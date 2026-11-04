extends SceneTree
## Headless AI-vs-AI soak for M1. Proves the grey-box opponent actually plays:
## crates get destroyed, bombs explode, players get eliminated, the match ends.
##
##   godot --headless --path . --script res://tools/ai_selfplay.gd

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const SimpleAi = preload("res://src/ai/simple_ai.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const MAX_TICKS := 9000

var _trace: bool = false


func _initialize() -> void:
	_trace = OS.get_cmdline_user_args().has("trace")
	var failures: Array[String] = []
	var seed_value := 20261031

	var rules = Ruleset.new()
	rules.countdown_ticks = 0
	var arena = ArenaLayout.new()
	if not arena.generate(rules.arena_width, rules.arena_height, seed_value, 4,
			rules.crate_density_percent):
		printerr("arena generation failed: %s" % arena.last_error)
		quit(1)
		return

	var sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, 4)
	sim.start()
	sim.step()

	var ais: Array = []
	for i in 4:
		ais.append(SimpleAi.new(seed_value + 97 * (i + 1)))

	var crates_destroyed := 0
	var bombs_placed := 0
	var explosions := 0
	var pickups_collected := 0
	var eliminations := 0
	var first_elimination_tick := -1
	var tick := 0

	while tick < MAX_TICKS and sim.phase != MatchSim.Phase.RESULTS and sim.phase != MatchSim.Phase.IDLE:
		var commands: Array = []
		for i in 4:
			var command: Dictionary = ais[i].think(sim, i)
			commands.append(command)
			sim.submit_command(i, command["dir"], command["bomb"])
		sim.step()
		tick += 1
		if _trace and tick % 300 == 0:
			print("  tick %d positions=%s commands=%s phase=%d" % [
				sim.tick, str(sim.players.map(func(p): return str(p.tile))), str(commands), sim.phase,
			])
		if _trace and sim.tick >= 30 and sim.tick <= 190 and sim.tick % 5 == 0:
			var p = sim.players[0]
			print("    t%d p0 tile=%s mv=%s->%s moving=%s dir=%s bomb=%s" % [
				sim.tick, str(p.tile), str(p.move_from), str(p.move_to), str(p.moving),
				str(commands[0]["dir"]), str(commands[0]["bomb"]),
			])
		for event in sim.take_events():
			match event.type:
				SimEvent.Type.CRATE_DESTROYED:
					crates_destroyed += 1
				SimEvent.Type.BOMB_PLACED:
					bombs_placed += 1
					if _trace:
						print("  tick %d  BOMB   p%d at %s" % [sim.tick, event.data.owner, str(event.data.tile)])
				SimEvent.Type.BOMB_EXPLODED:
					explosions += 1
					if _trace:
						print("  tick %d  BOOM   bomb %d at %s (owner p%d)" % [
							sim.tick, event.data.bomb_id, str(event.data.tile), event.data.owner,
						])
				SimEvent.Type.PICKUP_COLLECTED:
					pickups_collected += 1
				SimEvent.Type.PLAYER_HIT:
					if _trace:
						print("  tick %d  HIT    p%d at %s  positions=%s" % [
							sim.tick, event.data.player, str(event.data.tile),
							str(sim.players.map(func(p): return str(p.tile))),
						])
				SimEvent.Type.PLAYER_ELIMINATED:
					eliminations += 1
					if first_elimination_tick < 0:
						first_elimination_tick = sim.tick

	print("AI self-play: ticks=%d phase=%d winner=%d" % [tick, sim.phase, sim.winner_id])
	print("  bombs=%d explosions=%d crates=%d pickups=%d eliminations=%d first_elim=%d" % [
		bombs_placed, explosions, crates_destroyed, pickups_collected, eliminations, first_elimination_tick,
	])
	if _trace:
		print("  final alive=%s crates_left=%d" % [
			str(sim.players.map(func(p): return "%d:%s" % [p.id, str(p.alive)])),
			_count_crates(sim),
		])

	if bombs_placed < 20:
		failures.append("AI placed only %d bombs" % bombs_placed)
	if explosions < 10:
		failures.append("only %d explosions" % explosions)
	if crates_destroyed < 5:
		failures.append("only %d crates destroyed" % crates_destroyed)
	if eliminations < 1:
		failures.append("no player was ever eliminated")
	if sim.phase != MatchSim.Phase.RESULTS:
		failures.append("match did not resolve within %d ticks (phase %d)" % [MAX_TICKS, sim.phase])
	if tick < 200:
		failures.append("match ended suspiciously fast at tick %d" % tick)

	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL  " + failure)
		quit(1)


func _count_crates(sim) -> int:
	var count := 0
	for y in sim.grid.height:
		for x in sim.grid.width:
			if sim.grid.get_tile(x, y) == 2:
				count += 1
	return count
