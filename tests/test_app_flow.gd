extends "res://tests/case.gd"
## App-level flow: screen transitions, series scoring, draw handling.

const AppFlow = preload("res://src/app/app_flow.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")


func test_starts_on_title_with_one_player_mode() -> void:
	var flow = AppFlow.new()
	eq(flow.screen, AppFlow.Screen.TITLE, "boot screen is title")
	eq(flow.mode, AppFlow.MODE_1P, "default mode is 1P")
	eq(flow.best_of, 3, "default series is best of 3")
	eq(flow.wins_needed(), 2, "best of 3 needs two wins")
	eq(flow.round, 0, "no round before a series")


func test_wins_needed_scales_with_best_of() -> void:
	var flow = AppFlow.new()
	flow.best_of = 1
	eq(flow.wins_needed(), 1, "single round series")
	flow.best_of = 5
	eq(flow.wins_needed(), 3, "best of 5 needs three")
	flow.best_of = 7
	eq(flow.wins_needed(), 4, "best of 7 needs four")


func test_begin_series_resets_and_enters_match() -> void:
	var flow = AppFlow.new()
	flow.begin_series(AppFlow.MODE_2P)
	eq(flow.screen, AppFlow.Screen.MATCH, "series starts in match")
	eq(flow.mode, AppFlow.MODE_2P, "mode is stored")
	eq(flow.series, 1, "first series is 1")
	eq(flow.round, 1, "first round is 1")
	eq(flow.rounds_played, 0, "no rounds played yet")
	eq(flow.wins, [0, 0], "score starts level")


func test_series_counter_advances_on_rematch_but_not_on_next_round() -> void:
	var flow = AppFlow.new()
	flow.begin_series(AppFlow.MODE_1P)
	eq(flow.series, 1, "first series")
	flow.record_round(0)
	flow.next_round()
	eq(flow.series, 1, "next round stays in the same series")
	flow.begin_series(AppFlow.MODE_1P)
	eq(flow.series, 2, "rematch starts a new series")
	flow.back_to_title()
	eq(flow.series, 2, "returning to title keeps the counter so the next series differs")


func test_series_ends_when_a_player_reaches_majority() -> void:
	var flow = AppFlow.new()
	flow.begin_series(AppFlow.MODE_1P)

	eq(flow.record_round(0), false, "one win is not enough")
	eq(flow.screen, AppFlow.Screen.RESULTS, "round moves to results")
	eq(flow.wins, [1, 0], "win counted for player 0")

	eq(flow.next_round(), true, "next round allowed")
	eq(flow.round, 2, "round counter advanced")
	eq(flow.screen, AppFlow.Screen.MATCH, "back in match")

	eq(flow.record_round(1), false, "series now level")
	eq(flow.wins, [1, 1], "player 1 win counted")

	eq(flow.next_round(), true, "decider allowed")
	eq(flow.record_round(0), true, "two wins end the series")
	eq(flow.series_over, true, "series flagged over")
	eq(flow.series_winner(), 0, "player 0 takes the series")
	eq(flow.next_round(), false, "no round after a decided series")


func test_draws_do_not_score_but_consume_a_round() -> void:
	var flow = AppFlow.new()
	flow.begin_series(AppFlow.MODE_1P)
	flow.record_round(-1)
	eq(flow.wins, [0, 0], "draw awards nothing")
	eq(flow.rounds_played, 1, "draw still played")
	eq(flow.series_over, false, "draw alone does not end best of 3")
	flow.next_round()
	flow.record_round(-1)
	flow.next_round()
	eq(flow.series_over, false, "two draws still open")
	flow.record_round(-1)
	eq(flow.series_over, true, "round limit closes the series")
	eq(flow.series_winner(), -1, "all-draw series has no winner")


func test_round_limit_caps_a_long_series() -> void:
	var flow = AppFlow.new()
	flow.best_of = 3
	flow.begin_series(AppFlow.MODE_1P)
	flow.record_round(0)
	flow.next_round()
	flow.record_round(1)
	flow.next_round()
	flow.record_round(-1)
	eq(flow.rounds_played, 3, "three rounds played")
	eq(flow.series_over, true, "best of 3 cannot run longer")
	eq(flow.series_winner(), -1, "tie after the limit")


func test_record_round_is_ignored_outside_a_match() -> void:
	var flow = AppFlow.new()
	eq(flow.record_round(0), false, "cannot score on title")
	eq(flow.wins, [0, 0], "title recording changes nothing")
	flow.begin_series(AppFlow.MODE_1P)
	flow.record_round(0)
	eq(flow.record_round(1), false, "recording again in results is ignored")
	eq(flow.wins, [1, 0], "score unchanged by duplicate record")


func test_back_to_title_clears_the_series() -> void:
	var flow = AppFlow.new()
	flow.begin_series(AppFlow.MODE_2P)
	flow.record_round(0)
	flow.back_to_title()
	eq(flow.screen, AppFlow.Screen.TITLE, "title restored")
	eq(flow.wins, [0, 0], "score cleared")
	eq(flow.round, 0, "round cleared")
	eq(flow.series_over, false, "series closed")
	eq(flow.mode, AppFlow.MODE_2P, "mode preference survives")


func test_arena_seed_changes_per_round_and_per_rematch() -> void:
	var flow = AppFlow.new()
	eq(flow.arena_seed(4242), 4242, "title attract keeps the base seed")
	flow.begin_series(AppFlow.MODE_1P)
	var first: int = flow.arena_seed(4242)
	eq(first, ArenaLayout.derive_seed(4242, 1, 1), "first round seed comes from the counters")
	flow.record_round(0)
	flow.next_round()
	var second: int = flow.arena_seed(4242)
	check(second != first, "next round changes the arena seed")
	flow.begin_series(AppFlow.MODE_1P)
	check(flow.arena_seed(4242) != first, "a rematch changes the arena seed")
	flow.back_to_title()
	eq(flow.arena_seed(4242), 4242, "back on the title the attract seed is stable again")


func test_player_label_is_one_based() -> void:
	eq(AppFlow.player_label(0), "PLAYER 1", "player 0 label")
	eq(AppFlow.player_label(1), "PLAYER 2", "player 1 label")
