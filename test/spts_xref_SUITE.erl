-module(serpents_xref_SUITE).
-author('elbrujohalcon@inaka.net').

-ignore_xref([all/0]).
-ignore_xref([xref/1]).

-export([all/0]).
-export([xref/1]).

-spec all() -> [atom()].
all() -> serpents_test_utils:all(?MODULE).

-spec xref(serpents_test_utils:config()) -> {comment, []}.
xref(_Config) ->
  Dirs = [filename:absname("../../ebin")],
  [] = xref_runner:check(undefined_function_calls, #{dirs => Dirs}),
  [] = xref_runner:check(undefined_functions, #{dirs => Dirs}),
  [] = xref_runner:check(locals_not_used, #{dirs => Dirs}),
  [] = xref_runner:check(deprecated_function_calls, #{dirs => Dirs}),
  [] = xref_runner:check(deprecated_functions, #{dirs => Dirs}),
  {comment, ""}.
