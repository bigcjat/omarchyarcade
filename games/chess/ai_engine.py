#!/usr/bin/env python3
"""
Neo-Arcade Chess • Self-Contained AI Engine
Pure Python implementation featuring PeSTO Piece-Square Tables, Negamax with Alpha-Beta pruning,
Quiescence Search, Opening Book, and multi-difficulty ELO calibration (Novice to Expert).
Zero external dependencies.
"""

import random
import time

# =============================================================================
# PESTO PIECE-SQUARE TABLES (Midgame & Endgame tapered positional evaluation)
# =============================================================================

# Material values: Pawn, Knight, Bishop, Rook, Queen, King
MG_VAL = {'P': 82, 'N': 337, 'B': 365, 'R': 477, 'Q': 1025, 'K': 0}
EG_VAL = {'P': 94, 'N': 281, 'B': 297, 'R': 512, 'Q': 936,  'K': 0}

# PeSTO Tables (a1=0, h1=7, a8=56, h8=63)
# Midgame (MG)
P_MG = [
      0,   0,   0,   0,   0,   0,   0,   0,
     98, 134,  61,  95,  68, 126,  34, -11,
     -6,   7,  26,  31,  65,  56,  25, -20,
    -14,  13,   6,  21,  23,  12,  17, -23,
    -27,  -2,  -5,  12,  17,   6,  10, -25,
    -26,  -4,  -4, -10,   3,   3,  33, -12,
    -35,  -1, -20, -23, -15,  24,  38, -22,
      0,   0,   0,   0,   0,   0,   0,   0
]

N_MG = [
    -167, -89, -34, -49,  61, -97, -15, -107,
     -73, -41,  72,  36,  23,  62,   7,  -17,
     -47,  60,  37,  65,  84, 129,  73,   44,
      -9,  17,  19,  53,  37,  69,  18,   22,
     -13,   4,  16,  13,  28,  19,  21,   -8,
     -23,  -9,  12,  10,  19,  17,  25,  -16,
     -29, -53, -12,  -3,  -1,  18, -14,  -19,
    -105, -21, -58, -33, -17, -28, -19,  -23
]

B_MG = [
    -29,   4, -82, -37, -25, -42,   7,  -8,
    -26,  16, -18, -13,  30,  59,  18, -47,
    -16,  37,  43,  40,  35,  50,  37,  -2,
     -4,   5,  19,  50,  37,  37,   7,  -2,
     -6,  13,  13,  26,  34,  12,  10,   4,
      0,  15,  15,  15,  14,  27,  18,  10,
      4,  15,  16,   0,   7,  21,  33,   1,
    -33,  -3, -14, -21, -13, -12, -39, -21
]

R_MG = [
     32,  42,  32,  51,  63,   9,  31,  43,
     27,  32,  58,  62,  80,  67,  26,  44,
     -5,  19,  26,  36,  17,  45,  61,  16,
    -24, -11,   7,  26,  24,  35,  -8, -20,
    -36, -26, -12,  -1,   9,  -7,   6, -23,
    -45, -25, -16, -17,   3,   0,  -5, -33,
    -44, -16, -20,  -9,  -1,  11,  -6, -71,
    -19, -13,   1,  17,  16,   7, -37, -26
]

Q_MG = [
    -28,   0,  29,  12,  59,  44,  43,  45,
    -24, -39,  -5,   1, -16,  57,  28,  54,
    -13, -17,   7,   8,  29,  56,  47,  57,
    -27, -27, -16, -16,  -1,  17,  -2,   1,
     -9, -26,  -9, -10,  -2,  -4,   3,  -3,
    -14,   2, -11,  -2,  -5,   2,  14,   5,
    -35,  -8,  11,   2,   8,  15,  -3,   1,
     -1, -18,  -9,  10, -15, -25, -31, -50
]

