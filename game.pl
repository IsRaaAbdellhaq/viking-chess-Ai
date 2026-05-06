% e = Empty, a = Attacker , d = Defender , k = King

initial_board([
    [e, e, e, a, a, a, a, a, e, e, e],
    [e, e, e, e, e, a, e, e, e, e, e],
    [e, e, e, e, e, e, e, e, e, e, e],
    [a, e, e, e, e, d, e, e, e, e, a],
    [a, e, e, e, d, d, d, e, e, e, a],
    [a, a, e, d, d, k, d, d, e, a, a],
    [a, e, e, e, d, d, d, e, e, e, a],
    [a, e, e, e, e, d, e, e, e, e, a],
    [e, e, e, e, e, e, e, e, e, e, e],
    [e, e, e, e, e, a, e, e, e, e, e],
    [e, e, e, a, a, a, a, a, e, e, e]
]).

% 2. Predicate to Print the Board 

print_board(Board) :-
    nl,
    write('      1  2  3  4  5  6  7  8  9  10 11'), nl,
    write('    -----------------------------------'), nl,
    print_rows(Board, 1),
    write('    -----------------------------------'), nl.


print_rows([], _).


print_rows([Row|RestRows], RowIndex) :-
    (RowIndex < 10 -> write(' '),write(RowIndex); write(RowIndex)),
    write(' | '),

    print_cells(Row),
    write(' |'), nl,
    NextIndex is RowIndex + 1,
    print_rows(RestRows, NextIndex).


print_cells([]).

print_cells([Cell|RestCells]) :-
    symbol(Cell, Symbol),
    write(' '), write(Symbol), write(' '),
    print_cells(RestCells).


% Maps the internal representation to symbols for printing
symbol(e, '.'). % Empty cell
symbol(a, 'A'). % Attacker 
symbol(d, 'D'). % Defender 
symbol(k, 'K'). % King


test_print :-
    initial_board(B),
    print_board(B).


% ============================================================
%  Game Logic (Member 3)
%  - Capture logic
%  - Win conditions
%  - Game controller (Human vs Computer)
% ============================================================

board_size(11).

% Special squares
is_corner(0,  0).
is_corner(0,  10).
is_corner(10, 0).
is_corner(10, 10).

is_throne(5, 5).

special_square(R, C) :-
    is_corner(R, C);
    is_throne(R, C).


% ------------------------------------------------------------
% Board helpers
% ------------------------------------------------------------
in_bounds(R, C) :-
    board_size(Size),
    R >= 0, R < Size,
    C >= 0, C < Size.

get_cell(Board, R, C, Cell) :-
    nth0(R, Board, Row),
    nth0(C, Row, Cell).

set_cell(Board, R, C, Value, NewBoard) :-
    nth0(R, Board, Row),
    replace_nth0(Row, C, Value, NewRow),
    replace_nth0(Board, R, NewRow, NewBoard).

replace_nth0([_|T], 0, X, [X|T]).
replace_nth0([H|T], I, X, [H|R]) :-
    I > 0,
    I1 is I - 1,
    replace_nth0(T, I1, X, R).


% ------------------------------------------------------------
% Piece helpers
% ------------------------------------------------------------
piece_owner(a, attacker).
piece_owner(d, defender).
piece_owner(k, defender).

friendly_piece(attacker, a).
friendly_piece(defender, d).
friendly_piece(defender, k).

capturing_piece(attacker, a).
capturing_piece(defender, d). % king is unarmed

capturable_enemy(attacker, d).
capturable_enemy(defender, a).


% ------------------------------------------------------------
% Utility predicates used by AI and controller
% ------------------------------------------------------------
count_pieces(Board, Type, Count) :-
    flatten(Board, Flat),
    include(==(Type), Flat, Matching),
    length(Matching, Count).

king_position(Board, R, C) :-
    nth0(R, Board, Row),
    nth0(C, Row, k), !.

// Name : Omar Mohamed Abdelmoez 
// ID : 20230263
% ------------------------------------------------------------
% Win conditions
% ------------------------------------------------------------
defenders_win(Board) :-
    king_position(Board, R, C),
    is_corner(R, C).

attackers_win(Board) :-
    ( \+ king_position(Board, _, _) -> true
    ; king_position(Board, R, C),
      \+ defenders_win(Board),
      king_surrounded(Board, R, C)
    ).

