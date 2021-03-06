-define(MAGIC, "5-in-line-tic-tac-toe").
-define(s, State#state).
-type game_id() :: binary().
-type nick() :: binary().
-type player() :: {pid(), nick()}.

-record(game, {
	  room :: pid(),
	  id :: game_id(),
	  game_type :: binary(),
	  players :: [player()],
	  winner :: nick(),
	  loser :: nick()
	 }).
-type game() :: #game{}.
