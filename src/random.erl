%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2003-2015. All Rights Reserved.
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
%% =====================================================================
%% Multiple PRNG module for Erlang/OTP
%%
%% Copyright (c) 2010-2015 Kenji Rikitake, Kyoto University.
%% Copyright (c) 2006-2015 Mutsuo Saito, Makoto Matsumoto,
%%                         Hiroshima University, The University of Tokyo.
%%
%% Author contact: kenji.rikitake@acm.org
%% =====================================================================

%% NOTE: this module will replace OTP random module
-module(random).

-export([seed/0, seed/1, seed/2, seed/3, seed0/0, seed0/1,
         uniform/0, uniform/1, uniform_s/1, uniform_s/2]).

-define(DEFAULT_ALG_HANDLER, as183).
-define(SEED_DICT, random_seed).

-record(alg, {seed0 :: fun(), seed :: fun(),
                uniform :: fun(), uniform_n :: fun()}).

%% =====================================================================
%% Types
%% =====================================================================

%% This depends on the algorithm handler function
-type alg_state() :: any().
%% This is the algorithm handler function within this module
-type alg_handler() :: #alg{}.
%% Internal state
-type state() :: {alg_handler(), alg_state()}.

%% export the alg_handler() type
-export_type([alg_handler/0]).

%% =====================================================================
%% Wrapper functions for the algorithm handlers
%% =====================================================================

%%% Note: if a process calls uniform/0 or uniform/1 without setting a seed first,
%%%       seed/0 is called automatically.
%%% (compatible with the random module)

%% seed0/0: returns the default state, including the state values
%% and the algorithm handler.
%% (compatible with the random module)

-spec seed0() -> state().

seed0() ->
    seed0(?DEFAULT_ALG_HANDLER).

%% seed0/1: returns the default state
%% for the given algorithm handler name in atom.
%% usage example: seed0(exs64)
%% (new function)

-spec seed0(atom()) -> state().

seed0(Alg0) ->
    Alg = #alg{seed0=Seed0} = mk_alg(Alg0),
    {Alg, Seed0()}.

%% seed_put/1: internal function to put seed into the process dictionary.

-spec seed_put(state()) -> undefined | state().

seed_put(Seed) ->
    put(?SEED_DICT, Seed).

%% seed/0: seeds RNG with default (fixed) state values and the algorithm handler
%% in the process dictionary, and returns the old state.
%% (compatible with the random module)

-spec seed() -> undefined | state().

seed() ->
    case seed_put(seed0()) of
        undefined -> seed0();
        % no type checking here
        Old -> Old
    end.

%% seed/1:
%% seed({A1, A2, A3}) is equivalent to seed(A1, A2, A3), and
%% Seed({Alg, AS}) is equivalent to seed(Alg, AS).
%% (the 3-element tuple argument is compatible with the random module,
%% and the 2-element tuple argument is a new function.)

-spec seed({Alg :: alg_handler(), AS :: alg_state()} |
           {A1 :: integer(), A2 :: integer(), A3 :: integer()}) ->
      undefined | state().

seed({A1, A2, A3}) ->
    seed(A1, A2, A3);
seed({Alg, AS}) ->
    seed(Alg, AS).

%% seed/3: seeds RNG with integer values in the process dictionary,
%% and returns the old state.
%% (compatible with the random module)

-spec seed(A1 :: integer(), A2 :: integer(), A3 :: integer()) ->
      undefined | state().

seed(A1, A2, A3) ->
    seed(?DEFAULT_ALG_HANDLER, {A1, A2, A3}).

%% seed/2: seeds RNG with the algorithm handler and given values
%% in the process dictionary, and returns the old state.
%% Note: the type of the values depends on the algorithm handler.
%% (new function)

-spec seed(Alg :: atom() | alg_handler(), AS :: alg_state()) -> state().

seed(Alg0, AS0) when is_atom(Alg0) ->
    Alg = #alg{seed=Seed} = mk_alg(Alg0),
    AS = Seed(AS0),
    _ = seed_put({Alg, AS}),
    {Alg, AS};
seed(Alg, AS) when is_record(Alg, alg) ->
    _ = seed_put({Alg, AS}),
    {Alg, AS}.

%%% uniform/0, uniform/1, uniform_s/1, uniform_s/2 are all
%%% uniformly distributed random numbers.
%%% (They are expected to be semantically compatible with OTP random module,
%%%  i.e., the uniformity and return value ranges will not change.)

%% uniform/0: returns a random float X where 0.0 < X < 1.0,
%% updating the state in the process dictionary.
%% (See OTP random module.)

-spec uniform() -> float().

uniform() ->
    {X, Seed} = uniform_s(seed()),
    _ = seed_put(Seed),
    X.

%% uniform/1: given an integer N >= 1,
%% uniform/1 returns a random integer X where 1 =< X =< N,
%% updating the state in the process dictionary.

-spec uniform(N :: pos_integer()) -> pos_integer().

uniform(N) ->
    {X, Seed} = uniform_s(N, seed()),
    _ = seed_put(Seed),
    X.

%% uniform_s/1: given a state, uniform_s/1
%% returns a random float X where 0.0 < X < 1.0,
%% and a new state.
%% (See OTP random module.)

-spec uniform_s(state()) -> {float(), NewS :: state()}.

