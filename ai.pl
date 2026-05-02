% ============================================================
%  ai.pl  —  Viking Chess (Hnefatafl) AI
%  Member 4 file
%  Depends on: game.pl (all_moves/3, apply_move/3,
%              defenders_win/1, attackers_win/1,
%              king_position/3, count_pieces/3)
%  Until game.pl is ready, mock predicates below are used.
% ============================================================

:- consult('game.pl').
% ============================================================
% MOCK PREDICATES  (remove these once game.pl is ready)
% ============================================================

% Mock: count pieces of a given type on the board
count_pieces(Board, Type, Count) :-
    flatten(Board, Flat),
    include(==(Type), Flat, Matching),
    length(Matching, Count).

% Mock: find king position
king_position(Board, R, C) :-
    nth0(R, Board, Row),
    nth0(C, Row, k), !.

% Mock: win conditions (will be replaced by game.pl)
defenders_win(Board) :-
    king_position(Board, R, C),
    is_corner(R, C).

attackers_win(Board) :-
    \+ king_position(Board, _, _).   % king removed = captured

% Mock: all_moves — returns empty list until game.pl is ready
% REPLACE THIS with the real all_moves from game.pl
all_moves(_Board, _Player, []).

% Mock: apply_move — does nothing until game.pl is ready
% REPLACE THIS with the real apply_move from game.pl
apply_move(Board, _Move, Board).


% ============================================================
% 1. SPECIAL SQUARES
% ============================================================

is_corner(0,  0).
is_corner(0,  10).
is_corner(10, 0).
is_corner(10, 10).

is_throne(5, 5).


% ============================================================
% 2. DIFFICULTY LEVELS
% ============================================================

:- dynamic difficulty/1.
difficulty(medium).          % default difficulty

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
depth_for(medium, 3).
depth_for(hard,   5).

% Get current depth
current_depth(Depth) :-
    difficulty(Level),
    depth_for(Level, Depth).


% ============================================================
% 3. UTILITY FUNCTION
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
    ( defenders_win(Board) -> WinBonus =  9000 ; WinBonus = 0 ),
    ( attackers_win(Board) -> WinBonus = -9000 ; true ),

    % --- final score ---
    Value is WinBonus
          + (Defenders * 10)
          - (Attackers *  8)
          - (Dist      * 15)   % closer king to corner = better for defender
          + (Safety    *  5).  % safer king = better for defender


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
    ( R >= 0, R =< 10, C >= 0, C =< 10 ->
        get_cell(Board, R, C, Cell),
        ( Cell = e ; Cell = d ; Cell = k )   % empty or friendly = safe
    ->  Acc1 is Acc + 1
    ;   Acc1 = Acc
    ),
    count_safe_neighbors(Board, Rest, Acc1, Safety).


% Helper: get cell value from board
get_cell(Board, R, C, Cell) :-
    nth0(R, Board, Row),
    nth0(C, Row, Cell).


% ============================================================
% 4. ALPHA-BETA PRUNING
% ============================================================
% alpha_beta(+Board, +Depth, +Alpha, +Beta, +Mode, -Value)
% Mode: maximizing (defender's turn) | minimizing (attacker's turn)

% --- Base case: depth 0 or terminal state ---
alpha_beta(Board, 0, _, _, _, Value) :-
    !,
    utility(Board, Value).

alpha_beta(Board, _, _, _, _, 9000) :-
    defenders_win(Board), !.

alpha_beta(Board, _, _, _, _, -9000) :-
    attackers_win(Board), !.

% --- Maximizing node (defender plays) ---
alpha_beta(Board, Depth, Alpha, Beta, maximizing, Value) :-
    all_moves(Board, defender, Moves),
    Moves \= [], !,
    Depth1 is Depth - 1,
    max_loop(Board, Moves, Depth1, Alpha, Beta, -10000, Value).

% No moves for defender = attacker wins
alpha_beta(_, _, _, _, maximizing, -9000) :- !.

% --- Minimizing node (attacker plays) ---
alpha_beta(Board, Depth, Alpha, Beta, minimizing, Value) :-
    all_moves(Board, attacker, Moves),
    Moves \= [], !,
    Depth1 is Depth - 1,
    min_loop(Board, Moves, Depth1, Alpha, Beta, 10000, Value).

% No moves for attacker = defender wins
alpha_beta(_, _, _, _, minimizing, 9000) :- !.


% --- Max loop: iterate over moves, keep best (highest) value ---
max_loop(_, [], _, _, _, Best, Best).
max_loop(Board, [Move|Rest], Depth, Alpha, Beta, Current, Best) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, Alpha, Beta, minimizing, Val),
    NewCurrent is max(Current, Val),
    NewAlpha   is max(Alpha,   NewCurrent),
    ( NewAlpha >= Beta
    ->  Best = NewCurrent          % beta cut-off
    ;   max_loop(Board, Rest, Depth, NewAlpha, Beta, NewCurrent, Best)
    ).


% --- Min loop: iterate over moves, keep best (lowest) value ---
min_loop(_, [], _, _, _, Best, Best).
min_loop(Board, [Move|Rest], Depth, Alpha, Beta, Current, Best) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, Alpha, Beta, maximizing, Val),
    NewCurrent is min(Current, Val),
    NewBeta    is min(Beta,    NewCurrent),
    ( Alpha >= NewBeta
    ->  Best = NewCurrent          % alpha cut-off
    ;   min_loop(Board, Rest, Depth, Alpha, NewBeta, NewCurrent, Best)
    ).


% ============================================================
% 5. BEST MOVE SELECTION
% ============================================================
% best_move(+Board, +Player, -BestMove)
% Player: attacker | defender

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


% find_best(+Board, +Moves, +Depth, +OpponentMode,
%           +BestValSoFar, +BestMoveSoFar, -BestMove)
find_best(_, [], _, _, _, Best, Best).

find_best(Board, [Move|Rest], Depth, Mode, BestVal, _, BestMove) :-
    apply_move(Board, Move, NewBoard),
    alpha_beta(NewBoard, Depth, -10000, 10000, Mode, Val),
    (   (Mode = minimizing, Val > BestVal)   % defender maximizes
    ;   (Mode = maximizing, Val < BestVal)   % attacker minimizes
    ), !,
    find_best(Board, Rest, Depth, Mode, Val, Move, BestMove).

find_best(Board, [_|Rest], Depth, Mode, BestVal, Current, BestMove) :-
    find_best(Board, Rest, Depth, Mode, BestVal, Current, BestMove).


% ============================================================
% 6. QUICK TEST  (run with: ?- test_ai.)
% ============================================================
test_ai :-
    write('=== AI Module Test ==='), nl,

    % Load initial board from game.pl (Member 1)
    initial_board(Board),

    % Test utility
    utility(Board, Val),
    format("Utility of initial board: ~w~n", [Val]),

    % Test difficulty
    set_difficulty(hard),
    current_depth(D),
    format("Current depth (hard): ~w~n", [D]),

    % Test best_move (will return none until game.pl moves are ready)
    best_move(Board, attacker, Move),
    format("Best move for attacker: ~w~n", [Move]),

    write('=== Test Complete ==='), nl.