king_surrounded(Board, R, C) :-
    side_blocked(Board, R, C, -1,  0),
    side_blocked(Board, R, C,  1,  0),
    side_blocked(Board, R, C,  0, -1),
    side_blocked(Board, R, C,  0,  1).

side_blocked(Board, R, C, DR, DC) :-
    R1 is R + DR,
    C1 is C + DC,
    ( \+ in_bounds(R1, C1)
    -> true
    ; get_cell(Board, R1, C1, a)
    ).


% ------------------------------------------------------------
% Move application + capture logic
% ------------------------------------------------------------
apply_move(Board, move(FromR, FromC, ToR, ToC), FinalBoard) :-
    get_cell(Board, FromR, FromC, Piece),
    Piece \= e,
    basic_valid_move(Board, Piece, FromR, FromC, ToR, ToC),
    set_cell(Board, FromR, FromC, e, Board1),
    set_cell(Board1, ToR, ToC, Piece, Board2),
    ( Piece = k
    -> FinalBoard = Board2
    ; piece_owner(Piece, Player),
      capture_after_move(Board2, Player, ToR, ToC, FinalBoard)
    ).

capture_after_move(Board, Player, R, C, NewBoard) :-
    capture_positions(Board, Player, R, C, Positions),
    remove_positions(Board, Positions, NewBoard).

capture_positions(Board, Player, R, C, Positions) :-
    findall((ER, EC),
        ( direction(DR, DC),
          ER is R + DR,
          EC is C + DC,
          in_bounds(ER, EC),
          get_cell(Board, ER, EC, Enemy),
          capturable_enemy(Player, Enemy),
          SR is ER + DR,
          SC is EC + DC,
          supports_capture(Board, Player, SR, SC)
        ),
        Positions).

supports_capture(Board, Player, R, C) :-
    in_bounds(R, C),
    get_cell(Board, R, C, Cell),
    ( capturing_piece(Player, Cell)
    ; Cell = e, special_square(R, C)
    ).

remove_positions(Board, [], Board).
remove_positions(Board, [(R, C)|Rest], NewBoard) :-
    set_cell(Board, R, C, e, Board1),
    remove_positions(Board1, Rest, NewBoard).

direction(-1, 0).
direction(1, 0).
direction(0, -1).
direction(0, 1).


% ------------------------------------------------------------
% Basic move validation (used by controller and apply_move)
% ------------------------------------------------------------
basic_valid_move(Board, Piece, FromR, FromC, ToR, ToC) :-
    in_bounds(FromR, FromC),
    in_bounds(ToR, ToC),   
    (FromR \= ToR ; FromC \= ToC),
    get_cell(Board, ToR, ToC, e),
    straight_move(FromR, FromC, ToR, ToC),
    path_clear(Board, FromR, FromC, ToR, ToC),
    can_occupy(Piece, ToR, ToC).

straight_move(R1, C1, R2, C2) :-
    ( R1 = R2, C1 \= C2 )
    ; ( C1 = C2, R1 \= R2 ).

path_clear(Board, R, C1, R, C2) :-
    C1 < C2,
    CStart is C1 + 1,
    CEnd is C2 - 1,
    clear_row(Board, R, CStart, CEnd).
path_clear(Board, R, C1, R, C2) :-
    C1 > C2,
    CStart is C2 + 1,
    CEnd is C1 - 1,
    clear_row(Board, R, CStart, CEnd).
path_clear(Board, R1, C, R2, C) :-
    R1 < R2,
    RStart is R1 + 1,
    REnd is R2 - 1,
    clear_col(Board, RStart, REnd, C).
path_clear(Board, R1, C, R2, C) :-
    R1 > R2,
    RStart is R2 + 1,
    REnd is R1 - 1,
    clear_col(Board, RStart, REnd, C).

clear_row(_, _, CStart, CEnd) :-
    CStart > CEnd, !.
clear_row(Board, R, C, CEnd) :-
    get_cell(Board, R, C, e),
    C1 is C + 1,
    clear_row(Board, R, C1, CEnd).

clear_col(_, RStart, REnd, _) :-
    RStart > REnd, !.
clear_col(Board, R, REnd, C) :-
    get_cell(Board, R, C, e),
    R1 is R + 1,
    clear_col(Board, R1, REnd, C).

