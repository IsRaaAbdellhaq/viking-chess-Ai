import sys
sys.stdout.reconfigure(encoding='utf-8')
import os
import pygame
import pygame.gfxdraw  
import copy  


current_dir = os.path.dirname(os.path.abspath(__file__))
swipl_home = os.path.join(current_dir, "swipl")
swipl_bin = os.path.join(swipl_home, "bin")

os.environ["SWI_HOME_DIR"] = swipl_home
if hasattr(os, 'add_dll_directory'):
    os.add_dll_directory(swipl_bin)
os.environ['PATH'] = swipl_bin + os.pathsep + os.environ.get('PATH', '')

from pyswip import Prolog

prolog = Prolog()
print("Loading Prolog files...")
prolog.consult("ai.pl")
prolog.consult("game.pl")
print("Prolog loaded successfully!")


def clean_board(raw_board):
    cleaned = []
    for row in raw_board:
        cleaned_row = []
        for cell in row:
            val = cell.value if hasattr(cell, 'value') else cell
            if isinstance(val, bytes):
                val = val.decode('utf-8')
            cleaned_row.append(str(val))
        cleaned.append(cleaned_row)
    return cleaned

def format_board_for_prolog(board):
    rows = []
    for row in board:
        rows.append("[" + ",".join(row) + "]")
    return "[" + ",".join(rows) + "]"

def check_winner(board):
    board_str = format_board_for_prolog(board)
    try:
        if list(prolog.query(f"defenders_win({board_str})")):
            return "Defender"
        if list(prolog.query(f"attackers_win({board_str})")):
            return "Attacker"
    except Exception as e:
        print(f"Error checking winner: {e}")
    return None 

def get_initial_board():
    result = list(prolog.query("initial_board(Board)"))
    if result:
        return clean_board(result[0]["Board"])
    return []


pygame.init()
pygame.font.init()

WIDTH, HEIGHT = 1200, 800
WIN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Hnefatafl - Viking Chess")

BG_COLOR = (248, 250, 252)        
BOARD_BG = (255, 255, 255)        
GRID_COLOR = (226, 232, 240)      
ATTACKER_COLOR = (26, 32, 44)     
DEFENDER_COLOR = (139, 92, 246)   
KING_COLOR = (245, 158, 11)       
HIGHLIGHT_COLOR = (0, 0, 0)
VALID_MOVE_COLOR = (192, 132, 252) 
ERROR_COLOR = (239, 68, 68)       
TEXT_COLOR = (71, 85, 105)
WHITE = (255, 255, 255)
BLACK = (30, 30, 30)

ROWS, COLS = 11, 11
SQUARE_SIZE = 54
BOARD_WIDTH = COLS * SQUARE_SIZE
BOARD_HEIGHT = ROWS * SQUARE_SIZE
BOARD_X = (WIDTH - BOARD_WIDTH) // 2
BOARD_Y = (HEIGHT - BOARD_HEIGHT) // 2


current_difficulty = "medium"


def draw_smooth_circle(surface, color, x, y, radius):
    pygame.gfxdraw.aacircle(surface, int(x), int(y), int(radius), color)
    pygame.gfxdraw.filled_circle(surface, int(x), int(y), int(radius), color)


def draw_trophy_icon(surface, x, y):
    gold = (230, 175, 45)
    pygame.draw.rect(surface, gold, (x - 12, y + 10, 24, 6), border_radius=2)
    pygame.draw.rect(surface, gold, (x - 4, y + 2, 8, 8))
    pygame.draw.polygon(surface, gold, [(x - 16, y - 12), (x + 16, y - 12), (x + 10, y + 2), (x - 10, y + 2)])
    pygame.draw.arc(surface, gold, (x - 22, y - 12, 16, 16), 1.57, 4.71, 3)
    pygame.draw.arc(surface, gold, (x + 6, y - 12, 16, 16), 4.71, 7.85, 3)

def draw_refresh_icon(surface, x, y):
    color = (30, 30, 30)
    pygame.draw.arc(surface, color, (x - 8, y - 8, 16, 16), 0.5, 5.5, 2)
    pygame.draw.polygon(surface, color, [(x + 2, y - 10), (x + 8, y - 10), (x + 5, y - 5)])

