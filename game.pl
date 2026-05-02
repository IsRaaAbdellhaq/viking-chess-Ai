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