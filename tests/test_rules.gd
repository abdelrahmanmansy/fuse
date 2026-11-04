extends "res://tests/case.gd"

const Ruleset = preload("res://src/core/rules/ruleset.gd")


func test_tick_based_defaults_match_the_design_doc() -> void:
	var rules = Ruleset.new()
	eq(rules.fuse_ticks, 144, "2.4 s fuse at 60 Hz")
	eq(rules.blast_ticks, 27, "450 ms blast at 60 Hz")
	eq(rules.countdown_ticks, 180, "3 s countdown")
	eq(rules.match_ticks, 9000, "150 s match")
	eq(rules.drop_chance_percent, 34, "34 % crate drop chance")


func test_speed_curve_is_monotonic_and_capped() -> void:
	var rules = Ruleset.new()
	var previous := 0
	for level in range(rules.max_speed_level + 1):
		var speed: int = rules.speed_fp_for_level(level)
		check(speed > previous, "speed increases at level %d" % level)
		previous = speed
	eq(rules.speed_fp_for_level(0), rules.base_speed_fp, "level 0 is base speed")
	eq(rules.speed_fp_for_level(99), rules.max_speed_fp, "speed is capped")
	eq(rules.ticks_to_cross_a_tile(rules.base_speed_fp), 16, "base speed crosses a tile in 16 ticks")
	eq(rules.bomb_buffer_ticks, 6, "bomb presses are buffered for 100 ms")