def draw_eye_icon(surface, x, y):
    color = (100, 100, 100)
    pygame.draw.ellipse(surface, color, (x - 8, y - 5, 16, 10), 2)
    draw_smooth_circle(surface, color, x, y, 3)

def draw_share_icon(surface, x, y):
    color = (100, 100, 100)
    draw_smooth_circle(surface, color, x - 6, y, 2)
    draw_smooth_circle(surface, color, x + 5, y - 5, 2)
    draw_smooth_circle(surface, color, x + 5, y + 5, 2)
    pygame.draw.line(surface, color, (x - 6, y), (x + 5, y - 5), 2)
    pygame.draw.line(surface, color, (x - 6, y), (x + 5, y + 5), 2)


def draw_dashboard(win, width, height, winner_msg, moves, elapsed_time):
    overlay = pygame.Surface((width, height), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 150)) 
    win.blit(overlay, (0, 0))
    
    card_w, card_h = 380, 420
    card_x, card_y = (width - card_w) // 2, (height - card_h) // 2
    
    shadow = pygame.Surface((card_w + 20, card_h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 40), (0, 0, card_w + 20, card_h + 20), border_radius=20)
    win.blit(shadow, (card_x - 10, card_y - 5))
    
    pygame.draw.rect(win, WHITE, (card_x, card_y, card_w, card_h), border_radius=15)
    
    circle_y = card_y + 60
    draw_smooth_circle(win, (255, 249, 230), width//2, circle_y, 40)
    draw_trophy_icon(win, width//2, circle_y)
    
    small_font = pygame.font.SysFont('Segoe UI', 11, bold=True)
    term_txt = small_font.render("Match Terminated", True, (218, 165, 32))
    term_rect = term_txt.get_rect(center=(width//2, card_y + 120))
    pygame.draw.rect(win, WHITE, term_rect.inflate(20, 10), border_radius=10)
    pygame.draw.rect(win, (255, 240, 200), term_rect.inflate(20, 10), 1, border_radius=10)
    win.blit(term_txt, term_rect)

    title_font = pygame.font.SysFont('Segoe UI', 34, bold=True)
    desc_font = pygame.font.SysFont('Segoe UI', 13)
    
    if "Defender" in winner_msg:
        title_txt = title_font.render("Defenders Win", True, BLACK)
        desc1 = "Glorious victory! The King has successfully"
        desc2 = "navigated the battlefield and reached safety."
    else:
        title_txt = title_font.render("Attackers Win", True, BLACK)
        desc1 = "The King's guard has fallen."
        desc2 = "The King is fully surrounded and captured."
        
    win.blit(title_txt, title_txt.get_rect(center=(width//2, card_y + 170)))
    win.blit(desc_font.render(desc1, True, (120, 120, 120)), desc_font.render(desc1, True, BLACK).get_rect(center=(width//2, card_y + 205)))
    win.blit(desc_font.render(desc2, True, (120, 120, 120)), desc_font.render(desc2, True, BLACK).get_rect(center=(width//2, card_y + 225)))
    
    btn_w, btn_h = 300, 45
    btn_x = (width - btn_w) // 2
    btn_y = card_y + 265
    btn_rect = pygame.Rect(btn_x, btn_y, btn_w, btn_h)
    pygame.draw.rect(win, (252, 195, 45), btn_rect, border_radius=8) 
    
    btn_font = pygame.font.SysFont('Segoe UI', 15, bold=True)
    btn_txt = btn_font.render("Play Again", True, BLACK)
    btn_txt_rect = btn_txt.get_rect(center=(width//2 + 10, btn_rect.centery))
    win.blit(btn_txt, btn_txt_rect)
    draw_refresh_icon(win, btn_txt_rect.left - 15, btn_rect.centery)
    
    sec_btn_w = (btn_w - 15) // 2
    sec_btn_h = 40
    
    review_rect = pygame.Rect(btn_x, btn_y + 55, sec_btn_w, sec_btn_h)
    pygame.draw.rect(win, (245, 245, 245), review_rect, border_radius=8)
    pygame.draw.rect(win, (220, 220, 220), review_rect, 1, border_radius=8)
    rev_txt = desc_font.render("Review Board", True, (80, 80, 80))
    rev_txt_rect = rev_txt.get_rect(center=(review_rect.centerx + 10, review_rect.centery))
    win.blit(rev_txt, rev_txt_rect)
    draw_eye_icon(win, rev_txt_rect.left - 12, review_rect.centery)
    
    share_rect = pygame.Rect(btn_x + sec_btn_w + 15, btn_y + 55, sec_btn_w, sec_btn_h)
    pygame.draw.rect(win, (245, 245, 245), share_rect, border_radius=8)
    pygame.draw.rect(win, (220, 220, 220), share_rect, 1, border_radius=8)
    share_txt = desc_font.render("Share Result", True, (80, 80, 80))
    share_txt_rect = share_txt.get_rect(center=(share_rect.centerx + 10, share_rect.centery))
    win.blit(share_txt, share_txt_rect)
    draw_share_icon(win, share_txt_rect.left - 12, share_rect.centery)
    
    stats_font = pygame.font.SysFont('Segoe UI', 10, bold=True)
    mins = elapsed_time // 60
    secs = elapsed_time % 60
    stats_str = f"MATCH DURATION: {mins}m {secs}s   •   TOTAL MOVES: {moves}"
    stats_txt = stats_font.render(stats_str, True, (170, 170, 170))
    win.blit(stats_txt, stats_txt.get_rect(center=(width//2, card_y + 380)))
    
    return {"play_again": btn_rect, "review": review_rect, "share": share_rect}


def draw_swords(surface, x, y, size):
    color = (100, 116, 139)
    offset = size // 3
    pygame.draw.line(surface, color, (x - offset, y - offset), (x + offset, y + offset), 2)
    pygame.draw.line(surface, color, (x + offset, y - offset), (x - offset, y + offset), 2)

def draw_shield(surface, x, y, size):
    color = (255, 255, 255)
    w, h = size // 2, size // 1.5
    rect = pygame.Rect(x - w//2, y - h//2, w, h)
    pygame.draw.ellipse(surface, color, rect, 2)

def draw_crown(surface, x, y, size):
    color = (255, 255, 255)
    w = size // 1.8
    h = size // 2.5
    points = [
        (x - w//2, y - h//2), (x - w//4, y + h//2), (x, y - h//4),
        (x + w//4, y + h//2), (x + w//2, y - h//2), (x + w//3, y + h//2),
        (x - w//3, y + h//2)
    ]
    pygame.draw.polygon(surface, color, points, 2)


def draw_modern_board(win, board_state, selected=None, valid_moves=[], invalid_click=None):
    win.fill(BG_COLOR)
    
    shadow_rect = pygame.Rect(BOARD_X - 10, BOARD_Y - 10, BOARD_WIDTH + 20, BOARD_HEIGHT + 20)
    pygame.draw.rect(win, (230, 235, 240), shadow_rect, border_radius=15)
    
    board_rect = pygame.Rect(BOARD_X, BOARD_Y, BOARD_WIDTH, BOARD_HEIGHT)
    pygame.draw.rect(win, BOARD_BG, board_rect, border_radius=8)
    pygame.draw.rect(win, GRID_COLOR, board_rect, 2, border_radius=8)

    for row in range(ROWS):
        for col in range(COLS):
            x = BOARD_X + col * SQUARE_SIZE
            y = BOARD_Y + row * SQUARE_SIZE
            
            pygame.draw.rect(win, GRID_COLOR, (x, y, SQUARE_SIZE, SQUARE_SIZE), 1)
            
            if (row, col) in [(0, 0), (0, 10), (10, 0), (10, 10), (5, 5)]:
                pygame.draw.rect(win, (248, 250, 252), (x+1, y+1, SQUARE_SIZE-2, SQUARE_SIZE-2))
                pygame.draw.polygon(win, (203, 213, 225), [
                    (x + SQUARE_SIZE//2, y + 10),
                    (x + SQUARE_SIZE - 10, y + SQUARE_SIZE//2),
                    (x + SQUARE_SIZE//2, y + SQUARE_SIZE - 10),
                    (x + 10, y + SQUARE_SIZE//2)
                ], 1)

            if not board_state: continue
            piece = board_state[row][col]
            center_x, center_y = x + SQUARE_SIZE // 2, y + SQUARE_SIZE // 2
            radius = SQUARE_SIZE // 2 - 8
            
            if piece == 'a':
                draw_smooth_circle(win, ATTACKER_COLOR, center_x, center_y, radius)
                draw_swords(win, center_x, center_y, radius)
            elif piece == 'd':
                draw_smooth_circle(win, DEFENDER_COLOR, center_x, center_y, radius)
                draw_shield(win, center_x, center_y, radius)
            elif piece == 'k':
                draw_smooth_circle(win, KING_COLOR, center_x, center_y, radius)
                draw_crown(win, center_x, center_y, radius)

    if selected:
        r, c = selected
        sel_x = BOARD_X + c * SQUARE_SIZE
        sel_y = BOARD_Y + r * SQUARE_SIZE
        pygame.draw.rect(win, HIGHLIGHT_COLOR, (sel_x, sel_y, SQUARE_SIZE, SQUARE_SIZE), 3)

    for r, c in valid_moves:
        dot_x = BOARD_X + c * SQUARE_SIZE + SQUARE_SIZE // 2
        dot_y = BOARD_Y + r * SQUARE_SIZE + SQUARE_SIZE // 2
        draw_smooth_circle(win, VALID_MOVE_COLOR, dot_x, dot_y, 6)

    if invalid_click and invalid_click['frames'] > 0:
        r, c = invalid_click['pos']
        err_x = BOARD_X + c * SQUARE_SIZE
        err_y = BOARD_Y + r * SQUARE_SIZE
        pygame.draw.rect(win, ERROR_COLOR, (err_x, err_y, SQUARE_SIZE, SQUARE_SIZE), SQUARE_SIZE)


def draw_sidebars(win, diff_level):
    font_title = pygame.font.SysFont('Segoe UI', 12, bold=True)
    font_btn = pygame.font.SysFont('Segoe UI', 14)
    

    diff_color = (34, 197, 94) if diff_level == "easy" else (245, 158, 11) if diff_level == "medium" else (239, 68, 68)
    win.blit(font_title.render("DIFFICULTY: ", True, TEXT_COLOR), (40, BOARD_Y - 40))
    win.blit(font_title.render(diff_level.upper(), True, diff_color), (115, BOARD_Y - 40))

    win.blit(font_title.render("GAME ACTIONS", True, TEXT_COLOR), (40, BOARD_Y))
    actions = ["New Match", "Undo Move", "Redo Move"]
    action_rects = {}
    
    for i, act in enumerate(actions):
        btn_y = BOARD_Y + 30 + (i * 40)
        rect = pygame.Rect(40, btn_y, 160, 35)
        
        # Hover effect
        mouse_pos = pygame.mouse.get_pos()
        if rect.collidepoint(mouse_pos):
            pygame.draw.rect(win, (241, 245, 249), rect, border_radius=6)
        else:
            pygame.draw.rect(win, BOARD_BG, rect, border_radius=6)
            
        pygame.draw.rect(win, GRID_COLOR, rect, 1, border_radius=6)
        win.blit(font_btn.render(act, True, (30, 41, 59)), (70, btn_y + 8))
        action_rects[act] = rect 

    win.blit(font_title.render("CASUALTIES", True, TEXT_COLOR), (WIDTH - 250, BOARD_Y))
    pygame.draw.rect(win, BOARD_BG, (WIDTH - 250, BOARD_Y + 30, 200, 60), border_radius=6)
    pygame.draw.rect(win, GRID_COLOR, (WIDTH - 250, BOARD_Y + 30, 200, 60), 1, border_radius=6)
    win.blit(font_title.render("ATTACKERS LOST", True, (148, 163, 184)), (WIDTH - 240, BOARD_Y + 40))
    win.blit(font_btn.render("No captures yet", True, (148, 163, 184)), (WIDTH - 240, BOARD_Y + 60))
    
    return action_rects

def get_row_col_from_mouse(pos):
    x, y = pos
    if BOARD_X <= x <= BOARD_X + BOARD_WIDTH and BOARD_Y <= y <= BOARD_Y + BOARD_HEIGHT:
        return (y - BOARD_Y) // SQUARE_SIZE, (x - BOARD_X) // SQUARE_SIZE
    return None, None


def run_setup_menu(win):
    clock = pygame.time.Clock()
    running = True
    
    selected_side = "attacker"
    selected_diff = "medium"
    
    title_font = pygame.font.SysFont('Segoe UI', 36, bold=True)
    header_font = pygame.font.SysFont('Segoe UI', 16, bold=True)
    font = pygame.font.SysFont('Segoe UI', 14)
    
    card_w, card_h = 500, 450
    card_x = (WIDTH - card_w) // 2
    card_y = (HEIGHT - card_h) // 2

  
    side_rects = {
        "attacker": pygame.Rect(card_x + 40, card_y + 120, 200, 60),
        "defender": pygame.Rect(card_x + 260, card_y + 120, 200, 60)
    }
    
    diff_rects = {
        "easy": pygame.Rect(card_x + 40, card_y + 250, 130, 45),
        "medium": pygame.Rect(card_x + 185, card_y + 250, 130, 45),
        "hard": pygame.Rect(card_x + 330, card_y + 250, 130, 45)
    }
    
    start_btn = pygame.Rect(card_x + 100, card_y + 350, 300, 50)
    
    while running:
        clock.tick(30)
        mouse_pos = pygame.mouse.get_pos()
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
                
            if event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:
                    for side, rect in side_rects.items():
                        if rect.collidepoint(mouse_pos):
                            selected_side = side
                    
                    for diff, rect in diff_rects.items():
                        if rect.collidepoint(mouse_pos):
                            selected_diff = diff
                            
                    if start_btn.collidepoint(mouse_pos):
                        return {"side": selected_side, "diff": selected_diff}


        win.fill(BG_COLOR)
        

        shadow = pygame.Surface((card_w + 30, card_h + 30), pygame.SRCALPHA)
        pygame.draw.rect(shadow, (0, 0, 0, 30), (0, 0, card_w + 30, card_h + 30), border_radius=20)
        win.blit(shadow, (card_x - 15, card_y - 5))
        

        pygame.draw.rect(win, WHITE, (card_x, card_y, card_w, card_h), border_radius=15)
        

        title = title_font.render("Game Setup", True, BLACK)
        win.blit(title, title.get_rect(center=(WIDTH//2, card_y + 40)))
        

        win.blit(header_font.render("1. Choose Your Side", True, TEXT_COLOR), (card_x + 40, card_y + 90))
        
        for side, rect in side_rects.items():
            is_selected = (selected_side == side)
            is_hovered = rect.collidepoint(mouse_pos)
            
  
            bg_col = (239, 246, 255) if is_selected else ((248, 250, 252) if is_hovered else WHITE)
            border_col = (59, 130, 246) if is_selected else GRID_COLOR
            
            pygame.draw.rect(win, bg_col, rect, border_radius=10)
            pygame.draw.rect(win, border_col, rect, 2, border_radius=10)
            

            if side == "attacker":
                draw_smooth_circle(win, ATTACKER_COLOR, rect.x + 30, rect.y + 30, 16)
                draw_swords(win, rect.x + 30, rect.y + 30, 16)
                win.blit(font.render("Attacker", True, BLACK), (rect.x + 60, rect.y + 12))
                win.blit(pygame.font.SysFont('Segoe UI', 11).render("You play first", True, TEXT_COLOR), (rect.x + 60, rect.y + 32))
            else:
                draw_smooth_circle(win, DEFENDER_COLOR, rect.x + 30, rect.y + 30, 16)
                draw_shield(win, rect.x + 30, rect.y + 30, 16)
                win.blit(font.render("Defender", True, BLACK), (rect.x + 60, rect.y + 12))
                win.blit(pygame.font.SysFont('Segoe UI', 11).render("Computer first", True, TEXT_COLOR), (rect.x + 60, rect.y + 32))


        win.blit(header_font.render("2. Choose AI Difficulty", True, TEXT_COLOR), (card_x + 40, card_y + 220))
        
        colors_diff = {
            "easy": (34, 197, 94), 
            "medium": (245, 158, 11),
            "hard": (239, 68, 68)   
        }
        
        for diff, rect in diff_rects.items():
            is_selected = (selected_diff == diff)
            is_hovered = rect.collidepoint(mouse_pos)
            theme_color = colors_diff[diff]
            
            if is_selected:
                pygame.draw.rect(win, theme_color, rect, border_radius=8)
                text_col = WHITE
            else:
                bg_col = (248, 250, 252) if is_hovered else WHITE
                pygame.draw.rect(win, bg_col, rect, border_radius=8)
                pygame.draw.rect(win, GRID_COLOR, rect, 1, border_radius=8)
                text_col = BLACK
                
            txt = font.render(diff.capitalize(), True, text_col)
            win.blit(txt, txt.get_rect(center=rect.center))


        start_hover = start_btn.collidepoint(mouse_pos)
        start_color = (253, 204, 69) if start_hover else (252, 195, 45) 
        
        pygame.draw.rect(win, start_color, start_btn, border_radius=10)
        
        start_txt = header_font.render("Start Battle", True, BLACK)
        win.blit(start_txt, start_txt.get_rect(center=start_btn.center))

        pygame.display.update()

def main():
    global current_board, current_difficulty
    
    move_history = []  
    redo_stack = []    
    
    def setup_match():
        nonlocal human_player, ai_player, human_pieces, total_moves, start_time, hide_dashboard
        global current_board, current_difficulty
        
        current_board = get_initial_board()
        total_moves = 0
        hide_dashboard = False
        start_time = pygame.time.get_ticks()
        
        move_history.clear()
        redo_stack.clear()

        choices = run_setup_menu(WIN)
        chosen_side = choices["side"]
        current_difficulty = choices["diff"]
        
  
        try:
            list(prolog.query(f"set_difficulty({current_difficulty})"))
            print(f"Difficulty successfully set to: {current_difficulty}")
        except Exception as e:
            print(f"Error setting AI difficulty: {e}")

        if chosen_side == "attacker":
            human_player = "attacker"
            ai_player = "defender"
            human_pieces = ['a']
        else:
            human_player = "defender"
            ai_player = "attacker"
            human_pieces = ['d', 'k']
            
    
            draw_modern_board(WIN, current_board)
            draw_sidebars(WIN, current_difficulty)
            pygame.display.update()
            
            print("Computer is thinking... (First Move)")
            new_board_str = format_board_for_prolog(current_board)
            ai_query = f"best_move({new_board_str}, {ai_player}, Move), Move \\== none, apply_move({new_board_str}, Move, FinalBoard)"
            try:
                ai_result = list(prolog.query(ai_query))
                if ai_result:
                    current_board = clean_board(ai_result[0]["FinalBoard"])
                    total_moves += 1
            except Exception as e:
                print(f"AI Error on first move: {e}")

    human_player, ai_player, human_pieces = "", "", []
    total_moves = 0
    start_time = 0
    match_duration = 0
    hide_dashboard = False
    

    setup_match()
    
    run = True
    clock = pygame.time.Clock()
    selected_square = None 
    winner_message = None
    dashboard_btns = None
    side_btns = None
    valid_destinations = []  
    invalid_click = None     
    
    while run:
        clock.tick(30)
        
        if invalid_click:
            invalid_click['frames'] -= 1
            if invalid_click['frames'] <= 0:
                invalid_click = None

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                run = False
                
            if event.type == pygame.MOUSEBUTTONDOWN:
                pos = pygame.mouse.get_pos()
                
                if winner_message and not hide_dashboard and dashboard_btns:
                    if dashboard_btns["play_again"].collidepoint(pos):
                        winner_message = None
                        selected_square = None
                        valid_destinations = []
                        setup_match()
                    elif dashboard_btns["review"].collidepoint(pos):
                        hide_dashboard = True
                    continue 
                
                if side_btns:
                    if side_btns["New Match"].collidepoint(pos):
                        winner_message = None
                        selected_square = None
                        valid_destinations = []
                        setup_match()
                        continue
                        
                    elif side_btns["Undo Move"].collidepoint(pos) and move_history:
                        redo_stack.append(copy.deepcopy(current_board))
                        current_board = copy.deepcopy(move_history.pop())
                        selected_square = None
                        valid_destinations = []
                        winner_message = None 
                        hide_dashboard = False
                        continue
                        
                    elif side_btns["Redo Move"].collidepoint(pos) and redo_stack:
                        move_history.append(copy.deepcopy(current_board))
                        current_board = copy.deepcopy(redo_stack.pop())
                        selected_square = None
                        valid_destinations = []
                        winner_message = check_winner(current_board)
                        continue
                
                if winner_message and hide_dashboard:
                    hide_dashboard = False
                    continue
                
                if not winner_message:
                    coords = get_row_col_from_mouse(pos)
                    
                    if coords != (None, None):
                        row, col = coords
                        piece = current_board[row][col]
                        
                        if piece in human_pieces:
                            if selected_square == (row, col):
                                selected_square = None
                                valid_destinations = []
                            else:
                                selected_square = (row, col)
                                valid_destinations = []
                                board_str = format_board_for_prolog(current_board)
                                query = f"legal_move({board_str}, {human_player}, move({row},{col},R,C))"
                                try:
                                    for res in prolog.query(query):
                                        valid_destinations.append((int(res['R']), int(res['C'])))
                                except Exception as e:
                                    print(f"Error fetching valid moves: {e}")
                                    
                        elif selected_square:
                            if (row, col) in valid_destinations:
                                start_row, start_col = selected_square
                                board_str = format_board_for_prolog(current_board)
                                apply_query = f"apply_move({board_str}, move({start_row},{start_col},{row},{col}), NewBoard)"
                                
                                try:
                                    result = list(prolog.query(apply_query))
                                    if result:
                                        move_history.append(copy.deepcopy(current_board))
                                        redo_stack.clear()
                                        
                                        current_board = clean_board(result[0]["NewBoard"])
                                        selected_square = None
                                        valid_destinations = []
                                        total_moves += 1 
                                        
                                        winner_message = check_winner(current_board)
                                        if winner_message:
                                            match_duration = (pygame.time.get_ticks() - start_time) // 1000
                                            
                                        if not winner_message:
                                            draw_modern_board(WIN, current_board, selected_square, valid_destinations, invalid_click)
                                            side_btns = draw_sidebars(WIN, current_difficulty)
                                            pygame.display.update()
                                            
                                            print("Computer is thinking...")
                                            new_board_str = format_board_for_prolog(current_board)
                                            ai_query = f"best_move({new_board_str}, {ai_player}, Move), Move \\== none, apply_move({new_board_str}, Move, FinalBoard)"
                                            
                                            try:
                                                ai_result = list(prolog.query(ai_query))
                                                if ai_result:
                                                    current_board = clean_board(ai_result[0]["FinalBoard"])
                                                    total_moves += 1 
                                                    winner_message = check_winner(current_board)
                                                    if winner_message:
                                                        match_duration = (pygame.time.get_ticks() - start_time) // 1000
                                                else:
                                                    winner_message = f"Defender" if human_player == 'defender' else "Attacker"
                                                    match_duration = (pygame.time.get_ticks() - start_time) // 1000
                                            except Exception as e:
                                                print(f"AI Error: {e}")
                                except Exception as e:
                                    print(f"Prolog Apply Move Error: {e}")
                            else:
                                invalid_click = {'pos': (row, col), 'frames': 15}

        draw_modern_board(WIN, current_board, selected_square, valid_destinations, invalid_click)
        side_btns = draw_sidebars(WIN, current_difficulty) 
        
        if winner_message and not hide_dashboard:
            dashboard_btns = draw_dashboard(WIN, WIDTH, HEIGHT, winner_message, total_moves, match_duration)
        elif winner_message and hide_dashboard:
            overlay = pygame.Surface((WIDTH, 40), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))
            WIN.blit(overlay, (0, 0))
            font = pygame.font.SysFont('Segoe UI', 14, bold=True)
            msg = font.render("Click anywhere to return to the Match Dashboard", True, WHITE)
            WIN.blit(msg, msg.get_rect(center=(WIDTH//2, 20)))

        pygame.display.update()
        
    pygame.quit()

if __name__ == "__main__":
    main()