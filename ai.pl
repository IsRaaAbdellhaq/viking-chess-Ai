% ============================================================
%  ai.pl  —  Viking Chess (Hnefatafl) AI
%  Member 4 file
% ============================================================

:- consult('game.pl'). 

% ============================================================
% 1. DIFFICULTY LEVELS
% ============================================================

:- dynamic difficulty/1.
difficulty(easy).          % default difficulty

% Change difficulty at runtime
set_difficulty(Level) :-
    valid_difficulty(Level), !,
    retractall(difficulty(_)),
    assert(difficulty(Level)),
    format("Difficulty set to: ~w~n", [Level]).
set_difficulty(Level) :-
    format("Invalid difficulty '~w'. Choose easy/medium/hard.~n", [Level]).

valid_difficulty(easy).
valid_difficulty(medium).
valid_difficulty(hard).

% Depth for each difficulty level
depth_for(easy,   1).
depth_for(medium, 2). 
depth_for(hard,   3). 

% Get current depth
current_depth(Depth) :-
    difficulty(Level),
    depth_for(Level, Depth).


% ============================================================
% 2. UTILITY FUNCTION
% ============================================================
% Positive value  = good for DEFENDER
% Negative value  = good for ATTACKER

utility(Board, Value) :-
    % --- piece counts ---
    count_pieces(Board, a, Attackers),
    count_pieces(Board, d, Defenders),

    % --- king position ---
    ( king_position(Board, KR, KC)
    -> corner_distance(KR, KC, Dist),
       king_safety_score(Board, KR, KC, Safety)
    ;  Dist = 0, Safety = 0      % king already captured
    ),

    % --- terminal bonuses ---
    ( defenders_win(Board) -> WinBonus = 9000
    ; attackers_win(Board) -> WinBonus = -9000
    ; WinBonus = 0
    ),

    % --- final score ---
    Value is WinBonus
          + (Defenders * 10)
          - (Attackers * 8)
          - (Dist      * 15)   % closer king to corner = better for defender
          + (Safety    * 5).   % safer king = better for defender


% Distance of king to nearest corner (lower = better for defender)
corner_distance(R, C, Dist) :-
    D1 is R + C,          % distance to (0,0)
    D2 is R + (10 - C),   % distance to (0,10)
    D3 is (10 - R) + C,   % distance to (10,0)
    D4 is (10 - R) + (10 - C), % distance to (10,10)
    Dist is min(D1, min(D2, min(D3, D4))).


% King safety: count how many of the 4 surrounding squares are empty or friendly
king_safety_score(Board, R, C, Safety) :-
    R1 is R - 1, R2 is R + 1,
    C1 is C - 1, C2 is C + 1,
    Neighbors = [
        (R1, C), (R2, C),
        (R,  C1), (R, C2)
    ],
    count_safe_neighbors(Board, Neighbors, 0, Safety).

count_safe_neighbors(_, [], Acc, Acc).

count_safe_neighbors(Board, [(R, C)|Rest], Acc, Safety) :-
    ( (R >= 0, R =< 10, C >= 0, C =< 10) ->
        get_cell(Board, R, C, Cell),
        ( (Cell = e ; Cell = d ; Cell = k) -> Acc1 is Acc + 1 ; Acc1 = Acc )
    ;   Acc1 = Acc
    ),
    count_safe_neighbors(Board, Rest, Acc1, Safety).
% ============================================================
% 3. ALPHA-BETA PRUNING
% ============================================================
% alpha_beta(+Board, +Depth, +Alpha, +Beta, +Mode, -Value)

alpha_beta(Board, 0, _, _, _, Value) :-
    !,
    utility(Board, Value).

alpha_beta(Board, _, _, _, _, 9000) :-
    defenders_win(Board), !.

alpha_beta(Board, _, _, _, _, -9000) :-
    attackers_win(Board), !.

alpha_beta(Board, Depth, Alpha, Beta, maximizing, Value) :-
    all_moves(Board, defender, Moves),
    Moves \= [], !,
    Depth1 is Depth - 1,
    max_loop(Board, Moves, Depth1, Alpha, Beta, -10000, Value).

alpha_beta(_, _, _, _, maximizing, -9000) :- !.

alpha_beta(Board, Depth, Alpha, Beta, minimizing, Value) :-
    all_moves(Board, attacker, Moves),
    Moves \= [], !,
    Depth1 is Depth - 1,
    min_loop(Board, Moves, Depth1, Alpha, Beta, 10000, Value).

alpha_beta(_, _, _, _, minimizing, 9000) :- !.

max_loop(_, [], _, _, _, Best, Best).
max_loop(Board, [Move|Rest], Depth, Alpha, Beta, Current, Best) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, Alpha, Beta, minimizing, Val),
    NewCurrent is max(Current, Val),
    NewAlpha   is max(Alpha,   NewCurrent),
    ( NewAlpha >= Beta
    ->  Best = NewCurrent
    ;   max_loop(Board, Rest, Depth, NewAlpha, Beta, NewCurrent, Best)
    ).

min_loop(_, [], _, _, _, Best, Best).
min_loop(Board, [Move|Rest], Depth, Alpha, Beta, Current, Best) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, Alpha, Beta, maximizing, Val),
    NewCurrent is min(Current, Val),
    NewBeta    is min(Beta,    NewCurrent),
    ( Alpha >= NewBeta
    ->  Best = NewCurrent
    ;   min_loop(Board, Rest, Depth, Alpha, NewBeta, NewCurrent, Best)
    ).


% ============================================================
% 4. BEST MOVE SELECTION
% ============================================================
best_move(Board, Player, BestMove) :-
    current_depth(Depth),
    all_moves(Board, Player, Moves),
    Moves \= [],
    !,
    ( Player = defender
    -> StartVal = -10000, Mode = minimizing
    ;  StartVal =  10000, Mode = maximizing
    ),
    find_best(Board, Moves, Depth, Mode, StartVal, none, BestMove),
    format("Computer plays: ~w~n", [BestMove]).

best_move(_, _, none) :-
    write("Computer has no moves available."), nl.

find_best(_, [], _, _, _, Best, Best).
find_best(Board, [Move|Rest], Depth, Mode, BestVal, _, BestMove) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, -10000, 10000, Mode, Val),
    (   (Mode = minimizing, Val > BestVal)
    ;   (Mode = maximizing, Val < BestVal)
    ), !,
    find_best(Board, Rest, Depth, Mode, Val, Move, BestMove).
find_best(Board, [_|Rest], Depth, Mode, BestVal, Current, BestMove) :-
    find_best(Board, Rest, Depth, Mode, BestVal, Current, BestMove).
