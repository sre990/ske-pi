-module(test_stream).
-include("include/defines.hrl").
-export([benchmark/0,benchmark/4]).

% testing the pipe and farm skeletons by applying the function
% fn=1+(sin(X))^(10*Exp), where X is a random number from 0 to an upper bound

% default configuration
benchmark() ->
   Schedulers_Num = utils:get_schedulers(),
   Chunks_Exp = ?EXP-round(math:log2(Schedulers_Num)),
   benchmark(Schedulers_Num,Schedulers_Num, ?EXP,Chunks_Exp).
% customise number of schedulers online, number of workers, length of list and
% length of chunks
benchmark(W, Schedulers_Num, Exp, Chunks_Exp) ->
   utils:set_schedulers(Schedulers_Num),
   List = [rand:uniform(?UPPER)||
   _ <- utils:create_list(Exp)],

   io:format("> calculating the function fn=1+(sin(X))^(10*Exp), "),
   io:format("where EXP=~p and X is a random number from 0 to ~p.~n",
      [?EXP,?UPPER]),
   io:format("> testing with ~w scheduler(s) and ~w worker(s)~n",
   [Schedulers_Num,W]),
   io:format("> the list is 2^~w=~w elements long.~n",[Exp,length(List)]),
   if
      Exp>Chunks_Exp ->
         Chunks_Len = round(math:pow(2,Chunks_Exp)),
         io:format("> split into 2^~w chunks of length 2^~w=~w.~n~n",
         [Exp-Chunks_Exp, Chunks_Exp,Chunks_Len]);
      true ->
         Chunks_Len = round(math:pow(2,Exp)),
         io:format("> split 2^~w chunks of length 2^~w=~w.~n~n",
         [0, Exp,Chunks_Len])
   end,

   io:format("running tests, please wait...~n~n"),

   Chunks =  utils:make_chunks(Chunks_Len,List),

   Fun = fun(Input) ->
      [?COMPUTATION(X,Exp) || X <- Input]
   end,

   W_Fun = fun(Chunks) ->
      lists:sum(
      [?COMPUTATION(X,Exp)
      || X <- Chunks])
   end,

   % sequential version is a farm with only one worker
   Seq =
      fun() ->
         stream:start_seq(W_Fun, Chunks)
      end,

   % pipeline version with two stages of farm workers
   Pipe =
      fun() ->
         stream:start_piped_farm(W, [Fun, fun lists:sum/1], Chunks)
      end,

   % farm version
   Farm =
      fun() ->
         stream:start_farm(W, W_Fun, Chunks)
      end,

   Time_Seq = utils:test_loop(?TIMES,Seq, []),
   Mean_Seq = utils:mean(Time_Seq),
   Median_Seq = utils:median(Time_Seq),
   Time_Pipe = utils:test_loop(?TIMES,Pipe, []),
   Mean_Pipe = utils:mean(Time_Pipe),
   Median_Pipe = utils:median(Time_Pipe),
   Time_Farm = utils:test_loop(?TIMES,Farm, []),
   Mean_Farm = utils:mean(Time_Farm),
   Median_Farm = utils:median(Time_Farm),
   Speedup_Pipe = utils:speedup(Mean_Seq,Mean_Pipe),
   Speedup_Farm = utils:speedup(Mean_Seq,Mean_Farm),
   io:format("---SUMMARY OF RESULTS---~n"),
   utils:report(?SEQ, Time_Seq, Mean_Seq, Median_Seq),
   utils:report(?FARM, Time_Farm, Mean_Farm, Median_Farm),
   utils:report(?PIPED_FARM, Time_Pipe, Mean_Pipe, Median_Pipe),
   io:format("speedup for the ~p is ~w~n",[?FARM,Speedup_Pipe]),
   io:format("speedup for the ~p is ~w~n", [?PIPED_FARM,Speedup_Farm]).
