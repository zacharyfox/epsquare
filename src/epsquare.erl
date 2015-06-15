%%------------------------------------------------------------------------------
%% Copyright 2015 Danila Fediashchin (danilagamma@gmail.com)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%    http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%%------------------------------------------------------------------------------
%% @doc Erlang P-Square algorithm implementation
%%
%% Algirithm description: http://www.cse.wustl.edu/~jain/papers/psqr.htm
%%
%%------------------------------------------------------------------------------
-module(epsquare).

-export([calc/2, init/2, perc/1, update/2]).

-export_type([state/0]).

-type int_array()    :: {integer(), integer(), integer(), integer(), integer()}.
-type number_array() :: {number(),  number(),  number(),  number(),  number()}.

-type heights()           :: number_array().
-type positions()         :: int_array().
-type desired_positions() :: number_array().
-type deltas()            :: number_array().

-opaque state() :: {heights(), positions(), desired_positions(), deltas()}.

%% @doc Initialize state with 5 observations
%%
-spec init([number()], float()) -> state().
init([_, _, _, _, _] = Values, P) ->
    [V1, V2, V3, V4, V5] = lists:sort(Values),
    {
        {V1,        V2,        V3,          V4, V5},
        { 1,         2,         3,           4,  5},
        { 1, 1 + 2 * P, 1 + 4 * P,   3 + 2 * P,  5},
        { 0,     P / 2,         P, (1 + P) / 2,  1}
    }.

%% @doc Get current percentile value from state
%%
-spec perc(state()) -> number().
perc({{_, _, V3, _, _}, _, _, _}) ->
    V3.

%% @doc Update state with new observation
%%
-spec update(number(), state()) -> state().
update(V, {H, N, Nh, Dh}) ->
    {K, NewH} = fit(V, H),
    NewN  = bump_n(K, N),
    NewNh = bump_nh(Nh, Dh),
    adjust(4, adjust(3, adjust(2, {NewH, NewN, NewNh, Dh}))).

%% @doc Calculate percentile value for given observations
%%
-spec calc([number()], float()) -> number().
calc([V1, V2, V3, V4, V5|R], P) ->
    perc(lists:foldl(fun update/2, init([V1, V2, V3, V4, V5], P), R)).

bump_nh({N1, N2, N3, N4, N5}, {D1, D2, D3, D4, D5}) ->
    {N1 + D1, N2 + D2, N3 + D3, N4 + D4, N5 + D5}.

bump_n(2, {N1, N2, N3, N4, N5}) ->
    bump_n(3, {N1, N2 + 1, N3, N4, N5});
bump_n(3, {N1, N2, N3, N4, N5}) ->
    bump_n(4, {N1, N2, N3 + 1, N4, N5});
bump_n(4, {N1, N2, N3, N4, N5}) ->
    bump_n(5, {N1, N2, N3, N4 + 1, N5});
bump_n(5, {N1, N2, N3, N4, N5}) ->
    {N1, N2, N3, N4, N5 + 1}.

fit(V, { V1, V2, V3, V4, V5}) when V < V1 -> {2, { V, V2, V3, V4, V5}};
fit(V, { V1, V2, V3, V4, V5}) when V > V5 -> {5, {V1, V2, V3, V4,  V}};
fit(V, {_V1, V2, V3, V4, V5} = H) ->
    K = if
            V  < V2 -> 2;
            V  < V3 -> 3;
            V  < V4 -> 4;
            V =< V5 -> 5
        end,
    {K, H}.

-define(E(I, V), (element(I, V))).

adjust(I, {H, N, Nh, Dh}) ->
    Ni = ?E(I, N),
    D  = ?E(I, Nh) - Ni,
    case should_adjust(D, I, Ni, N) of
        true ->
            Sign = sign(D),
            P    = parabolic(Sign, I, H, N),
            NewHi = case P of
                        P when ?E(I - 1, H) < P, P < ?E(I + 1, H) ->
                            P;
                        P ->
                            linear(Sign, I, H, N)
                    end,
            {setelement(I, H, NewHi), setelement(I, N, Ni + Sign), Nh, Dh};
        false ->
            {H, N, Nh, Dh}
    end.

sign(D) when D >= 0 ->  1;
sign(_)             -> -1.

should_adjust(D, I, Ni, N) when D >=  1, ?E(I + 1, N) - Ni >  1 -> true;
should_adjust(D, I, Ni, N) when D =< -1, ?E(I - 1, N) - Ni < -1 -> true;
should_adjust(_, _,  _, _)                                      -> false.

linear(D, I, H, N) ->
    Hi = ?E(I,     H),
    Hn = ?E(I + D, H),
    Ni = ?E(I,     N),
    Nn = ?E(I + D, N),
    Hi + D * (Hn - Hi) / (Nn - Ni).

parabolic(D, I, H, N) ->
    Hi = ?E(I,     H),
    Hn = ?E(I + 1, H),
    Hp = ?E(I - 1, H),
    Ni = ?E(I,     N),
    Nn = ?E(I + 1, N),
    Np = ?E(I - 1, N),
    A = D / (Nn - Np),
    B = (Ni - Np + D) * (Hn - Hi) / (Nn - Ni)
      + (Nn - Ni - D) * (Hi - Hp) / (Ni - Np),
    Hi + A * B.