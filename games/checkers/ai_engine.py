#!/usr/bin/env python3
"""
Neo-Arcade Checkers • Self-Contained AI Engine
Pure Python implementation of American / English Draughts featuring:
- Full standard rules (forced captures, multi-jumps, king promotion)
- Negamax search with Alpha-Beta pruning
- Positional heuristic evaluation (king values, center control, back-rank protection)
- 4 Calibrated ELO Difficulties (Novice to Expert)
Zero external dependencies.
"""

import random
import copy
import time

WHITE = 'w'  # Player 1 / Cyan (moves UP from rows 5..7 toward 0)
BLACK = 'b'  # Computer / Coral (moves DOWN from rows 0..2 toward 7)
WHITE_KING = 'W'
BLACK_KING = 'B'
EMPTY = '.'

# Center square coordinates (favoring center control)
CENTER_SQUARES = {
    (2, 3), (2, 5),
    (3, 2), (3, 4),
    (4, 3), (4, 5),
    (5, 2), (5, 4)
}

def create_initial_board():
    """8x8 board initialized with 12 pieces per side on dark squares."""
    board = [[EMPTY for _ in range(8)] for _ in range(8)]
    for r in range(8):
        for c in range(8):
            if (r + c) % 2 == 1:
                if r < 3:
                    board[r][c] = BLACK
                elif r > 4:
                    board[r][c] = WHITE
    return board

def board_to_str(board):
    """Serialize board to a compact 64-character string."""
    return "".join(board[r][c] for r in range(8) for c in range(8))

def board_from_str(s):
    """Deserialize 64-character string into 8x8 board."""
    board = []
    for r in range(8):
        row = []
        for c in range(8):
            row.append(s[r * 8 + c])
        board.append(row)
    return board

def is_valid_square(r, c):
    return 0 <= r < 8 and 0 <= c < 8 and (r + c) % 2 == 1

def is_white(piece):
    return piece in (WHITE, WHITE_KING)

def is_black(piece):
    return piece in (BLACK, BLACK_KING)

def is_opponent(piece, active_color):
    if active_color == WHITE:
        return is_black(piece)
    else:
        return is_white(piece)

def get_moves_for_piece(board, r, c):
    """
    Returns (quiet_moves, jump_moves) from (r, c).
    A jump move is a list of steps representing complete jump paths:
    e.g. [[(r, c), (dest_r, dest_c), (captured_r, captured_c)], ...]
    """
    piece = board[r][c]
    if piece == EMPTY:
        return [], []

    color = WHITE if is_white(piece) else BLACK
    is_king = piece in (WHITE_KING, BLACK_KING)

    # Determine movement directions
    directions = []
    if is_king:
        directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
    elif color == WHITE:
        directions = [(-1, -1), (-1, 1)]  # Moving UP (decreasing row)
    else:
        directions = [(1, -1), (1, 1)]    # Moving DOWN (increasing row)

    # 1. Quiet Moves (1-square diagonal)
    quiet_moves = []
    for dr, dc in directions:
        nr, nc = r + dr, c + dc
        if is_valid_square(nr, nc) and board[nr][nc] == EMPTY:
            quiet_moves.append({
                "from": (r, c),
                "to": (nr, nc),
                "path": [(r, c), (nr, nc)],
                "captures": []
            })

    # 2. Jump Moves (including multi-jump chains recursively)
    jump_moves = []

    def find_jumps(curr_r, curr_c, curr_piece, visited_captures, current_path):
        found_jump = False
        curr_king = curr_piece in (WHITE_KING, BLACK_KING)
        curr_dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)] if curr_king else ([(-1, -1), (-1, 1)] if is_white(curr_piece) else [(1, -1), (1, 1)])

        for dr, dc in curr_dirs:
            mid_r, mid_c = curr_r + dr, curr_c + dc
            dest_r, dest_c = curr_r + 2 * dr, curr_c + 2 * dc

            if is_valid_square(dest_r, dest_c) and (mid_r, mid_c) not in visited_captures:
                mid_piece = board[mid_r][mid_c]
                dest_piece = board[dest_r][dest_c]

                # Destination must be empty (or be the starting position of this jump chain)
                if dest_piece == EMPTY or (dest_r, dest_c) == (r, c):
                    if is_opponent(mid_piece, color):
                        found_jump = True
                        next_visited = visited_captures + [(mid_r, mid_c)]
                        next_path = current_path + [(dest_r, dest_c)]

                        # Check if crowned during jump
                        became_king = False
                        if not curr_king:
                            if (color == WHITE and dest_r == 0) or (color == BLACK and dest_r == 7):
                                became_king = True

                        # In American checkers, crowning ends turn immediately
                        if became_king:
                            jump_moves.append({
                                "from": (r, c),
                                "to": (dest_r, dest_c),
                                "path": next_path,
                                "captures": next_visited
                            })
                        else:
                            # Continue searching for further jumps
                            sub_found = find_jumps(dest_r, dest_c, curr_piece, next_visited, next_path)
                            if not sub_found:
                                jump_moves.append({
                                    "from": (r, c),
                                    "to": (dest_r, dest_c),
                                    "path": next_path,
                                    "captures": next_visited
                                })

        return found_jump

    find_jumps(r, c, piece, [], [(r, c)])
    return quiet_moves, jump_moves

