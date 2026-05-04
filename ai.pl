% ============================================================
%  ai.pl  —  Viking Chess (Hnefatafl) AI
%  Member 4 file
% ============================================================

:- consult('game.pl'). 
:- set_prolog_flag(stack_limit, 2_147_483_648).
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
% ============================================================
% OPTIMIZED BEST MOVE SELECTION
% ============================================================

% Step 1: score each move quickly using utility
score_move(Board, Player, Move, Score-Move) :-
    ( apply_move(Board, Move, NewBoard) ->
        utility(NewBoard, U)
    ;   U = 0
    ),
    ( Player = attacker -> Score is -U ; Score is U ).

% Step 2: order moves best-first for better pruning
order_moves(Board, Player, Moves, Ordered) :-
    maplist(score_move(Board, Player), Moves, Scored),
    msort(Scored, Sorted),
    ( Player = attacker
    ->  Sorted = OrderedScored
    ;   reverse(Sorted, OrderedScored)
    ),
    pairs_values(OrderedScored, Ordered).

% Step 3: limit to top N moves only
limit_moves(Moves, Limited) :-
    length(Moves, Len),
    ( Len > 15
    -> findall(M, (nth1(I, Moves, M), I =< 15), Limited)
    ;  Limited = Moves
    ).

% Step 4: best_move with all optimizations
best_move(Board, Player, BestMove) :-
    current_depth(Depth),
    all_moves(Board, Player, Moves),
    Moves \= [], !,
    order_moves(Board, Player, Moves, OrderedMoves),
    ( length(OrderedMoves, Len), Len > 12
    -> findall(M, (nth1(I, OrderedMoves, M), I =< 12), LimitedMoves)
    ;  LimitedMoves = OrderedMoves
    ),
    ( Player = defender
    -> StartVal = -10000, Mode = minimizing
    ;  StartVal =  10000, Mode = maximizing
    ),
    find_best(Board, LimitedMoves, Depth, Mode, StartVal, none, BestMove),
    format("Computer plays: ~w~n", [BestMove]).

best_move(_, _, none) :-
    write("Computer has no moves available."), nl.


% ============================================================
% FIND BEST — required by best_move
% ============================================================

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

% ============================================================
% 5. TEST PREDICATE
% run with:  ?- test_ai.
% ============================================================
% ============================================================
% 5. TEST PREDICATE
% Uncomment ONLY the difficulty level you want to test
% run with:  ?- test_ai.
% ============================================================
test_ai :-
    write('========================================'), nl,
    write('     AI Module Test - Hnefatafl         '), nl,
    write('========================================'), nl,

    % Load and print board
    initial_board(Board),
    print_board(Board),

    % Utility on initial board
    utility(Board, Val),
    format("~nUtility of initial board : ~w~n", [Val]),

    % King info
    king_position(Board, KR, KC),
    format("King position            : row=~w, col=~w~n", [KR, KC]),
    corner_distance(KR, KC, Dist),
    format("King distance to corner  : ~w~n~n", [Dist]),

    % ==========================================
    % UNCOMMENT ONLY ONE BLOCK BELOW
    % ==========================================

    % --- EASY (depth 1) --- FAST ---
    %set_difficulty(easy),
    %current_depth(D), format("Difficulty: easy | Depth: ~w~n", [D]),
    %write('Calculating attacker move...'), nl,
    %best_move(Board, attacker, AMove),
    %format("Attacker best move : ~w~n", [AMove]),
    %write('Calculating defender move...'), nl,
    %best_move(Board, defender, DMove),
    %format("Defender best move : ~w~n", [DMove]).

    % --- MEDIUM (depth 2) --- MODERATE ---
    set_difficulty(medium),
    current_depth(D), format("Difficulty: medium | Depth: ~w~n", [D]),
    write('Calculating attacker move (may take ~10 sec)...'), nl,
    best_move(Board, attacker, AMove),
    format("Attacker best move : ~w~n", [AMove]),
    write('Calculating defender move (may take ~10 sec)...'), nl,
    best_move(Board, defender, DMove),
    format("Defender best move : ~w~n", [DMove]).

    % --- HARD (depth 3) --- SLOW ---
    % set_difficulty(hard),
    % current_depth(D), format("Difficulty: hard | Depth: ~w~n", [D]),
    % write('Calculating attacker move (may take several minutes)...'), nl,
    % best_move(Board, attacker, AMove),
    % format("Attacker best move : ~w~n", [AMove]),
    % write('Calculating defender move (may take several minutes)...'), nl,
    % best_move(Board, defender, DMove),
    % format("Defender best move : ~w~n", [DMove]).