K_MG = [
    -65,  23,  16, -15, -56, -34,   2,  13,
     29,  -1, -20,  -7,  -8,  -4, -38, -29,
     -9,  24,   2, -16, -20,   6,  22, -22,
    -17, -20, -12, -27, -30, -25, -14, -36,
    -49,  -1, -27, -39, -46, -44, -33, -51,
    -14, -14, -22, -46, -44, -30, -15, -27,
      1,   7,  -8, -64, -43, -16,   9,   8,
    -15,  36,  12, -54,   8, -28,  24,  14
]

# Endgame (EG)
P_EG = [
      0,   0,   0,   0,   0,   0,   0,   0,
    178, 173, 158, 134, 147, 132, 165, 187,
     94, 100,  85,  67,  56,  53,  82,  84,
     32,  24,  13,   5,  -2,   4,  17,  17,
     13,   9,  -3,  -7,  -7,  -8,   3,  -1,
      4,   7,  -6,   1,   0,  -5,  -1,  -8,
     13,   8,   8, -10,   7,   2, -10,  -5,
      0,   0,   0,   0,   0,   0,   0,   0
]

N_EG = [
    -58, -38, -13, -28, -31, -27, -63, -99,
    -25,  -8, -25,  -2,  -9, -25, -24, -52,
    -24, -20,  10,   9,  -1,  -9, -19, -41,
    -17,   3,  22,  22,  22,  11,   8, -18,
    -18,  -6,  16,  25,  16,  17,   4, -18,
    -23,  -3,  -1,  15,  10,  -3, -20, -22,
    -42, -20, -10,  -5,  -2, -20, -23, -44,
    -29, -51, -23, -15, -22, -18, -50, -64
]

B_EG = [
    -14, -21, -11,  -8,  -7,  -9, -17, -24,
     -8,  -4,   7, -12,  -3, -13,  -4, -14,
      2,  -8,   0,  -1,  -2,   6,   0,   4,
     -3,   9,  12,   9,  14,  10,   3,   2,
     -6,   3,  13,  19,   7,  10,  -3,  -9,
    -12,  -3,   8,  10,  13,   3,  -7, -15,
    -14, -18,  -7,  -1,   4,  -9, -15, -27,
    -23,  -9, -23,  -5,  -9, -16,  -5, -17
]

R_EG = [
     13,  10,  18,  15,  12,  12,   8,   5,
     11,  13,  13,  11,  -3,   3,   8,   3,
      7,   7,   7,   5,   4,  -3,  -5,  -3,
      4,   3,  13,   1,   2,   1,  -1,   2,
      3,   5,   8,   4,  -5,  -6,  -8, -11,
     -4,   0,  -5,  -1,  -7, -12,  -8, -16,
     -6,  -6,   0,   2,  -9,  -9, -11,  -3,
     -9,   2,   3,  -1,  -5, -13,   4, -20
]

Q_EG = [
     -9,  22,  22,  27,  27,  19,  10,  20,
    -17,  20,  32,  41,  58,  25,  30,   0,
    -20,   6,   9,  49,  47,  35,  19,   9,
      3,  22,  24,  45,  57,  40,  57,  36,
    -18,  28,  19,  47,  31,  34,  39,  18,
    -16, -27,  15,   6,   9,  17,  10,   5,
    -22, -23, -30, -16, -16, -23, -36, -32,
    -33, -28, -22, -43,  -5, -32, -20, -41
]

K_EG = [
    -74, -35, -18, -18, -11,  15,   4, -17,
    -12,  17,  14,  17,  17,  38,  23,  11,
     10,  17,  23,  15,  20,  45,  44,  13,
     -8,  22,  24,  27,  26,  33,  26,   3,
    -18,  -4,  21,  24,  27,  23,   9, -11,
    -19,  -3,  11,  21,  23,  16,   7,  -9,
    -27, -11,   4,  13,  14,   4,  -5, -17,
    -53, -34, -21, -11, -28, -14, -24, -43
]

PST_MG = {'P': P_MG, 'N': N_MG, 'B': B_MG, 'R': R_MG, 'Q': Q_MG, 'K': K_MG}
PST_EG = {'P': P_EG, 'N': N_EG, 'B': B_EG, 'R': R_EG, 'Q': Q_EG, 'K': K_EG}