def get_legal_moves(board, active_color):
    """
    Returns list of all legal moves for active_color.
    Enforces the mandatory jump rule: if ANY jump exists, only jumps are returned.
    """
    all_quiets = []
    all_jumps = []

    for r in range(8):
        for c in range(8):
            p = board[r][c]
            if (active_color == WHITE and is_white(p)) or (active_color == BLACK and is_black(p)):
                q_moves, j_moves = get_moves_for_piece(board, r, c)
                all_quiets.extend(q_moves)
                all_jumps.extend(j_moves)

    # Mandatory capture rule: if jumps exist, player MUST jump
    if all_jumps:
        return all_jumps
    return all_quiets

def apply_move(board, move):
    """Applies a move to the board in-place and returns an undo token."""
    from_r, from_c = move["from"]
    to_r, to_c = move["to"]
    piece = board[from_r][from_c]

    # Save state for undo
    captured_data = []
    for cap_r, cap_c in move["captures"]:
        captured_data.append((cap_r, cap_c, board[cap_r][cap_c]))
        board[cap_r][cap_c] = EMPTY

    board[from_r][from_c] = EMPTY

    # Check for king promotion
    promoted = False
    if piece == WHITE and to_r == 0:
        piece = WHITE_KING
        promoted = True
    elif piece == BLACK and to_r == 7:
        piece = BLACK_KING
        promoted = True

    board[to_r][to_c] = piece

    undo_token = {
        "move": move,
        "moved_piece": board[to_r][to_c],
        "original_piece": WHITE if (piece == WHITE_KING and promoted) else (BLACK if (piece == BLACK_KING and promoted) else piece),
        "promoted": promoted,
        "captured_data": captured_data
    }
    return undo_token

def undo_move(board, undo_token):
    """Reverses a move using the undo token."""
    move = undo_token["move"]
    from_r, from_c = move["from"]
    to_r, to_c = move["to"]

    board[to_r][to_c] = EMPTY
    board[from_r][from_c] = undo_token["original_piece"]

    for cap_r, cap_c, cap_piece in undo_token["captured_data"]:
        board[cap_r][cap_c] = cap_piece

def evaluate_board(board):
    """
    Heuristic evaluation from the perspective of WHITE (positive = white advantage).
    Components:
    - Piece values: Man = 100, King = 280
    - Positional advancement: +4 per rank toward king row for men
    - Center square occupancy: +10 per center square
    - Back-rank guard protection: +15 for each piece unmoved on back rank
    """
    score = 0
    w_pieces = 0
    b_pieces = 0

    for r in range(8):
        for c in range(8):
            p = board[r][c]
            if p == EMPTY:
                continue

            val = 0
            if p == WHITE:
                w_pieces += 1
                val = 100 + (7 - r) * 4  # Advancement bonus
                if r == 7:
                    val += 15            # Back rank anchor
                if (r, c) in CENTER_SQUARES:
                    val += 10
                score += val

            elif p == WHITE_KING:
                w_pieces += 1
                val = 280
                if (r, c) in CENTER_SQUARES:
                    val += 15
                score += val

            elif p == BLACK:
                b_pieces += 1
                val = 100 + r * 4        # Advancement bonus
                if r == 0:
                    val += 15            # Back rank anchor
                if (r, c) in CENTER_SQUARES:
                    val += 10
                score -= val

            elif p == BLACK_KING:
                b_pieces += 1
                val = 280
                if (r, c) in CENTER_SQUARES:
                    val += 15
                score -= val

    # Win detection
    if b_pieces == 0:
        return 99999
    if w_pieces == 0:
        return -99999

    return score

