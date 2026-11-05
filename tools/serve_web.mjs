#!/usr/bin/env node
// Tiny static server for the exported FUSE web build.
//
//   node tools/serve_web.mjs [--port 8080] [--dir build/web] [--https]
//
// Binds 0.0.0.0 so a phone on the same Wi-Fi/hotspot can open the printed LAN
// URL. Godot 4.7 requires a Secure Context, so a phone must use --https with the
// self-signed certificate from tools/make_cert.ps1. No third-party dependencies;
// wasm gets the MIME type Godot expects.

import { createServer as createHttpServer } from "node:http";
import { createServer as createHttpsServer } from "node:https";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { networkInterfaces } from "node:os";

const args = process.argv.slice(2);
function argValue(name, fallback) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}

const port = Number(argValue("--port", process.env.PORT || 8080));
const root = resolve(argValue("--dir", "build/web"));
const useHttps = args.includes("--https");
const certPath = resolve(argValue("--cert", "build/certs/dev-cert.pem"));
const keyPath = resolve(argValue("--key", "build/certs/dev-key.pem"));

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".css": "text/css; charset=utf-8",
  ".worklet.js": "text/javascript; charset=utf-8",
};

async function handleRequest(req, res) {
  try {
    const url = new URL(req.url || "/", "http://localhost");
    let pathname = decodeURIComponent(url.pathname);
    if (pathname.endsWith("/")) pathname += "index.html";
    const file = normalize(join(root, pathname));
    if (!file.startsWith(root)) {
      res.writeHead(403).end("Forbidden");
      return;
    }
    const info = await stat(file);
    if (!info.isFile()) {
      res.writeHead(404).end("Not found");
      return;
    }
    const body = await readFile(file);
    res.writeHead(200, {
      "Content-Type": MIME[extname(file)] || "application/octet-stream",
      "Content-Length": body.length,
      "Cache-Control": "no-cache",
      // Single-threaded builds do not need cross-origin isolation.
    });
    res.end(body);
  } catch {
    res.writeHead(404).end("Not found");
  }
}

let server;
if (useHttps) {
  let cert;
  let key;
  try {
    [cert, key] = await Promise.all([readFile(certPath), readFile(keyPath)]);
  } catch {
    console.error(`Missing certificate files:\n  ${certPath}\n  ${keyPath}`);
    console.error("Generate them once with:");
    console.error("  powershell -ExecutionPolicy Bypass -File tools/make_cert.ps1");
    process.exit(1);
  }
  server = createHttpsServer({ cert, key }, handleRequest);
} else {
  server = createHttpServer(handleRequest);
}

server.listen(port, "0.0.0.0", () => {
  const scheme = useHttps ? "https" : "http";
  const urls = [];
  for (const list of Object.values(networkInterfaces())) {
    for (const net of list || []) {
      if (net.family === "IPv4" && !net.internal) {
        urls.push(`${scheme}://${net.address}:${port}/`);
      }
    }
  }
  console.log(`FUSE web build served from ${root}`);
  console.log(`  local: ${scheme}://localhost:${port}/`);
  for (const url of urls) console.log(`  LAN:   ${url}`);
  if (useHttps) {
    console.log("  self-signed certificate: accept the browser warning once");
  } else {
    console.log("  warning: Godot requires HTTPS on a phone; pass --https");
  }
});
