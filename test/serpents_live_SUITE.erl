-module(serpents_live_SUITE).
-author('elbrujohalcon@inaka.net').

-include_lib("mixer/include/mixer.hrl").
-mixin([
        {serpents_test_utils,
         [ init_per_suite/1
         , end_per_suite/1
         ]}
       ]).

-export([ all/0
        , init_per_testcase/2
        , end_per_testcase/2
        ]).
-export([ serpent_movement/1
        , collision_detection_left_wall/1
        , collision_detection_right_wall/1
        , collision_detection_up_wall/1
        , collision_detection_down_wall/1
        , collision_with_serpent_body/1
        , collision_with_serpent_head/1
        ]).

-spec all() -> [atom()].
all() -> serpents_test_utils:all(?MODULE).

-spec init_per_testcase(atom(), serpents_test_utils:config()) ->
  serpents_test_utils:config().
init_per_testcase(serpent_movement, Config) ->
  GameId =
    serpents_games:id(
      serpents_core:create_game(#{cols => 5, rows => 5, ticktime => 600000})),
  Player1Id = serpents_players:id(serpents_core:register_player(<<"1">>)),
  Player2Id = serpents_players:id(serpents_core:register_player(<<"2">>)),
  Player3Id = serpents_players:id(serpents_core:register_player(<<"3">>)),
  serpents_core:join_game(GameId, Player1Id),
  serpents_core:join_game(GameId, Player2Id),
  serpents_core:join_game(GameId, Player3Id),
  [ {player1, Player1Id}
  , {player2, Player2Id}
  , {player3, Player3Id}
  , {game, GameId}
  | Config];
init_per_testcase(Test, Config) when Test == collision_with_serpent_body;
                                     Test == collision_with_serpent_head ->
  Game = serpents_games_repo:create(#{cols => 5, rows => 5}),
  Player1Id = serpents_players:id(serpents_core:register_player(<<"1">>)),
  Player2Id = serpents_players:id(serpents_core:register_player(<<"2">>)),
  [ {player1, Player1Id}
  , {player2, Player2Id}
  , {game, Game}
  | Config];
init_per_testcase(_Test, Config) ->
  GameId =
    serpents_games:id(
      serpents_core:create_game(#{cols => 5, rows => 5, ticktime => 600000})),
  Player1Id = serpents_players:id(serpents_core:register_player(<<"1">>)),
  serpents_core:join_game(GameId, Player1Id),
  [ {player1, Player1Id}
  , {game, GameId}
  | Config].

-spec end_per_testcase(atom(), serpents_test_utils:config()) ->
  serpents_test_utils:config().
end_per_testcase(_Test, Config) ->
  lists:filter(
    fun ({K, _}) -> not lists:member(K, [game, player1, player2, player3]) end,
    Config).

-spec serpent_movement(serpents_test_utils:config()) -> {comment, []}.
serpent_movement(Config) ->
  {game, GameId} = lists:keyfind(game, 1, Config),

  ct:comment("Check the game board and start the game"),
  Game = serpents_core:fetch_game(GameId),
  Serpents = serpents_games:serpents(Game),
  ok = serpents_core:start_game(GameId),

  ct:comment("After a tick, all serpents should've moved in their directions"),
  serpents_games:process_name(GameId) ! tick,
  NewGame = serpents_core:fetch_game(GameId),

  FoundSerpents =
    lists:map(
      fun(Serpent) ->
        NewSerpent =
          serpents_games:serpent(NewGame, serpents_serpents:owner(Serpent)),

        ExpectedDirection = serpents_serpents:direction(Serpent),
        ExpectedDirection = serpents_serpents:direction(NewSerpent),

        [Head|_] = serpents_serpents:body(Serpent),
        ExpectedPosition =
          serpents_test_utils:move(Head, serpents_serpents:direction(Serpent)),
        [ExpectedPosition|_] = serpents_serpents:body(NewSerpent),

        NewSerpent
      end, Serpents),

  [] = FoundSerpents -- serpents_games:serpents(NewGame),
  [] = serpents_games:serpents(NewGame) -- FoundSerpents,

  {comment, ""}.

-spec collision_detection_left_wall(serpents_test_utils:config()) ->
  {comment, []}.
collision_detection_left_wall(Config) ->
  [{_, 0} | _] = collision_detection_wall(left, Config),
  {comment, ""}.

-spec collision_detection_right_wall(serpents_test_utils:config()) ->
  {comment, []}.
collision_detection_right_wall(Config) ->
  [{_, 6} | _] = collision_detection_wall(right, Config),
  {comment, ""}.

-spec collision_detection_up_wall(serpents_test_utils:config()) ->
  {comment, []}.
collision_detection_up_wall(Config) ->
  [{0, _} | _] = collision_detection_wall(up, Config),
  {comment, ""}.

-spec collision_detection_down_wall(serpents_test_utils:config()) ->
  {comment, []}.
collision_detection_down_wall(Config) ->
  [{6, _} | _] = collision_detection_wall(down, Config),
  {comment, ""}.

collision_detection_wall(Direction, Config) ->
  {game, GameId} = lists:keyfind(game, 1, Config),
  {player1, Player1Id} = lists:keyfind(player1, 1, Config),

  ct:comment("Pick the first serpent and get it to move ~p", [Direction]),
  ok = serpents_core:turn(GameId, Player1Id, Direction),
  serpents_core:start_game(GameId),

  ct:comment(
    "After moving the serpent 5 times ~p, it should've died", [Direction]),
  lists:foreach(
    fun(_) -> serpents_games:process_name(GameId) ! tick end,
    lists:seq(1, 5)),

  NewGame = serpents_core:fetch_game(GameId),
  finished = serpents_games:state(NewGame),
  Serpent = serpents_games:serpent(NewGame, Player1Id),
  dead = serpents_serpents:status(Serpent),
  serpents_serpents:body(Serpent).

-spec collision_with_serpent_body(serpents_test_utils:config()) ->
  {comment, []}.
collision_with_serpent_body(Config) ->
  {game, Game} = lists:keyfind(game, 1, Config),
  {player1, Player1Id} = lists:keyfind(player1, 1, Config),
  {player2, Player2Id} = lists:keyfind(player2, 1, Config),

  ct:comment("Serpents are placed in proper positions"),
  Serpent1 =
    serpents_serpents:feed(serpents_serpents:new(Player1Id, {2, 2}, down)),
  Serpent2 = serpents_serpents:new(Player2Id, {2, 3}, left),
  GameWithSerpents =
    serpents_games:add_serpent(
      serpents_games:add_serpent(Game, Serpent1), Serpent2),

  ct:comment("When serpent 2 moves to the left it should collide with S1"),
  NewGame = serpents_games_repo:advance(GameWithSerpents),

  ct:comment("S1 should be alive and its body should be 2 cells long"),
  alive = serpents_serpents:status(serpents_games:serpent(NewGame, Player1Id)),

  ct:comment("S2 should've died in ~p", [NewGame]),
  dead = serpents_serpents:status(serpents_games:serpent(NewGame, Player2Id)),

  {comment, ""}.

-spec collision_with_serpent_head(serpents_test_utils:config()) ->
  {comment, []}.
collision_with_serpent_head(Config) ->
  {game, Game} = lists:keyfind(game, 1, Config),
  {player1, Player1Id} = lists:keyfind(player1, 1, Config),
  {player2, Player2Id} = lists:keyfind(player2, 1, Config),

  ct:comment("Serpents are placed in proper positions"),
  Serpent1 = serpents_serpents:new(Player1Id, {2, 2}, right),
  Serpent2 = serpents_serpents:new(Player2Id, {2, 4}, left),
  GameWithSerpents =
    serpents_games:add_serpent(
      serpents_games:add_serpent(Game, Serpent1), Serpent2),

  ct:comment("When serpents move they simultaenously collide"),
  NewGame = serpents_games_repo:advance(GameWithSerpents),

  ct:comment("Both serpents are dead"),
  dead = serpents_serpents:status(serpents_games:serpent(NewGame, Player1Id)),
  dead = serpents_serpents:status(serpents_games:serpent(NewGame, Player2Id)),

  ct:comment("The game finished"),
  finished = serpents_games:state(NewGame),

  {comment, ""}.
