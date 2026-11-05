#!/usr/bin/env node
// Tiny static server for the exported FUSE web build.
//
//   node tools/serve_web.mjs [--port 8080] [--dir build/web]
//
// Binds 0.0.0.0 so a phone on the same Wi-Fi/hotspot can open the printed LAN
// URL. No third-party dependencies; wasm gets the MIME type Godot expects.

import { createServer } from "node:http";
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

const server = createServer(async (req, res) => {
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
});

server.listen(port, "0.0.0.0", () => {
  const urls = [];
  for (const list of Object.values(networkInterfaces())) {
    for (const net of list || []) {
      if (net.family === "IPv4" && !net.internal) {
        urls.push(`http://${net.address}:${port}/`);
      }
    }
  }
  console.log(`FUSE web build served from ${root}`);
  console.log(`  local: http://localhost:${port}/`);
  for (const url of urls) console.log(`  LAN:   ${url}`);
});
