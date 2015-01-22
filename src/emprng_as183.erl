%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 1996-2011. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%
-module(emprng_as183).

%% Reasonable random number generator.
%%  The method is attributed to B. A. Wichmann and I. D. Hill
%%  See "An efficient and portable pseudo-random number generator",
%%  Journal of Applied Statistics. AS183. 1982. Also Byte March 1987.

-export([seed/3, seed0/0, uniform_s/1, uniform_s/2]).

-define(PRIME1, 30269).
-define(PRIME2, 30307).
-define(PRIME3, 30323).

%%-----------------------------------------------------------------------
%% The type of the state

-type ran() :: {integer(), integer(), integer()}.

%%-----------------------------------------------------------------------

-spec seed0() -> ran().

seed0() ->
    {3172, 9814, 20125}.

%% seed(A1, A2, A3) 
%%  Seed random number generation 

-spec seed(A1, A2, A3) -> ran() when
      A1 :: integer(),
      A2 :: integer(),
      A3 :: integer().

seed(A1, A2, A3) ->
    {(abs(A1) rem (?PRIME1-1)) + 1,   % Avoid seed numbers that are
	 (abs(A2) rem (?PRIME2-1)) + 1,   % even divisors of the
	 (abs(A3) rem (?PRIME3-1)) + 1}.  % corresponding primes.

%%% Functional versions

%% uniform_s(State) -> {F, NewState}
%%  Returns a random float between 0 and 1.

-spec uniform_s(State0) -> {float(), State1} when
      State0 :: ran(),
      State1 :: ran().

uniform_s({A1, A2, A3}) ->
    B1 = (A1*171) rem ?PRIME1,
    B2 = (A2*172) rem ?PRIME2,
    B3 = (A3*170) rem ?PRIME3,
    R = B1/?PRIME1 + B2/?PRIME2 + B3/?PRIME3,
    {R - trunc(R), {B1,B2,B3}}.

%% uniform_s(N, State) -> {I, NewState}
%%  Given an integer N >= 1, uniform(N) returns a random integer
%%  between 1 and N.

-spec uniform_s(N, State0) -> {integer(), State1} when
      N :: pos_integer(),
      State0 :: ran(),
      State1 :: ran().

uniform_s(N, State0) when is_integer(N), N >= 1 ->
    {F, State1} = uniform_s(State0),
    {trunc(F * N) + 1, State1}.