uniform_s({Alg = #alg{uniform=Uniform}, AS0}) ->
    {X, AS} = Uniform(AS0),
    {X, {Alg, AS}}.

%% uniform_s/2: given an integer N >= 1 and a state, uniform_s/2
%% uniform_s/2 returns a random integer X where 1 =< X =< N,
%% and a new state.

-spec uniform_s(N :: pos_integer(), state()) ->
      {pos_integer(), NewS :: state()}.

uniform_s(N, {Alg = #alg{uniform_n=Uniform}, AS0}) 
  when is_integer(N), N >= 1 ->
    {X, AS} = Uniform(N, AS0),
    {X, {Alg, AS}}.


%% Setup alg record
mk_alg(as183) ->  %% DEFAULT_ALG_HANDLER
    #alg{seed0=fun as183_seed0/0, seed=fun as183_seed/1, 
	 uniform=fun as183_uniform/1, uniform_n=fun as183_uniform/2};
mk_alg(exs64) -> 
    #alg{seed0=fun exs64_seed0/0, seed=fun exs64_seed/1, 
	 uniform=fun exs64_uniform/1, uniform_n=fun exs64_uniform/2};
mk_alg(exsplus) -> 
    #alg{seed0=fun exsplus_seed0/0, seed=fun exsplus_seed/1, 
	 uniform=fun exsplus_uniform/1, uniform_n=fun exsplus_uniform/2};
mk_alg(exs1024) -> 
    #alg{seed0=fun exs1024_seed0/0, seed=fun exs1024_seed/1, 
	 uniform=fun exs1024_uniform/1, uniform_n=fun exs1024_uniform/2};
mk_alg(sfmt) -> 
    #alg{seed0=fun sfmt_seed0/0, seed=fun sfmt_seed/1, 
	 uniform=fun sfmt_uniform/1, uniform_n=fun sfmt_uniform/2};
mk_alg(tinymt) -> 
    #alg{seed0=fun tinymt_seed0/0, seed=fun tinymt_seed/1, 
	 uniform=fun tinymt_uniform/1, uniform_n=fun tinymt_uniform/2}.


%% =====================================================================
%% AS183 PRNG
%% =====================================================================

%% Reasonable random number generator.
%%  The method is attributed to B. A. Wichmann and I. D. Hill
%%  See "An efficient and portable pseudo-random number generator",
%%  Journal of Applied Statistics. AS183. 1982. Also Byte March 1987.

-define(PRIME1, 30269).
-define(PRIME2, 30307).
-define(PRIME3, 30323).

%%-----------------------------------------------------------------------
%% The type of the state

%-type ran() :: {integer(), integer(), integer()}.

%%-----------------------------------------------------------------------

%% seed0: initial PRNG seed

as183_seed0() ->
    {3172, 9814, 20125}.

%% seed: seeding with three Integers

as183_seed({A1, A2, A3}) ->
    {(abs(A1) rem (?PRIME1-1)) + 1,   % Avoid seed numbers that are
     (abs(A2) rem (?PRIME2-1)) + 1,   % even divisors of the
     (abs(A3) rem (?PRIME3-1)) + 1}.  % corresponding primes.

%% {uniform_s, State} -> {F, NewState}:
%%  Returns a random float between 0 and 1, and new state.

as183_uniform({A1, A2, A3}) ->
    B1 = (A1*171) rem ?PRIME1,
    B2 = (A2*172) rem ?PRIME2,
    B3 = (A3*170) rem ?PRIME3,
    R = B1/?PRIME1 + B2/?PRIME2 + B3/?PRIME3,
    {R - trunc(R), {B1,B2,B3}}.

%% {uniform_s, N, State} -> {I, NewState}
%%  Given an integer N >= 1, returns a random integer between 1 and N.

as183_uniform(N, State0) ->
    {F, State1} = as183_uniform(State0),
    {trunc(F * N) + 1, State1}.

%% =====================================================================
%% exs64 PRNG: Xorshift*64
%% Algorithm by Sebastiano Vigna
%% Reference URL: http://xorshift.di.unimi.it/
%% =====================================================================

%% uint64(). 64bit unsigned integer type.

-type uint64() :: 0..16#ffffffffffffffff.

%% exs64_state(). Internal state data type for exs64.
%% Internally represented as the record <code>#state{}</code>,
%% of the 128bit seed.

-type exs64_state() :: uint64().