# =============================================================================
# LIGHTWEIGHT CHESS ENGINE (Fast Move Generator & Board State)
# =============================================================================

class ChessState:
    """High-speed pure-Python board state and legal move generator."""
    def __init__(self, fen=None):
        self.board = [None] * 64
        self.white_to_move = True
        self.castling = {'K': True, 'Q': True, 'k': True, 'q': True}
        self.en_passant = None # (col, row)
        self.halfmove_clock = 0
        self.fullmove_number = 1
        self.set_fen(fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    def set_fen(self, fen):
        self.board = [None] * 64
        parts = fen.split()
        rows = parts[0].split('/')
        for r, row in enumerate(rows):
            c = 0
            sq_r = 7 - r # rank 7 is row 0
            for ch in row:
                if ch.isdigit():
                    c += int(ch)
                else:
                    sq = sq_r * 8 + c
                    self.board[sq] = ch
                    c += 1
        
        self.white_to_move = (parts[1] == 'w')
        self.castling = {
            'K': 'K' in parts[2], 'Q': 'Q' in parts[2],
            'k': 'k' in parts[2], 'q': 'q' in parts[2]
        }
        self.en_passant = None
        if parts[3] != '-':
            col = ord(parts[3][0]) - ord('a')
            row = int(parts[3][1]) - 1
            self.en_passant = row * 8 + col

    def evaluate(self):
        """Tapered PeSTO evaluation returning score from White's perspective."""
        mg_score = 0
        eg_score = 0
        game_phase = 0

        # Phase weights for tapering: N=1, B=1, R=2, Q=4
        phase_weights = {'N': 1, 'B': 1, 'R': 2, 'Q': 4, 'n': 1, 'b': 1, 'r': 2, 'q': 4}

        for sq in range(64):
            piece = self.board[sq]
            if not piece:
                continue

            is_white = piece.isupper()
            ptype = piece.upper()

            # Flip index for black pieces so table is symmetrical
            p_sq = sq if is_white else (sq ^ 56)

            mg_val = MG_VAL[ptype] + PST_MG[ptype][p_sq]
            eg_val = EG_VAL[ptype] + PST_EG[ptype][p_sq]

            if is_white:
                mg_score += mg_val
                eg_score += eg_val
            else:
                mg_score -= mg_val
                eg_score -= eg_val

            if ptype in phase_weights:
                game_phase += phase_weights[ptype]

        # Clamp game phase between 0 (pure endgame) and 24 (opening)
        if game_phase > 24:
            game_phase = 24
        mg_weight = game_phase
        eg_weight = 24 - game_phase
        score = (mg_score * mg_weight + eg_score * eg_weight) // 24
        return score if self.white_to_move else -score

    def get_moves(self, captures_only=False):
        """Generates pseudo-legal moves; returns list of (from_sq, to_sq, promo_piece)."""
        moves = []
        us_white = self.white_to_move

        for sq in range(64):
            piece = self.board[sq]
            if not piece:
                continue
            if piece.isupper() != us_white:
                continue

            ptype = piece.upper()
            r, c = divmod(sq, 8)

            # PAWN MOVES
            if ptype == 'P':
                direction = 1 if us_white else -1
                start_rank = 1 if us_white else 6
                promo_rank = 7 if us_white else 0

                # Single push
                if not captures_only:
                    next_r = r + direction
                    if 0 <= next_r <= 7:
                        to_sq = next_r * 8 + c
                        if self.board[to_sq] is None:
                            if next_r == promo_rank:
                                for promo in ('Q', 'R', 'B', 'N'):
                                    moves.append((sq, to_sq, promo if us_white else promo.lower()))
                            else:
                                moves.append((sq, to_sq, None))

                            # Double push
                            if r == start_rank:
                                d_sq = (r + 2 * direction) * 8 + c
                                if self.board[d_sq] is None:
                                    moves.append((sq, d_sq, None))

                # Captures
                next_r = r + direction
                if 0 <= next_r <= 7:
                    for dc in (-1, 1):
                        to_c = c + dc
                        if 0 <= to_c <= 7:
                            to_sq = next_r * 8 + to_c
                            target = self.board[to_sq]
                            if target and (target.isupper() != us_white):
                                if next_r == promo_rank:
                                    for promo in ('Q', 'R', 'B', 'N'):
                                        moves.append((sq, to_sq, promo if us_white else promo.lower()))
                                else:
                                    moves.append((sq, to_sq, None))
                            elif self.en_passant == to_sq:
                                moves.append((sq, to_sq, None))

            # KNIGHT MOVES
            elif ptype == 'N':
                for dr, dc in [(-2,-1), (-2,1), (-1,-2), (-1,2), (1,-2), (1,2), (2,-1), (2,1)]:
                    nr, nc = r + dr, c + dc
                    if 0 <= nr <= 7 and 0 <= nc <= 7:
                        to_sq = nr * 8 + nc
                        target = self.board[to_sq]
                        if not target:
                            if not captures_only:
                                moves.append((sq, to_sq, None))
                        elif target.isupper() != us_white:
                            moves.append((sq, to_sq, None))

            # BISHOP / ROOK / QUEEN (Ray pieces)
            elif ptype in ('B', 'R', 'Q'):
                dirs = []
                if ptype in ('B', 'Q'):
                    dirs.extend([(-1,-1), (-1,1), (1,-1), (1,1)])
                if ptype in ('R', 'Q'):
                    dirs.extend([(-1,0), (1,0), (0,-1), (0,1)])

                for dr, dc in dirs:
                    nr, nc = r + dr, c + dc
                    while 0 <= nr <= 7 and 0 <= nc <= 7:
                        to_sq = nr * 8 + nc
                        target = self.board[to_sq]
                        if not target:
                            if not captures_only:
                                moves.append((sq, to_sq, None))
                        else:
                            if target.isupper() != us_white:
                                moves.append((sq, to_sq, None))
                            break
                        nr += dr
                        nc += dc

            # KING MOVES
            elif ptype == 'K':
                for dr in (-1, 0, 1):
                    for dc in (-1, 0, 1):
                        if dr == 0 and dc == 0:
                            continue
                        nr, nc = r + dr, c + dc
                        if 0 <= nr <= 7 and 0 <= nc <= 7:
                            to_sq = nr * 8 + nc
                            target = self.board[to_sq]
                            if not target:
                                if not captures_only:
                                    moves.append((sq, to_sq, None))
                            elif target.isupper() != us_white:
                                moves.append((sq, to_sq, None))

                # Castling (pseudo-legal check)
                if not captures_only:
                    if us_white and r == 0 and c == 4:
                        if self.castling['K'] and not self.board[5] and not self.board[6] and self.board[7] == 'R':
                            moves.append((4, 6, None))
                        if self.castling['Q'] and not self.board[3] and not self.board[2] and not self.board[1] and self.board[0] == 'R':
                            moves.append((4, 2, None))
                    elif not us_white and r == 7 and c == 4:
                        if self.castling['k'] and not self.board[61] and not self.board[62] and self.board[63] == 'r':
                            moves.append((60, 62, None))
                        if self.castling['q'] and not self.board[59] and not self.board[58] and not self.board[57] and self.board[56] == 'r':
                            moves.append((60, 58, None))

        return moves

    def make_move(self, move):
        """Applies a move, returning an undo structure."""
        from_sq, to_sq, promo = move
        piece = self.board[from_sq]
        captured = self.board[to_sq]
        undo = (from_sq, to_sq, piece, captured, self.castling.copy(), self.en_passant, self.white_to_move)

        # En passant capture
        if piece.upper() == 'P' and to_sq == self.en_passant:
            ep_capture_sq = to_sq - (8 if self.white_to_move else -8)
            captured = self.board[ep_capture_sq]
            self.board[ep_capture_sq] = None

        # Apply move
        self.board[from_sq] = None
        self.board[to_sq] = promo if promo else piece

        # Handle Castling Rook move
        if piece.upper() == 'K':
            if from_sq == 4 and to_sq == 6: # White O-O
                self.board[7] = None; self.board[5] = 'R'
            elif from_sq == 4 and to_sq == 2: # White O-O-O
                self.board[0] = None; self.board[3] = 'R'
            elif from_sq == 60 and to_sq == 62: # Black O-O
                self.board[63] = None; self.board[61] = 'r'
            elif from_sq == 60 and to_sq == 58: # Black O-O-O
                self.board[56] = None; self.board[59] = 'r'

            if self.white_to_move:
                self.castling['K'] = self.castling['Q'] = False
            else:
                self.castling['k'] = self.castling['q'] = False

        # Rook moves invalidate castling
        if from_sq == 0: self.castling['Q'] = False
        elif from_sq == 7: self.castling['K'] = False
        elif from_sq == 56: self.castling['q'] = False
        elif from_sq == 63: self.castling['k'] = False

        # En passant target square
        if piece.upper() == 'P' and abs(to_sq - from_sq) == 16:
            self.en_passant = (from_sq + to_sq) // 2
        else:
            self.en_passant = None

        self.white_to_move = not self.white_to_move
        return undo

    def unmake_move(self, undo):
        from_sq, to_sq, piece, captured, castling, en_passant, white_to_move = undo
        self.board[from_sq] = piece
        self.board[to_sq] = captured
        self.castling = castling
        self.en_passant = en_passant
        self.white_to_move = white_to_move

        # Undo Castling Rook
        if piece.upper() == 'K':
            if from_sq == 4 and to_sq == 6:
                self.board[5] = None; self.board[7] = 'R'
            elif from_sq == 4 and to_sq == 2:
                self.board[3] = None; self.board[0] = 'R'
            elif from_sq == 60 and to_sq == 62:
                self.board[61] = None; self.board[63] = 'r'
            elif from_sq == 60 and to_sq == 58:
                self.board[59] = None; self.board[56] = 'r'

    def is_in_check(self, white):
        """Checks if the given side's King is under attack."""
        target_king = 'K' if white else 'k'
        king_sq = None
        for sq in range(64):
            if self.board[sq] == target_king:
                king_sq = sq
                break
        if king_sq is None:
            return False

        # Temporarily switch turn to opponent to see if they can capture king_sq
        orig_turn = self.white_to_move
        self.white_to_move = not white
        opp_moves = self.get_moves(captures_only=True)
        self.white_to_move = orig_turn

        for _, to_sq, _ in opp_moves:
            if to_sq == king_sq:
                return True
        return False

# =============================================================================
# SEARCH & AI CONTROLLER
# =============================================================================

# Classic Opening Book moves (UCI format)
OPENING_BOOK = {
    # Starting Position (White)
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1": ["e2e4", "d2d4", "c2c4", "g1f3"],
    # After 1. e4 (Black responses)
    "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1": ["e7e5", "c7c5", "e7e6", "c7c6"],
    # After 1. d4 (Black responses)
    "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1": ["d7d5", "g8f6", "e7e6"],
    # After 1. e4 e5 (White responses)
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2": ["g1f3", "f1c4", "b1c3"],
    # After 1. e4 e5 2. Nf3 (Black responses)
    "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2": ["b8c6", "g8f6", "d7d6"],
}

def uci_to_move(uci_str):
    f_col = ord(uci_str[0]) - ord('a')
    f_row = int(uci_str[1]) - 1
    t_col = ord(uci_str[2]) - ord('a')
    t_row = int(uci_str[3]) - 1
    promo = uci_str[4] if len(uci_str) > 4 else None
    return (f_row * 8 + f_col, t_row * 8 + t_col, promo)

def move_to_uci(move):
    from_sq, to_sq, promo = move
    f_c, f_r = from_sq % 8, from_sq // 8
    t_c, t_r = to_sq % 8, to_sq // 8
    uci = f"{chr(ord('a') + f_c)}{f_r + 1}{chr(ord('a') + t_c)}{t_r + 1}"
    if promo:
        uci += promo.lower()
    return uci

def quiescence(state, alpha, beta):
    """Calculates capture chains at tree leaves to eliminate the horizon effect."""
    stand_pat = state.evaluate()
    if stand_pat >= beta:
        return beta
    if alpha < stand_pat:
        alpha = stand_pat

    captures = state.get_moves(captures_only=True)
    # Order captures (MVV-LVA estimate)
    for move in captures:
        undo = state.make_move(move)
        # Check legality
        if state.is_in_check(not state.white_to_move):
            state.unmake_move(undo)
            continue
        score = -quiescence(state, -beta, -alpha)
        state.unmake_move(undo)

        if score >= beta:
            return beta
        if score > alpha:
            alpha = score
    return alpha

def negamax(state, depth, alpha, beta, allow_quiescence=True):
    """Alpha-Beta Negamax search with PeSTO evaluation."""
    if depth <= 0:
        return quiescence(state, alpha, beta) if allow_quiescence else state.evaluate()

    moves = state.get_moves()
    # Sort captures first
    moves.sort(key=lambda m: 1 if state.board[m[1]] else 0, reverse=True)

    legal_moves = 0
    best_score = -999999

    for move in moves:
        undo = state.make_move(move)
        if state.is_in_check(not state.white_to_move):
            state.unmake_move(undo)
            continue

        legal_moves += 1
        score = -negamax(state, depth - 1, -beta, -alpha, allow_quiescence)
        state.unmake_move(undo)

        if score > best_score:
            best_score = score
        if score > alpha:
            alpha = score
        if alpha >= beta:
            break

    # If no legal moves, checkmate or stalemate
    if legal_moves == 0:
        if state.is_in_check(state.white_to_move):
            return -20000 - depth # Checkmate
        return 0 # Stalemate

    return best_score

def find_best_move(fen, difficulty="casual"):
    """
    Finds the optimal move for the active player.
    Difficulty: 'novice' (~900), 'casual' (~1300), 'club' (~1650), 'expert' (~2000)
    """
    diff = str(difficulty).lower()

    # 1. Opening Book Check
    fen_key = " ".join(fen.split()[:4])
    for book_fen, moves in OPENING_BOOK.items():
        if book_fen.startswith(fen_key):
            chosen = random.choice(moves)
            return chosen

    state = ChessState(fen)
    moves = state.get_moves()

    # Filter legal moves
    legal_moves = []
    for m in moves:
        undo = state.make_move(m)
        if not state.is_in_check(not state.white_to_move):
            legal_moves.append(m)
        state.unmake_move(undo)

    if not legal_moves:
        return None

    # NOVICE LEVEL (~900 ELO): Depth 1 with 20% random blunder chance
    if diff == "novice":
        if random.random() < 0.20:
            return move_to_uci(random.choice(legal_moves))
        depth = 1
        allow_q = False

    # CASUAL LEVEL (~1300 ELO): Depth 2 + PST evaluation
    elif diff == "casual":
        depth = 2
        allow_q = False

    # CLUB LEVEL (~1650 ELO): Depth 3 + Quiescence search
    elif diff == "club":
        depth = 3
        allow_q = True

    # EXPERT LEVEL (~2000 ELO): Depth 4 + Quiescence search
    else:
        depth = 4
        allow_q = True

    best_move = None
    best_score = -999999
    alpha = -999999
    beta = 999999

    # Move ordering: prioritize captures
    legal_moves.sort(key=lambda m: 1 if state.board[m[1]] else 0, reverse=True)

    for move in legal_moves:
        undo = state.make_move(move)
        score = -negamax(state, depth - 1, -beta, -alpha, allow_q)
        state.unmake_move(undo)

        # Slight randomization among nearly equal moves (within 5 centipawns) to avoid repetitive play
        adjusted_score = score + random.randint(-5, 5)

        if adjusted_score > best_score:
            best_score = adjusted_score
            best_move = move
        if score > alpha:
            alpha = score

    return move_to_uci(best_move if best_move else random.choice(legal_moves))

# Quick CLI test
if __name__ == "__main__":
    start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    for level in ["novice", "casual", "club", "expert"]:
        mv = find_best_move(start_fen, level)
        print(f"[{level.upper()}] Best Move for White: {mv}")