can_occupy(k, _, _) :- !.
can_occupy(_, R, C) :-
    \+ special_square(R, C).


% ------------------------------------------------------------
% Game controller (Human vs Computer)
% ------------------------------------------------------------
play :-
    initial_board(Board),
    choose_human_side(Human),
    play_loop(Board, attacker, Human).

choose_human_side(Human) :-
    write('Choose your side (attacker/defender): '),
    read(Side),
    ( Side = attacker
    -> Human = attacker
    ; Side = defender
    -> Human = defender
    ; write('Invalid choice. Please type attacker or defender.'), nl,
      choose_human_side(Human)
    ).

play_loop(Board, Player, Human) :-
    print_board(Board),
    ( defenders_win(Board)
    -> write('Defenders win!'), nl
    ; attackers_win(Board)
    -> write('Attackers win!'), nl
    ; take_turn(Board, Player, Human, NewBoard),
      switch_player(Player, Next),
      play_loop(NewBoard, Next, Human)
    ).

take_turn(Board, Player, Player, NewBoard) :-
    human_turn(Board, Player, NewBoard).
take_turn(Board, Player, _Human, NewBoard) :-
    computer_turn(Board, Player, NewBoard).

human_turn(Board, Player, NewBoard) :-
    format('~w turn (you). Enter move as move(RowFrom,ColFrom,RowTo,ColTo).~n', [Player]),
    read(Input),
    ( parse_move(Input, Move),
      legal_move(Board, Player, Move)
    -> apply_move(Board, Move, NewBoard)
    ; write('Invalid move. Try again.'), nl,
      human_turn(Board, Player, NewBoard)
    ).

computer_turn(Board, Player, NewBoard) :-
    ( current_predicate(best_move/3)
    -> best_move(Board, Player, Move)
    ;  fallback_computer_move(Board, Player, Move)
    ),
    ( Move == none
    -> write('Computer has no moves.'), nl,
       NewBoard = Board
    ;  apply_move(Board, Move, NewBoard)
    ).

fallback_computer_move(Board, Player, Move) :-
    ( current_predicate(all_moves/3)
    -> all_moves(Board, Player, Moves),
       Moves \= [],
       Moves = [Move|_]
    ;  Move = none
    ).

switch_player(attacker, defender).
switch_player(defender, attacker).

parse_move(move(R1, C1, R2, C2), move(RF, CF, RT, CT)) :-
    map_coord(R1, RF),
    map_coord(C1, CF),
    map_coord(R2, RT),
    map_coord(C2, CT).

map_coord(Input, Index) :-
    integer(Input),
    Input >= 1,
    Input =< 11,
    Index is Input - 1.

legal_move(Board, Player, move(FromR, FromC, ToR, ToC)) :-
    get_cell(Board, FromR, FromC, Piece),
    piece_owner(Piece, Player),
    ( current_predicate(all_moves/3)
    -> all_moves(Board, Player, Moves),
       member(move(FromR, FromC, ToR, ToC), Moves)
    ;  basic_valid_move(Board, Piece, FromR, FromC, ToR, ToC)
    ).

% ============================================================
%  Move Generation (Member 2)
% ============================================================


valid_move(StartX, StartY, Board, EndX, EndY) :-
    direction(DX, DY),
    slide(StartX, StartY, DX, DY, Board, EndX, EndY).

slide(X, Y, DX, DY, Board, NextX, NextY) :-
    NextX is X + DX,
    NextY is Y + DY,
    in_bounds(NextX, NextY),
    is_empty(Board, NextX, NextY).

slide(X, Y, DX, DY, Board, FinalX, FinalY) :-
    NextX is X + DX,
    NextY is Y + DY,
    in_bounds(NextX, NextY),
    is_empty(Board, NextX, NextY),
    slide(NextX, NextY, DX, DY, Board, FinalX, FinalY).

is_empty(Board, X, Y) :-
    get_cell(Board, X, Y, e).


all_moves(Board, Player, Moves) :-
    findall(move(FromR, FromC, ToR, ToC),
        (
            get_cell(Board, FromR, FromC, Piece),
            piece_owner(Piece, Player),
            valid_move(FromR, FromC, Board, ToR, ToC),
            can_occupy(Piece, ToR, ToC)
        ),
        Moves).