-define(UINT32MASK, 16#ffffffff).
-define(UINT64MASK, 16#ffffffffffffffff).

%% Advance xorshift64star state for one step.
%% and generate 64bit unsigned integer from
%% the xorshift64star internal state.

-spec exs64_next(exs64_state()) ->
        {uint64(), exs64_state()}.

exs64_next(R) ->
    R1 = R bxor (R bsr 12),
    R2 = R1 bxor ((R1 bsl 25) band ?UINT64MASK),
    R3 = R2 bxor (R2 bsr 27),
    {(R3 * 2685821657736338717) band ?UINT64MASK, R3}.

%%-----------------------------------------------------------------------

%% seed0: initial PRNG seed
%% set the default seed value to xorshift64star state
%% in the process directory.

exs64_seed0() -> 1234567890123456789.

%% seed: seeding with three Integers
%% set the seed value to xorshift64star state in the process directory
%% with the given three unsigned 32-bit integer arguments
%% Multiplicands here: three 32-bit primes

exs64_seed({A1, A2, A3}) ->
    {V1, _} = exs64_next(((A1 band ?UINT32MASK) * 4294967197 + 1)),
    {V2, _} = exs64_next(((A2 band ?UINT32MASK) * 4294967231 + 1)),
    {V3, _} = exs64_next(((A3 band ?UINT32MASK) * 4294967279 + 1)),
    ((V1 * V2 * V3) rem (?UINT64MASK - 1)) + 1.

%% {uniform_s, State} -> {F, NewState}:
%% Generate float from
%% given xorshift64star internal state.
%% (Note: 0.0 &lt; result &lt; 1.0)
%% (Compatible with random:uniform_s/1)

exs64_uniform(R0) ->
    {V, R1} = exs64_next(R0),
    {V / 18446744073709551616.0, R1}.

%% {uniform_s, N, State} -> {I, NewState}:
%% Generate integer from given xorshift64star internal state.
%% (Note: 0 =&lt; result &lt; MAX (given positive integer))

exs64_uniform(Max, R) ->
    {V, R1} = exs64_next(R),
    {(V rem Max) + 1, R1}.

%% =====================================================================
%% exsplus PRNG: Xorshift+128
%% Algorithm by Sebastiano Vigna
%% Reference URL: http://xorshift.di.unimi.it/
%% =====================================================================

%% exsplus_state(). Internal state data type for exsplus.
%% Internally represented as the record <code>#state{}</code>,
%% of the 128bit seed.

-record(exsplus_state, {s0 :: uint64(), s1 :: uint64()}).

-type exsplus_state() :: #exsplus_state{}.

%% Advance xorshift128plus state for one step.
%% and generate 64bit unsigned integer from
%% the xorshift128plus internal state.

-spec exsplus_next(exsplus_state()) ->
    {uint64(), exsplus_state()}.

exsplus_next(R) ->
    S1 = R#exsplus_state.s0,
    S0 = R#exsplus_state.s1,
    S11 = (S1 bxor (S1 bsl 23)) band ?UINT64MASK,
    S12 = S11 bxor S0 bxor (S11 bsr 17) bxor (S0 bsr 26),
    {(S0 + S12) band ?UINT64MASK,
        #exsplus_state{s0 = S0, s1 = S12}}.

%%-----------------------------------------------------------------------

%% seed0: initial PRNG seed
%% Set the default seed value to xorshift128plus state
%% in the process directory

exsplus_seed0() ->
    #exsplus_state{s0 = 1234567890123456789, s1 = 9876543210987654321}.

%% seed: seeding with three Integers
%% Set the seed value to xorshift128plus state in the process directory
%% with the given three unsigned 32-bit integer arguments
%% Multiplicands here: three 32-bit primes

exsplus_seed({A1, A2, A3}) ->
    {_, R1} = exsplus_next(
               #exsplus_state{
                   s0 = (((A1 * 4294967197) + 1) band ?UINT64MASK),
                   s1 = (((A2 * 4294967231) + 1) band ?UINT64MASK)}),
    {_, R2} = exsplus_next(
               #exsplus_state{
                   s0 = (((A3 * 4294967279) + 1) band ?UINT64MASK),
                   s1 = R1#exsplus_state.s1}),
    R2.

%% {uniform_s, State} -> {F, NewState}:
%% Generate float from
%% given xorshift128plus internal state.
%% (Note: 0.0 =&lt; result &lt; 1.0)

exsplus_uniform(R0) ->
    {I, R1} = exsplus_next(R0),
    {I / 18446744073709551616.0, R1}.

%% {uniform_s, N, State} -> {I, NewState}:
%% Generate integer from given xorshift128plus internal state.
%% (Note: 0 =&lt; result &lt; MAX (given positive integer))

exsplus_uniform(Max, R) ->
    {V, R1} = exsplus_next(R),
    {(V rem Max) + 1, R1}.

%% =====================================================================
%% exs1024 PRNG: Xorshift*1024
%% Algorithm by Sebastiano Vigna
%% Reference URL: http://xorshift.di.unimi.it/
%% =====================================================================

%% exs1024_state(). Internal state data type for exs1024.
%% Representing 16 64-bit numbers with a pair of
%% the list and a reverse list.

-type exs1024_state() :: {list(uint64()), list(uint64())}.

%% Calculation of xorshift1024star.
%% exs1024_calc(S0, S1) -> {X, NS1}.
%% X: random number output

-spec exs1024_calc(uint64(), uint64()) -> {uint64(), uint64()}.

exs1024_calc(S0, S1) ->
    S11 = S1 bxor ((S1 bsl 31) band ?UINT64MASK),
    S12 = S11 bxor (S11 bsr 11),
    S01 = S0 bxor (S0 bsr 30),
    NS1 = S01 bxor S12,
    {(NS1 * 1181783497276652981) band ?UINT64MASK, NS1}.

%% Advance xorshift1024star state for one step.
%% and generate 64bit unsigned integer from
%% the xorshift1024star internal state.

-spec exs1024_next(exs1024_state()) ->
        {uint64(), exs1024_state()}.

exs1024_next({[H], RL}) ->
    exs1024_next({[H|lists:reverse(RL)], []});
exs1024_next({L, RL}) ->
    [S0|L2] = L,
    [S1|L3] = L2,
    {X, NS1} = exs1024_calc(S0, S1),
    {X, {[NS1|L3], [S0|RL]}}.

%% Generate a list of 16 64-bit element list
%% of the xorshift64star random sequence
%% from a given 64-bit seed.
%% Note: dependent on exs64_next/1

-spec exs1024_gen1024(uint64()) -> list(uint64()).

exs1024_gen1024(R) ->
        exs1024_gen1024(16, R, []).

-spec exs1024_gen1024(
        non_neg_integer(), uint64(), list(uint64())) ->
            list(uint64()).

exs1024_gen1024(0, _, L) ->
    L;
exs1024_gen1024(N, R, L) ->
    {X, R2} = exs64_next(R),
    exs1024_gen1024(N - 1, R2, [X|L]).

%%-----------------------------------------------------------------------

-define(UINT21MASK, 16#1fffff).

%% seed0: initial PRNG seed
%% Set the default seed value to xorshift1024star state
%% in the process directory (Compatible with random:seed0/0).

exs1024_seed0() ->
    {
     [
      16#0123456789abcdef,
      16#123456789abcdef0,
      16#23456789abcdef01,
      16#3456789abcdef012,
      16#456789abcdef0123,
      16#56789abcdef01234,
      16#6789abcdef012345,
      16#789abcdef0123456,
      16#89abcdef01234567,
      16#9abcdef012345678,
      16#abcdef0123456789,
      16#bcdef0123456789a,
      16#cdef0123456789ab,
      16#def0123456789abc,
      16#ef0123456789abcd,
      16#f0123456789abcde
     ], []}.

%% seed: seeding with three Integers
%% Set the seed value to xorshift1024star state in the process directory
%% with the given three unsigned 21-bit integer arguments
%% Multiplicands here: three 21-bit primes.
%% TODO: this seeding has a room to improve.

exs1024_seed({A1, A2, A3}) ->
    B1 = (((A1 band ?UINT21MASK) + 1) * 2097131) band ?UINT21MASK,
    B2 = (((A2 band ?UINT21MASK) + 1) * 2097133) band ?UINT21MASK,
    B3 = (((A3 band ?UINT21MASK) + 1) * 2097143) band ?UINT21MASK,
    {exs1024_gen1024(
            (B1 bsl 43) bor (B2 bsl 22) bor (B3 bsl 1) bor 1), []}.

%% {uniform_s, State} -> {F, NewState}:
%% Generate float from
%% given xorshift1024star internal state.
%% (Note: 0.0 =&lt; result &lt; 1.0)

exs1024_uniform(R0) ->
    {V, R1} = exs1024_next(R0),
    {V / 18446744073709551616.0, R1}.

%% {uniform_s, N, State} -> {I, NewState}:
%% @doc Generate integer from given xorshift1024star internal state.
%% (Note: 0 =&lt; result &lt; MAX (given positive integer))

exs1024_uniform(Max, R) ->
    {V, R1} = exs1024_next(R),
    {(V rem Max) + 1, R1}.

%% =====================================================================
%% SIMD-oriented Fast Mersennt Twister (SFMT) PRNG
%% SFMT19937 (period: 2^19937 - 1)
%% Algorithm by Mutsuo Saito and Makoto Matsumoto
%% Reference URL:
%% http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/SFMT/
%% =====================================================================

%% SFMT period parameters
-define(SFMT_MEXP, 19937).
-define(SFMT_N, 156).
-define(SFMT_N32, 624).
-define(SFMT_LAG, 11).
-define(SFMT_MID, 306).
-define(SFMT_POS1, 122).
-define(SFMT_SL1, 18).
-define(SFMT_SL2, 1).
-define(SFMT_SR1, 11).
-define(SFMT_SR2, 1).
-define(SFMT_MSK1, 16#dfffffef).
-define(SFMT_MSK2, 16#ddfecb7f).
-define(SFMT_MSK3, 16#bffaffff).
-define(SFMT_MSK4, 16#bffffff6).
-define(SFMT_PARITY1, 16#00000001).
-define(SFMT_PARITY2, 16#00000000).
-define(SFMT_PARITY3, 16#00000000).
-define(SFMT_PARITY4, 16#13c9e684).
%% identification string for the algorithm
-define(SFMT_IDSTR, "SFMT-19937:122-18-1-11-1:dfffffef-ddfecb7f-bffaffff-bffffff6").

-define(BITMASK32, 16#ffffffff).
-define(BITMASK64, 16#ffffffffffffffff).

%% type w128(). Four-element list of 32-bit unsigned integers
%% to represent a 128-bit integer.

-type w128() :: [integer()].

%% type sfmt_intstate().
%% N-element list of 128-bit unsigned integers,
%% represented as a four-element list of 32-bit integers.

-type sfmt_intstate() :: [integer()].

%% type ran_sfmt(). N-element list of 128-bit unsigned integers,
%% represented as a list of 32-bit integers. The number of N is 156.

-type ran_sfmt() :: {[integer()], sfmt_intstate()}.


%% SIMD 128-bit right shift simulation for little endian SIMD
%% of Shift*8 bits.

-spec sfmt_rshift128(w128(), integer()) -> w128().

sfmt_rshift128(In, Shift) ->
    [I0, I1, I2, I3] = In,
    TH = (I3 bsl 32) bor (I2),
    TL = (I1 bsl 32) bor (I0),
    OH = (TH bsr (Shift * 8)) band ?BITMASK64,
    OL = (TL bsr (Shift * 8) bor (TH bsl (64 - (Shift * 8))))
	band ?BITMASK64,
    [OL band ?BITMASK32, OL bsr 32,
     OH band ?BITMASK32, OH bsr 32].

%% SIMD 128-bit left shift simulation for little endian SIMD
%% of Shift*8 bits.

-spec sfmt_lshift128(w128(), integer()) -> w128().

sfmt_lshift128(In, Shift) ->
    [I0, I1, I2, I3] = In,
    TH = (I3 bsl 32) bor (I2),
    TL = (I1 bsl 32) bor (I0),
    OL = (TL bsl (Shift * 8)) band ?BITMASK64,
    OH = (TH bsl (Shift * 8) bor (TL bsr (64 - (Shift * 8))))
	band ?BITMASK64,
    [OL band ?BITMASK32, OL bsr 32,
     OH band ?BITMASK32, OH bsr 32].

%% The recursion formula operation of SFMT.

-spec sfmt_do_recursion(w128(), w128(), w128(), w128()) -> w128().

sfmt_do_recursion(A, B, C, D) ->
    [A0, A1, A2, A3] = A,
    [B0, B1, B2, B3] = B,
    % [C0, C1, C2, C3] = C,
    [D0, D1, D2, D3] = D,
    [X0, X1, X2, X3] = sfmt_lshift128(A, ?SFMT_SL2),
    [Y0, Y1, Y2, Y3] = sfmt_rshift128(C, ?SFMT_SR2),
    [
     A0 bxor X0 bxor ((B0 bsr ?SFMT_SR1) band ?SFMT_MSK1) bxor Y0
        bxor ((D0 bsl ?SFMT_SL1) band ?BITMASK32),
     A1 bxor X1 bxor ((B1 bsr ?SFMT_SR1) band ?SFMT_MSK2) bxor Y1
        bxor ((D1 bsl ?SFMT_SL1) band ?BITMASK32),
     A2 bxor X2 bxor ((B2 bsr ?SFMT_SR1) band ?SFMT_MSK3) bxor Y2
        bxor ((D2 bsl ?SFMT_SL1) band ?BITMASK32),
     A3 bxor X3 bxor ((B3 bsr ?SFMT_SR1) band ?SFMT_MSK4) bxor Y3
        bxor ((D3 bsl ?SFMT_SL1) band ?BITMASK32)
     ].

-spec sfmt_gen_rand_recursion(non_neg_integer(),
    [integer()], [integer()], [integer()],
    [integer()], [integer()], w128(), w128()) -> [integer()].

sfmt_gen_rand_recursion(0, Acc, _, _, _, _, _, _) ->
    lists:reverse(Acc);
sfmt_gen_rand_recursion(K, Acc, Int, AccInt, [], AccIntP, R, Q) ->
    sfmt_gen_rand_recursion(K, Acc, Int, AccInt,
		       lists:reverse(AccIntP),
		       [],
		       R, Q);
sfmt_gen_rand_recursion(K, Acc, [], AccInt, IntP, AccIntP, R, Q) ->
    sfmt_gen_rand_recursion(K, Acc,
		       lists:reverse(AccInt),
		       [],
		       IntP, AccIntP, R, Q);
sfmt_gen_rand_recursion(K, Acc, Int,
		   AccInt, IntP, AccIntP,
		   [R0, R1, R2, R3],
		   [Q0, Q1, Q2, Q3]) ->
    [A0, A1, A2, A3 | IntN ] = Int,
    [B0, B1, B2, B3 | IntPN ] = IntP,
    [X0, X1, X2, X3] = sfmt_do_recursion([A0, A1, A2, A3],
				    [B0, B1, B2, B3],
				    [R0, R1, R2, R3],
				    [Q0, Q1, Q2, Q3]),
    sfmt_gen_rand_recursion(K - 4,
		       [X3 | [X2 | [X1 | [X0 | Acc]]]],
		       IntN,
		       [X3 | [X2 | [X1 | [X0 | AccInt]]]],
		       IntPN,
		       [X3 | [X2 | [X1 | [X0 | AccIntP]]]],
		       [Q0, Q1, Q2, Q3],
		       [X0, X1, X2, X3]).

%% filling the internal state array with SFMT PRNG

-spec sfmt_gen_rand_all(sfmt_intstate()) ->
        sfmt_intstate().

sfmt_gen_rand_all(Int) ->
    [T3, T2, T1, T0, S3, S2, S1, S0 | _] = lists:reverse(Int),
    sfmt_gen_rand_recursion(?SFMT_N32, [], Int, [],
		       lists:nthtail(?SFMT_POS1 * 4, Int), [],
		       [S0, S1, S2, S3], [T0, T1, T2, T3]).

sfmt_period_modification_rec1(Parity, I) ->
    sfmt_period_modification_rec1(0, Parity, I).

sfmt_period_modification_rec1(true, _, I) ->
    {I, true};
sfmt_period_modification_rec1(32, _, I) ->
    {I, false};
sfmt_period_modification_rec1(X, Parity, I) ->
    Work = 1 bsl X,
    case (Work band Parity =/= 0) of
	true ->
	    sfmt_period_modification_rec1(true, Parity, I bxor Work);
	false ->
	    sfmt_period_modification_rec1(X + 1, Parity, I)
    end.

sfmt_period_modification(Int) ->
    [I0, I1, I2, I3 | IR ] = Int,
    {NI0, F0} = sfmt_period_modification_rec1(?SFMT_PARITY1, I0),
    {NI1, F1} = sfmt_period_modification_rec1(?SFMT_PARITY2, I1),
    {NI2, F2} = sfmt_period_modification_rec1(?SFMT_PARITY3, I2),
    {NI3, F3} = sfmt_period_modification_rec1(?SFMT_PARITY4, I3),
    % F[0-3] are true or false
    if
	F0 ->
	    [NI0, I1, I2, I3 | IR];
	F1 ->
	    [I0, NI1, I2, I3 | IR];
	F2 ->
	    [I0, I1, NI2, I3 | IR];
	F3 ->
	    [I0, I1, I2, NI3 | IR];
	true ->
	    Int
    end.

sfmt_period_certification(Int) ->
    [I0, I1, I2, I3 | _ ] = Int,
    In0 = (I0 band ?SFMT_PARITY1) bxor
	(I1 band ?SFMT_PARITY2) bxor
	(I2 band ?SFMT_PARITY3) bxor	
	(I3 band ?SFMT_PARITY4),
    In1 = In0 bxor (In0 bsr 16),
    In2 = In1 bxor (In1 bsr 8),
    In3 = In2 bxor (In2 bsr 4),
    In4 = In3 bxor (In3 bsr 2),
    In5 = In4 bxor (In4 bsr 1),
    Inner = In5 band 1,
    case Inner of
	1 ->
	    Int;
	0 ->
	    sfmt_period_modification(Int)
    end.

sfmt_func1(X) ->
    ((X bxor (X bsr 27)) * 1664525) band ?BITMASK32.

sfmt_func2(X) ->
    ((X bxor (X bsr 27)) * 1566083941) band ?BITMASK32.

sfmt_init_gen_rand_rec1(?SFMT_N32, Acc) ->
    lists:reverse(Acc);
sfmt_init_gen_rand_rec1(I, Acc) ->
    [H | _] = Acc,
    sfmt_init_gen_rand_rec1(
      I + 1,
      [((1812433253 * (H bxor (H bsr 30))) + I) band ?BITMASK32 | Acc]).

%% @doc generates an internal state from an integer seed

-spec sfmt_init_gen_rand(integer()) ->
        sfmt_intstate().

sfmt_init_gen_rand(Seed) ->
    sfmt_period_certification(
        sfmt_init_gen_rand_rec1(1, [Seed])).

sfmt_init_by_list32_rec1(0, I, _, A) ->
    {I, A};
sfmt_init_by_list32_rec1(K, I, [], A) ->
    R = sfmt_func1(array:get(I, A) bxor
		  array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) bxor
		  array:get((I + ?SFMT_N32 - 1) rem ?SFMT_N32, A)),
    A2 = array:set((I + ?SFMT_MID) rem ?SFMT_N32,
		   (array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) + R) band ?BITMASK32,
		   A),
    R2 = (R + I) band ?BITMASK32,
    A3 = array:set((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32,
		 (array:get((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32, A2) + R2) band ?BITMASK32,
		 A2),
    A4 = array:set(I, R2, A3),
    I2 = (I + 1) rem ?SFMT_N32,
    sfmt_init_by_list32_rec1(K - 1, I2, [], A4);
sfmt_init_by_list32_rec1(K, I, Key, A) ->
    R = sfmt_func1(array:get(I, A) bxor
		  array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) bxor
		  array:get((I + ?SFMT_N32 - 1) rem ?SFMT_N32, A)),
    A2 = array:set((I + ?SFMT_MID) rem ?SFMT_N32,
		   (array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) + R) band ?BITMASK32,
		   A),
    [H|T] = Key,
    R2 = (R + H + I) band ?BITMASK32,
    A3 = array:set((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32,
		   (array:get((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32, A2) + R2) band ?BITMASK32,
		   A2),
    A4 = array:set(I, R2, A3),
    I2 = (I + 1) rem ?SFMT_N32,
    sfmt_init_by_list32_rec1(K - 1, I2, T, A4).

sfmt_init_by_list32_rec2(0, _, A) ->
    A;
sfmt_init_by_list32_rec2(K, I, A) ->
    R = sfmt_func2((array:get(I, A) +
		  array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) +
		  array:get((I + ?SFMT_N32 - 1) rem ?SFMT_N32, A)) band ?BITMASK32),
    A2 = array:set((I + ?SFMT_MID) rem ?SFMT_N32,
		   (array:get((I + ?SFMT_MID) rem ?SFMT_N32, A) bxor R),
		   A),
    R2 = (R - I) band ?BITMASK32,
    A3 = array:set((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32,
		   (array:get((I + ?SFMT_MID + ?SFMT_LAG) rem ?SFMT_N32, A2) bxor R2),
		   A2),
    A4 = array:set(I, R2, A3),
    I2 = (I + 1) rem ?SFMT_N32,
    sfmt_init_by_list32_rec2(K - 1, I2, A4).

%% generates an internal state from a list of 32-bit integers

-spec sfmt_init_by_list32([integer()]) ->
    sfmt_intstate().

sfmt_init_by_list32(Key) ->
    Keylength = length(Key),

    A = array:new(?SFMT_N32, {default, 16#8b8b8b8b}),

    Count =
	if
	    Keylength + 1 > ?SFMT_N32 ->
		Keylength + 1;
	    true ->
		?SFMT_N32
	end,
    R = sfmt_func1(array:get(0, A) bxor
		  array:get(?SFMT_MID, A) bxor
		  array:get(?SFMT_N32 - 1, A)),
    A2 = array:set(?SFMT_MID,
		   (array:get(?SFMT_MID, A) + R) band ?BITMASK32,
		   A),
    R2 = (R + Keylength) band ?BITMASK32,
    A3 = array:set(?SFMT_MID + ?SFMT_LAG,
		   (array:get(?SFMT_MID + ?SFMT_LAG, A2) + R2) band ?BITMASK32,
		   A2),
    A4 = array:set(0, R2, A3),

    Count1 = Count - 1,
    {I1, A5} = sfmt_init_by_list32_rec1(Count1, 1, Key, A4),

    sfmt_period_certification(
      array:to_list(sfmt_init_by_list32_rec2(?SFMT_N32, I1, A5))).

%% Note: ran_sfmt() -> {[integer()], sfmt_intstate()}

%% generates a 32-bit random number from the given ran_sfmt()

-spec sfmt_gen_rand32
        (sfmt_intstate()) -> {integer(), ran_sfmt()};
        (ran_sfmt()) -> {integer(), ran_sfmt()}.

sfmt_gen_rand32(L) when is_list(L), length(L) =:= ?SFMT_N32 ->
    % when sfmt_intstate() is directly passed
    % note: given sfmt_intstate() is
    %       re-initialized by gen_rand_all/1
    L2 = sfmt_gen_rand_all(L),
    [H|T] = L2,
    {H, {T, L2}};
sfmt_gen_rand32({[], I}) ->
    I2 = sfmt_gen_rand_all(I),
    % this operation is sfmt_intstate() type dependent
    [H|T] = I2,
    {H, {T, I2}};
sfmt_gen_rand32({R, I}) ->
    [H|T] = R,
    {H, {T, I}}.

%%-----------------------------------------------------------------------

%% seed0: initial PRNG seed
%% Returns the default internal state

sfmt_seed0() ->
    I = sfmt_init_gen_rand(1234),
    % this operation is sfmt_intstate() type dependent
    {I, I}.

%% seed: seeding with three Integers
%% Puts the seed computed from the given integer list by init_by_list32/1
%% and puts the internal state into the process dictionary
%% and initializes the random number list with the internal state
%% and returns the old internal state (internal use only)

sfmt_seed({A1, A2, A3}) ->
    I = sfmt_init_by_list32([
            (A1 + 1) rem 4294967295,
            (A2 + 1) rem 4294967295,
            (A3 + 1) rem 4294967295]),
    % this operation is sfmt_intstate() type dependent
    {I, I}.

%% With a given state,
%% Returns a uniformly-distributed float random number X
%% where `(X > 0.0)' and `(X < 1.0)'
%% and a new state

sfmt_uniform(RS) ->
    {X, NRS} = sfmt_gen_rand32(RS),
    {(X + 0.5) * (1.0/4294967296.0), NRS}.

%% Returns a uniformly-distributed integer random number X
%% where (X >= 1) and (X =< N)
%% and a new state

sfmt_uniform(N, RS) ->
    {X, NRS} = sfmt_gen_rand32(RS),
    {trunc(X * (1.0/4294967296.0) * N) + 1, NRS}.

%% =====================================================================
%% Tiny Mersennt Twister (TinyMT) PRNG
%% Algorithm by Mutsuo Saito and Makoto Matsumoto
%% Reference URL:
%% http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/TINYMT/index.html
%% =====================================================================

%% type uint32(). 32bit unsigned integer type.

-type uint32() :: 0..16#ffffffff.

-record(tinymt_intstate32,
	{status0 :: uint32(),
	 status1 :: uint32(),
	 status2 :: uint32(),
	 status3 :: uint32(),
	 mat1 :: uint32(),
	 mat2 :: uint32(),
	 tmat :: uint32()}).

%% type tinymt_intstate32(). Internal state data type for TinyMT.
%% Internally represented as the record <code>#intstate32{}</code>,
%% including the 127bit seed and 96bit polynomial data.

-type tinymt_intstate32() ::
        #tinymt_intstate32{}.

-define(TINYMT32_SH0, 1).
-define(TINYMT32_SH1, 10).
-define(TINYMT32_SH8, 8).
-define(TINYMT32_MASK, 16#7fffffff).
-define(TINYMT32_UINT32, 16#ffffffff).

-define(TWOPOW32, 16#100000000).

-define(TINYMT32_MIN_LOOP, 8).
-define(TINYMT32_PRE_LOOP, 8).
-define(TINYMT32_LAG, 1).
-define(TINYMT32_MID, 1).
-define(TINYMT32_SIZE, 4).

%% Advance TinyMT state for one step.
%% Note: running temper function is required
%% to obtain the actual random number.

-spec tinymt_next_state(tinymt_intstate32()) ->
        tinymt_intstate32().

tinymt_next_state(R) ->
    Y0 = R#tinymt_intstate32.status3,
    X0 = R#tinymt_intstate32.status0
         bxor R#tinymt_intstate32.status1
         bxor R#tinymt_intstate32.status2,
    X1 = (X0 bxor (X0 bsl ?TINYMT32_SH0)) band ?TINYMT32_UINT32,
    Y1 = Y0 bxor (Y0 bsr ?TINYMT32_SH0) bxor X1,
    S0 = R#tinymt_intstate32.status1,
    S10 = R#tinymt_intstate32.status2,
    S20 = (X1 bxor (Y1 bsl ?TINYMT32_SH1)) band ?TINYMT32_UINT32,
    S3 = Y1,
    Y1M = (-(Y1 band 1)) band ?TINYMT32_UINT32,
    S1 = S10 bxor (R#tinymt_intstate32.mat1 band Y1M),
    S2 = S20 bxor (R#tinymt_intstate32.mat2 band Y1M),
    R#tinymt_intstate32{
        status0 = S0, status1 = S1, status2 = S2, status3 = S3}.

%% Generate 32bit unsigned integer from the TinyMT internal state.

-spec tinymt_temper(tinymt_intstate32()) -> uint32().

tinymt_temper(R) ->
    T0 = R#tinymt_intstate32.status3,
    T1 = (R#tinymt_intstate32.status0 +
         (R#tinymt_intstate32.status2 bsr ?TINYMT32_SH8))
          band ?TINYMT32_UINT32,
    T2 = T0 bxor T1,
    T1M = (-(T1 band 1)) band ?TINYMT32_UINT32,
    T2 bxor (R#tinymt_intstate32.tmat band T1M).

%% Generate 32bit-resolution float from the TinyMT internal state.
%% (Note: 0.0 &lt; result &lt; 1.0)
-spec tinymt_temper_float(tinymt_intstate32()) -> float().

tinymt_temper_float(R) ->
    (tinymt_temper(R) + 0.5) * (1.0 / 4294967296.0).

-spec tinymt_period_certification(tinymt_intstate32()) ->
        tinymt_intstate32().

%% Certify TinyMT internal state for proper seeding:
%% if the lower 127bits of the seed is all zero, reinitialize.

tinymt_period_certification(
    #tinymt_intstate32{
        status0 = 0, status1 = 0, status2 = 0, status3 = 0,
            mat1 = M1, mat2 = M2, tmat = TM}) ->
    #tinymt_intstate32{
        status0 = $T, status1 = $I, status2 = $N, status3 = $Y,
            mat1 = M1, mat2 = M2, tmat = TM};
tinymt_period_certification(
    #tinymt_intstate32{
        status0 = 16#80000000, status1 = 0, status2 = 0, status3 = 0,
                mat1 = M1, mat2 = M2, tmat = TM}) ->
    #tinymt_intstate32{
        status0 = $T, status1 = $I, status2 = $N, status3 = $Y,
            mat1 = M1, mat2 = M2, tmat = TM};
tinymt_period_certification(_R) -> _R.

-spec tinymt_ini_func1(uint32()) -> uint32().

tinymt_ini_func1(X) ->
    ((X bxor (X bsr 27)) * 1664525) band ?TINYMT32_UINT32.

-spec tinymt_ini_func2(uint32()) -> uint32().

tinymt_ini_func2(X) ->
    ((X bxor (X bsr 27)) * 1566083941) band ?TINYMT32_UINT32.

-spec tinymt_init_rec2(integer(), integer(),
        tinymt_intstate32()) -> tinymt_intstate32().

tinymt_init_rec2(I, N, R) when I =:= N ->
    R;
tinymt_init_rec2(I, N, R) when I < N ->
    R1 = tinymt_next_state(R),
    tinymt_init_rec2(I + 1, N, R1).

-spec tinymt_init_by_list32_rec1
        (integer(), integer(), [uint32()], array:array(uint32())) ->
            {integer(), array:array(uint32())}.

tinymt_init_by_list32_rec1(0, I, _, ST) ->
    {I, ST};
tinymt_init_by_list32_rec1(K, I, [], ST) ->
    RR = tinymt_ini_func1(array:get(I, ST) bxor
             array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) bxor
             array:get((I + ?TINYMT32_SIZE - 1) rem ?TINYMT32_SIZE, ST)),
    ST2 = array:set((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE,
              (array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) + RR)
               band ?TINYMT32_UINT32, ST),
    RR2 = (RR + I) band ?TINYMT32_UINT32,
    ST3 = array:set((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE,
                 (array:get((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE, ST2) + RR2) band ?TINYMT32_UINT32,
                 ST2),
    ST4 = array:set(I, RR2, ST3),
    I2 = (I + 1) rem ?TINYMT32_SIZE,
    tinymt_init_by_list32_rec1(K - 1, I2, [], ST4);
tinymt_init_by_list32_rec1(K, I, Key, ST) ->
    RR = tinymt_ini_func1(array:get(I, ST) bxor
                  array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) bxor
                  array:get((I + ?TINYMT32_SIZE - 1) rem ?TINYMT32_SIZE, ST)),
    ST2 = array:set((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE,
                   (array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) + RR) band ?TINYMT32_UINT32,
                    ST),
    [H|T] = Key,
    RR2 = (RR + H + I) band ?TINYMT32_UINT32,
    ST3 = array:set((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE,
                 (array:get((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE, ST2) + RR2) band ?TINYMT32_UINT32,
                 ST2),
    ST4 = array:set(I, RR2, ST3),
    I2 = (I + 1) rem ?TINYMT32_SIZE,
    tinymt_init_by_list32_rec1(K - 1, I2, T, ST4).

-spec tinymt_init_by_list32_rec2
        (integer(), integer(), array:array(uint32())) -> array:array(uint32()).

tinymt_init_by_list32_rec2(0, _, ST) ->
    ST;
tinymt_init_by_list32_rec2(K, I, ST) ->
    RR = tinymt_ini_func2((array:get(I, ST) +
                  array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) +
                  array:get((I + ?TINYMT32_SIZE - 1) rem ?TINYMT32_SIZE, ST)) band ?TINYMT32_UINT32),
    ST2 = array:set((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE,
                   (array:get((I + ?TINYMT32_MID) rem ?TINYMT32_SIZE, ST) bxor RR),
                   ST),
    RR2 = (RR - I) band ?TINYMT32_UINT32,
    ST3 = array:set((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE,
                   (array:get((I + ?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE, ST2) bxor RR2),
                   ST2),
    ST4 = array:set(I, RR2, ST3),
    I2 = (I + 1) rem ?TINYMT32_SIZE,
    tinymt_init_by_list32_rec2(K - 1, I2, ST4).

%% @doc Generate a TinyMT internal state from a list of 32-bit integers.

-spec tinymt_init_by_list32(tinymt_intstate32(), [uint32()]) ->
        tinymt_intstate32().

tinymt_init_by_list32(R, K) ->
    KL = length(K),
    ST = array:new(4),
    ST0 = array:set(0, 0, ST),
    ST1 = array:set(1, R#tinymt_intstate32.mat1, ST0),
    ST2 = array:set(2, R#tinymt_intstate32.mat2, ST1),
    ST3 = array:set(3, R#tinymt_intstate32.tmat, ST2),
    C =
        if
            KL + 1 > ?TINYMT32_MIN_LOOP ->
                KL + 1;
            true ->
                ?TINYMT32_MIN_LOOP
        end,
    RR1 = tinymt_ini_func1(array:get(0, ST3) bxor
                  array:get(?TINYMT32_MID rem ?TINYMT32_SIZE, ST3) bxor
                  array:get((?TINYMT32_SIZE - 1) rem ?TINYMT32_SIZE, ST3)),
    ST4 = array:set(?TINYMT32_MID rem ?TINYMT32_SIZE,
            (array:get(?TINYMT32_MID rem ?TINYMT32_SIZE, ST3) + RR1) band ?TINYMT32_UINT32,
                    ST3),
    RR2 = (RR1 + KL) band ?TINYMT32_UINT32,
    ST5 = array:set((?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE,
                   (array:get((?TINYMT32_MID + ?TINYMT32_LAG) rem ?TINYMT32_SIZE, ST4) + RR2) band ?TINYMT32_UINT32,
                    ST4),
    ST6 = array:set(0, RR2, ST5),
    C1 = C - 1,
    {I1, ST7} = tinymt_init_by_list32_rec1(C1, 1, K, ST6),
    ST8 = tinymt_init_by_list32_rec2(?TINYMT32_SIZE, I1, ST7),
    [V0, V1, V2, V3] = array:to_list(ST8),
    R1 = tinymt_period_certification(
        R#tinymt_intstate32{status0 = V0, status1 = V1,
                       status2 = V2, status3 = V3}),
    tinymt_init_rec2(0, ?TINYMT32_PRE_LOOP, R1).

%%-----------------------------------------------------------------------

%% seed0: initial PRNG seed
%% Set the default seed value to TinyMT state in the process directory
%% (Compatible with random:seed0/0).

tinymt_seed0() ->
    #tinymt_intstate32{status0 = 297425621, status1 = 2108342699,
          status2 = 4290625991, status3 = 2232209075,
          mat1 = 2406486510, mat2 = 4235788063, tmat = 932445695}.

%% Set the seed value to TinyMT state in the process directory
%% with the given three unsigned 32-bit integer arguments
%% (Compatible with random:seed/3).

tinymt_seed({A1, A2, A3}) ->
    tinymt_init_by_list32(
      tinymt_seed0(),
      [A1 band ?TINYMT32_UINT32,
       A2 band ?TINYMT32_UINT32,
       A3 band ?TINYMT32_UINT32]).

%% Generate 32bit-resolution float from the given TinyMT internal state.
%% (Note: 0.0 =&lt; result &lt; 1.0)
%% (Compatible with random:uniform_s/1)

tinymt_uniform(R0) ->
    R1 = tinymt_next_state(R0),
    {tinymt_temper_float(R1), R1}.

%% Generate 32bit-resolution float from the given TinyMT internal state.
%% (Note: 1 =&gt; result &lt;= MAX (given positive integer))

tinymt_uniform(Max, R) ->
    R1 = tinymt_next_state(R),
    {(tinymt_temper(R1) rem Max) + 1, R1}.