def negamax(board, depth, alpha, beta, active_color):
    """Negamax with alpha-beta pruning."""
    legal_moves = get_legal_moves(board, active_color)
    if not legal_moves:
        # No legal moves = loss for active player
        return -99999 + (10 - depth)

    if depth == 0:
        raw_eval = evaluate_board(board)
        return raw_eval if active_color == WHITE else -raw_eval

    # Move ordering: prioritize multi-captures first
    legal_moves.sort(key=lambda m: len(m["captures"]), reverse=True)

    max_score = -999999
    next_color = BLACK if active_color == WHITE else WHITE

    for move in legal_moves:
        undo = apply_move(board, move)
        score = -negamax(board, depth - 1, -beta, -alpha, next_color)
        undo_move(board, undo)

        if score > max_score:
            max_score = score
        if score > alpha:
            alpha = score
        if alpha >= beta:
            break

    return max_score

def find_best_move(board_repr, active_color=BLACK, difficulty="casual"):
    """
    Calculates best move for active_color given a board string or 2D array.
    Returns the chosen move dict:
    {
        "from": [from_r, from_c],
        "to": [to_r, to_c],
        "path": [[r0, c0], [r1, c1], ...],
        "captures": [[cr1, cc1], ...]
    }
    """
    if isinstance(board_repr, str):
        board = board_from_str(board_repr)
    else:
        board = [row[:] for row in board_repr]

    legal_moves = get_legal_moves(board, active_color)
    if not legal_moves:
        return None

    # Depth by difficulty
    if difficulty == "novice":
        # 25% random blunder, else 1-ply greedy
        if random.random() < 0.25:
            return format_move(random.choice(legal_moves))
        depth = 1
    elif difficulty == "casual":
        depth = 3
    elif difficulty == "club":
        depth = 5
    else:  # expert
        depth = 7

    # If only 1 legal move (e.g. forced jump), return immediately
    if len(legal_moves) == 1:
        return format_move(legal_moves[0])

    best_move = None
    best_score = -999999
    alpha = -999999
    beta = 999999

    next_color = BLACK if active_color == WHITE else WHITE

    # Move ordering: captures first
    legal_moves.sort(key=lambda m: len(m["captures"]), reverse=True)

    for move in legal_moves:
        undo = apply_move(board, move)
        score = -negamax(board, depth - 1, -beta, -alpha, next_color)
        undo_move(board, undo)

        # Slight jitter (within 3 points) to prevent repetitive play across matches
        adjusted_score = score + random.randint(-3, 3)

        if adjusted_score > best_score:
            best_score = adjusted_score
            best_move = move
        if score > alpha:
            alpha = score

    return format_move(best_move if best_move else random.choice(legal_moves))

def format_move(move):
    """Converts internal tuples to JSON-friendly list of lists."""
    return {
        "from": list(move["from"]),
        "to": list(move["to"]),
        "path": [list(pt) for pt in move["path"]],
        "captures": [list(pt) for pt in move["captures"]]
    }

if __name__ == "__main__":
    b = create_initial_board()
    print("Initial Checkers Board:")
    for row in b:
        print(" ".join(row))

    print("\nLegal opening moves for White (Cyan):", len(get_legal_moves(b, WHITE)))
    print("Legal opening moves for Black (Coral):", len(get_legal_moves(b, BLACK)))

    for diff in ["novice", "casual", "club", "expert"]:
        t0 = time.time()
        mv = find_best_move(b, BLACK, diff)
        elapsed = time.time() - t0
        print(f"[{diff.upper()}] Move: {mv['from']} -> {mv['to']} ({elapsed:.3f}s)")
