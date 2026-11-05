extends RefCounted
## Pure app navigation and best-of series bookkeeping.
##
## Deliberately free of nodes, input and rendering so menu flow can be tested
## headlessly and reused later for online lobbies. The match simulation knows
## nothing about rounds; this layer owns the series around each match.

enum Screen { TITLE, MATCH, RESULTS }

const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")

const MODE_1P := 0
const MODE_2P := 1

var screen: int = Screen.TITLE
var mode: int = MODE_1P
var best_of: int = 3

var wins: Array[int] = [0, 0]
var rounds_played: int = 0
## Counts series started since boot. Mixed into the arena seed so a rematch does
## not replay the exact same board as the previous series.
var series: int = 0
var round: int = 0
var last_winner: int = -1
var series_over: bool = false


## Rounds required to take the series (first to majority).
func wins_needed() -> int:
	return int(ceil(float(best_of) / 2.0))


## Start a fresh series in `selected_mode`; called when leaving the title screen.
func begin_series(selected_mode: int) -> void:
	mode = clampi(selected_mode, MODE_1P, MODE_2P)
	wins = [0, 0]
	rounds_played = 0
	series += 1
	round = 1
	last_winner = -1
	series_over = false
	screen = Screen.MATCH


## Record a finished round. `winner_id` is a player index or -1 for a draw.
## Returns true when the series is decided (or the round limit is reached).
func record_round(winner_id: int) -> bool:
	if screen != Screen.MATCH or series_over:
		return series_over
	rounds_played += 1
	last_winner = winner_id
	if winner_id >= 0 and winner_id < wins.size():
		wins[winner_id] += 1
	series_over = wins[0] >= wins_needed() \
		or wins[1] >= wins_needed() \
		or rounds_played >= best_of
	screen = Screen.RESULTS
	return series_over


## Advance to the next round in the same series. False when the series is over.
func next_round() -> bool:
	if series_over:
		return false
	round += 1
	screen = Screen.MATCH
	return true


## Winner of a decided series, or -1 for a tie (possible with draws in a best-of).
func series_winner() -> int:
	if wins[0] == wins[1]:
		return -1
	return 0 if wins[0] > wins[1] else 1


## Seed for the board that should be on screen. Outside a live match (title
## attract, results) the base seed is used unchanged; during a series it is
## folded with the round and series counters so every round gets a new arena.
func arena_seed(base_seed: int) -> int:
	if screen != Screen.MATCH:
		return base_seed
	return ArenaLayout.derive_seed(base_seed, round, series)


## Leave the match and return to the title screen with a clean slate.
func back_to_title() -> void:
	screen = Screen.TITLE
	wins = [0, 0]
	rounds_played = 0
	round = 0
	last_winner = -1
	series_over = false


## "Player 2" style label, 1-based; used by menus and results copy.
static func player_label(player_id: int) -> String:
	return "PLAYER %d" % (player_id + 1)
