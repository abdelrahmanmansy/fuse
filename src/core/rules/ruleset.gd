extends RefCounted
## All tuning in one object so modes, tests and future game rules can override it.
## Durations are integer ticks at `tick_rate`; speeds are fixed-point units per tick
## (1024 units = one tile).

const TICK_RATE := 60
const FIXED_ONE := 1024

# Arena / match flow
var arena_width: int = 21
var arena_height: int = 13
var countdown_ticks: int = 180          # 3.0 s
var match_ticks: int = 9000             # 150 s
var results_ticks: int = 300            # 5.0 s
var sudden_death_interval_ticks: int = 45
var sudden_death_fuse_ticks: int = 90

# Bomb / blast
var fuse_ticks: int = 144               # 2.4 s
var blast_ticks: int = 27               # 0.45 s
var spawn_guard_ticks: int = 120        # 2.0 s

# Movement: 3.75 tiles/s and 0.47 tiles/s per upgrade, capped near 6.1 tiles/s.
# 64 fp/tick = exactly 16 ticks per tile, which keeps the grid step snappy without
# making late-game speed unreadable.
var base_speed_fp: int = 64
var speed_step_fp: int = 8
var max_speed_fp: int = 104
var max_speed_level: int = 5

# Input feel: a bomb press stays queued for this many ticks, so pressing a few
# frames before a slot frees or before the countdown ends still places the bomb.
var bomb_buffer_ticks: int = 6

# Player stats
var start_capacity: int = 1
var max_capacity: int = 5
var start_range: int = 2
var max_range: int = 6

# Loot
var drop_chance_percent: int = 34
var crate_density_percent: int = 82


func speed_fp_for_level(level: int) -> int:
	return mini(base_speed_fp + level * speed_step_fp, max_speed_fp)


func ticks_to_cross_a_tile(speed_fp: int) -> int:
	if speed_fp <= 0:
		return 1
	return ceili(float(FIXED_ONE) / float(speed_fp))
