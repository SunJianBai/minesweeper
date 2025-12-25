.386
.model flat,stdcall
option casemap:none

; ==== 基础库与 Win32 库 ====
include windows.inc
include user32.inc
include gdi32.inc
include kernel32.inc
include msvcrt.inc
; 使用 winmm 播放 mp3 点击音效
include winmm.inc

includelib user32.lib
includelib gdi32.lib
includelib kernel32.lib
includelib msvcrt.lib
includelib winmm.lib

printf PROTO C:PTR SBYTE,:VARARG
scanf PROTO C:PTR SBYTE,:VARARG
; MCI 字符串命令接口，用于播放 mp3
mciSendStringA PROTO :DWORD,:DWORD,:DWORD,:DWORD

.stack 4096

.data
; ==== 窗口相关常量 ====
; 基础窗口大小（适合简单难度），更大棋盘会在运行时放大窗口
WINDOW_WIDTH  EQU 600
WINDOW_HEIGHT EQU 500

; 每个格子的像素边长（适当缩小格子尺寸）
CELL_SIZE     EQU 24
; 棋盘默认左上角坐标（仅用于初始化，真正布局在运行时计算）
BOARD_ORG_X   EQU 100
BOARD_ORG_Y   EQU 100

GRID_SIZE     EQU 10         ; 10x10 棋盘

; 重置按钮区域
RESET_BTN_X   EQU 20
RESET_BTN_Y   EQU 20
RESET_BTN_W   EQU 80
RESET_BTN_H   EQU 30

; ==== 全局句柄 ====
hInstance  DWORD ?
hWinMain   DWORD ?

hFontCell  DWORD ?           ; 绘制数字/旗子的字体
hBrushClosed DWORD ?         ; 未翻开格子刷子
hBrushOpen   DWORD ?         ; 已翻开格子刷子
hBrushMine   DWORD ?         ; 地雷格子刷子
hBrushFlag   DWORD ?         ; 旗子底色
; 被点中的雷用红色，其它雷用橙色
hBrushMineOther DWORD ?      ; 其他雷格子刷子

; 格子位图与内存 DC（用于从 MINE_COLOR.BMP 贴图绘制格子）
hBmpMine     DWORD ?         ; MINE_COLOR.BMP 的位图句柄
hMemMineDC   DWORD ?         ; 选择了 hBmpMine 的内存 DC

; ==== 布局与窗口尺寸（根据难度动态更新）====
gWinWidth   DWORD WINDOW_WIDTH
gWinHeight  DWORD WINDOW_HEIGHT
board_org_x DWORD BOARD_ORG_X
board_org_y DWORD BOARD_ORG_Y
row_stride  DWORD 40         ; 每行字节数 = board_width * 4，默认 10*4
total_cells DWORD 100        ; 总格子数 = board_width * board_height

; ==== 字符串 ====
szClassName   BYTE "MineClass",0
szCaptionMain BYTE "Minesweeper",0

szResetText   BYTE "Reset",0

; 菜单文本（使用英文避免编码问题）
szMenuEasy    BYTE "Easy",0
szMenuMedium  BYTE "Medium",0
szMenuExpert  BYTE "Expert",0

board_width BYTE 10 ;棋盘宽度（列数）
board_height BYTE 10 ;棋盘高度（行数）
mine_count BYTE 10 ;地雷数量
mines_left BYTE 10 ;剩余地雷数量
cells_left DWORD 90 ;剩余未打开格子数量,每翻开一个非雷格子减1,游戏胜利条件:cells_left=0

; 最大支持 16x30 棋盘：480 格，每格 4 字节，共 1920 字节
board_grid BYTE 1920 DUP(0); ;棋盘格子数据,每个格子4字节 
game_state BYTE 0 ;0-未开始 1-进行中 2-失败 3-胜利

largeVal QWORD 0              ; 用于存储查询的高精度计数器值

szMsg BYTE "Welcome to Minesweeper!",0ah,0
MsgSeed BYTE "Random Seed is %d",0ah,0

MsgTest_random BYTE "random() generated: %d",0ah,0
MsgTest_get_time_seed BYTE "get_time_seed() returned: %d",0ah,0
MsgTest_random_mod_100 BYTE "random_mod_100() returned: %d",0ah,0
MsgPlaceMines BYTE "Placing Mines In %d",0ah,0

MsgNewLine BYTE 0ah,0

MsgCell_info_mid BYTE "%d %d %d %d,",0
MsgCell_info_end BYTE "%d %d %d %d",0   ;放在最后一个不加逗号


;输入输出相关数据
;get_cell_state相关数据
MsgInputPrompt BYTE "Input: Op(1=Click, 2=Flag) Row Col: ",0
InputFormat BYTE "%d %d %d",0
input_op DWORD ?
input_x DWORD ?
input_y DWORD ?
MsgOutputCellState BYTE "Cell(%d,%d) State : %08X",0ah,0




;游戏结束语
MsgGameOver_fail BYTE "BOOM! You hit a mine! Game Over.",0ah , 0
MsgGameOver_win BYTE "Congratulations! You cleared all the mines!",0ah , 0

MsgClickInfo   BYTE "Click (%d,%d) op=%d",0ah,0
MsgFlagInfo    BYTE "Toggle flag (%d,%d)",0ah,0

szMinesLeftFmt BYTE "Mines left: %d",0

szTimeFmt      BYTE "Time: %d s",0

; 点击 / 爆炸音效相关 MCI 命令字符串（音效文件嵌入资源，运行时释放到临时目录）
szTempDir       BYTE 260 DUP(0)        ; 临时目录
szClickTmpPath  BYTE 260 DUP(0)        ; 点击音效临时文件完整路径
szBoomTmpPath   BYTE 260 DUP(0)        ; 爆炸音效临时文件完整路径

szClickTmpFmt   BYTE "%sms_click.mp3",0
szBoomTmpFmt    BYTE "%sms_boom.mp3",0

szMciOpenClickCmd BYTE 260 DUP(0)
szMciOpenBoomCmd  BYTE 260 DUP(0)
szMciOpenFmtClick BYTE "open ""%s"" alias clicksnd",0
szMciOpenFmtBoom  BYTE "open ""%s"" alias boomsnd",0

szMciPlayClick BYTE "play clicksnd from 0",0
szMciCloseClick BYTE "close clicksnd",0
szMciPlayBoom BYTE "play boomsnd from 0",0
szMciCloseBoom BYTE "close boomsnd",0
MsgMciOpenErr  BYTE "[MCI] open res\\click.mp3 error: %u",0ah,0
MsgMciPlayErr  BYTE "[MCI] play clicksnd error: %u",0ah,0
MsgMciOpenBoomErr BYTE "[MCI] open res\\boom.mp3 error: %u",0ah,0
MsgMciPlayBoomErr BYTE "[MCI] play boomsnd error: %u",0ah,0

; 调试信息
MsgMainStart   BYTE "[DEBUG] main start",0ah,0
MsgWinMainStart BYTE "[DEBUG] WinMain start",0ah,0
MsgAfterRegClass BYTE "[DEBUG] RegisterClassEx done",0ah,0
MsgAfterCreateWin BYTE "[DEBUG] CreateWindowEx done",0ah,0
MsgWMCreate    BYTE "[DEBUG] WM_CREATE",0ah,0
MsgInitGameStart BYTE "[DEBUG] init_game start",0ah,0
MsgInitGameEnd   BYTE "[DEBUG] init_game end",0ah,0
MsgPlaceStart    BYTE "[DEBUG] r_places_mines start",0ah,0
MsgPlaceEnd      BYTE "[DEBUG] r_places_mines end",0ah,0

start_tick     DWORD 0        ; 第一次点击时的时间戳（GetTickCount）
elapsed_sec    DWORD 0        ; 胜利时总用时（秒）
timer_started  BYTE  0        ; 是否已经开始计时

szWinTimeText  BYTE 64 DUP(0) ; 胜利时 MessageBox 使用的时间字符串缓冲区

; 记录最后一次点击到的雷的索引（0~total_cells-1），-1 表示无
last_click_index DWORD 0FFFFFFFFh

; 标记最近一次点击是否踩雷（0=否，1=是），用于播放爆炸音效
last_click_is_mine BYTE 0


seed DWORD ? ;随机数种子
location DWORD ? ;地雷埋放位置

; 菜单命令 ID
IDM_DIFF_EASY   EQU 1001
IDM_DIFF_MEDIUM EQU 1002
IDM_DIFF_EXPERT EQU 1003

; 资源 ID（嵌入的 mp3）
IDR_CLICK_MP3   EQU 2001
IDR_BOOM_MP3    EQU 2002

; 资源 ID（格子位图，需与 resource.h 中保持一致）
IDB_MINE_COLOR  EQU 131

.code
;获取系统时间并用作种子
get_time_seed PROC
    INVOKE QueryPerformanceCounter, OFFSET largeVal
    MOV EAX, DWORD PTR largeVal
    AND EAX, 07FFFFFFFh ;确保种子为正数
    MOV seed, EAX
    RET
get_time_seed ENDP

;伪随机数生成函数（线性同余法）
random PROC
    MOV EAX, seed
    IMUL EAX, 041C64E6DH ;乘法常数
    ADD EAX, 03039H       ;增量常数
    XOR EDX, EDX
    MOV ECX , 07FFFFFFFh    ;模数=2^31-1
    DIV ECX               ;取模
    MOV seed, EDX           ;余数作为种子
    MOV EAX, EDX           ;返回值
    RET
random ENDP

;伪随机数生成函数（取模100）
random_mod_100 PROC
    CALL random
    XOR EDX, EDX
    MOV ECX, 100
    DIV ECX
    MOV location, EDX
    MOV EAX, EDX ;返回值为0~99
    RET
random_mod_100 ENDP

;随机布雷
r_places_mines PROC
    LOCAL Number:DWORD, total:DWORD

    INVOKE printf, OFFSET MsgPlaceStart

    INVOKE get_time_seed

    ; 计算总格子数 total = board_width * board_height
    MOVZX EAX, board_width
    MOVZX ECX, board_height
    IMUL EAX, ECX
    MOV total, EAX

    MOVZX EAX, mine_count
    MOV Number, EAX   ;保存地雷数量

loop_random:
    ; 调用 random 获取一个随机数，然后对 total 取模
    CALL random
    XOR EDX, EDX
    MOV ECX, total
    DIV ECX                ; EAX = 商, EDX = 余数(0 ~ total-1)

    ; 使用余数作为格子索引
    MOV EAX, EDX

    ;检查该位置是否已放置地雷
    MOV EBX, OFFSET board_grid  ;board_grid地址
    MOV DL, [EBX + EAX*4]       ;DL存放该格子的一个字节
    CMP DL, 1                   ;1表示已放置地雷
    JE loop_random              ;如果已放置地雷，重新生成位置

    ;如果该位置未放置地雷，则放置地雷
    MOV DL, 1                   ;1表示放置地雷
    MOV [EBX + EAX*4], DL

    PUSH EAX
    INVOKE printf, OFFSET MsgPlaceMines, EAX
    POP EAX

    DEC Number
    CMP Number, 0
    JNE loop_random

    INVOKE printf, OFFSET MsgPlaceEnd
    RET
r_places_mines ENDP


;计算每个格子周围的地雷数（支持可变棋盘大小）
calc_around_mines PROC
    LOCAL row:DWORD, col:DWORD
    LOCAL dr:DWORD, dc:DWORD
    LOCAL nr:DWORD, nc:DWORD
    LOCAL cur_off:DWORD
    LOCAL count:DWORD

    PUSH ESI
    PUSH EDI

    MOV ESI, OFFSET board_grid ; board_grid 基址
    MOV row, 0

row_loop_calc:
    ; if row >= board_height -> done
    MOV EAX, row
    MOVZX ECX, board_height
    CMP EAX, ECX
    JGE cac_done

    MOV col, 0

col_loop_cals:
    ; if col >= board_width -> next row
    MOV EAX, col
    MOVZX ECX, board_width
    CMP EAX, ECX
    JGE next_row_calc

    ; cur_off = row * row_stride + col * 4
    MOV EAX, row
    MOV ECX, row_stride
    IMUL ECX                 ; EAX = row * row_stride
    MOV ECX, col
    SHL ECX, 2
    ADD EAX, ECX
    MOV cur_off, EAX

    ; 若本格子有地雷，则跳过
    MOV AL, [ESI + EAX]
    CMP AL, 1
    JE next_cell_calc

    MOV count, 0

    ; dr 从 -1 到 1
    MOV dr, 0FFFFFFFFh

dr_loop:
    MOV EAX, dr
    CMP EAX, 2          ; dr > 1 ?
    JGE dr_done

    ; dc 从 -1 到 1
    MOV dc, 0FFFFFFFFh

dc_loop:
    MOV EAX, dc
    CMP EAX, 2          ; dc > 1 ?
    JGE dc_done

    ; 跳过自身 (0,0)
    MOV EAX, dr
    CMP EAX, 0
    JNE do_neighbor
    MOV EAX, dc
    CMP EAX, 0
    JE next_dc

do_neighbor:
    ; nr = row + dr
    MOV EAX, row
    ADD EAX, dr
    MOV nr, EAX

    ; nc = col + dc
    MOV EAX, col
    ADD EAX, dc
    MOV nc, EAX

    ; 检查边界: 0 <= nr < board_height, 0 <= nc < board_width
    MOV EAX, nr
    CMP EAX, 0
    JL next_dc
    MOVZX ECX, board_height
    CMP EAX, ECX
    JGE next_dc

    MOV EAX, nc
    CMP EAX, 0
    JL next_dc
    MOVZX ECX, board_width
    CMP EAX, ECX
    JGE next_dc

    ; nr * row_stride + nc * 4
    MOV EAX, nr
    MOV ECX, row_stride
    IMUL ECX                 ; EAX = nr * row_stride
    MOV ECX, nc
    SHL ECX, 2
    ADD EAX, ECX

    ; 若邻居是雷，计数+1
    MOV AL, [ESI + EAX]
    CMP AL, 1
    JNE next_dc
    MOV EAX, count
    INC EAX
    MOV count, EAX

next_dc:
    MOV EAX, dc
    INC EAX
    MOV dc, EAX
    JMP dc_loop

dc_done:
    MOV EAX, dr
    INC EAX
    MOV dr, EAX
    JMP dr_loop

dr_done:
    ; 将周围地雷数（0-8）写入第 4 个字节
    MOV EAX, cur_off
    MOV EDX, count
    MOV [ESI + EAX + 3], DL

next_cell_calc:
    ; col++
    MOV EAX, col
    INC EAX
    MOV col, EAX
    JMP col_loop_cals

next_row_calc:
    MOV EAX, row
    INC EAX
    MOV row, EAX
    JMP row_loop_calc

cac_done:
    POP EDI
    POP ESI
    RET
calc_around_mines ENDP


;获取并显示当前游戏状态
get_game_state PROC
    LOCAL bMine:BYTE, bOpen:BYTE, bFlag:BYTE, bAroundMines:BYTE
    ;bMine:是否有地雷, bOpen:是否打开, bFlag:是否插旗, bAroundMines:周围地雷数
    ;PUSH EBP
    ;MOV EBP, ESP
    PUSH EBX
    PUSH ESI
    PUSH EDI 

    MOV ESI, OFFSET board_grid ;board_grid地址
    XOR EDI , EDI         ;row = 0

row_loop_get:
    XOR EBX, EBX          ;col = 0

col_loop_get:
    ;offset = row * row_stride + col * 4
    MOV EAX, EDI            ; row
    MOV ECX, row_stride
    IMUL ECX                ; EAX = row * row_stride
    MOV ECX, EBX            ; col
    SHL ECX, 2              ; col * 4
    ADD EAX, ECX            ; offset

    MOV EDX, EAX
    MOV AL, [ESI + EDX] ;取出格子数据的第一个字节
    MOV bMine, AL
    MOV AL, [ESI + EDX +1]; 取出格子数据的第二个字节
    MOV bOpen, AL
    MOV AL, [ESI + EDX +2]; 取出格子数据的第三个字节
    MOV bFlag, AL
    MOV AL, [ESI + EDX +3]; 取出格子数据的第四个字节
    MOV bAroundMines, AL

    ; 判断是否是本行最后一个单元（col == board_width-1）
    MOV EAX, EBX
    MOVZX ECX, board_width
    DEC ECX
    CMP EAX, ECX
    JE last_in_row
    
    ; 保存 ESI（board_grid 基址）
    PUSH ESI
    
    MOVZX EAX, bAroundMines  ; 注意：参数从右到左压栈
    PUSH EAX
    MOVZX EAX, bFlag
    PUSH EAX
    MOVZX EAX, bOpen
    PUSH EAX
    MOVZX EAX, bMine
    PUSH EAX
    PUSH OFFSET MsgCell_info_mid
    CALL printf
    ADD ESP, 20  ; 清理栈（5个参数 * 4字节）
    
    ; 恢复 ESI
    POP ESI
    JMP after_print

last_in_row:
    ; 保存 ESI
    PUSH ESI
    
    MOVZX EAX, bAroundMines
    PUSH EAX
    MOVZX EAX, bFlag
    PUSH EAX
    MOVZX EAX, bOpen
    PUSH EAX
    MOVZX EAX, bMine
    PUSH EAX
    PUSH OFFSET MsgCell_info_end
    CALL printf
    ADD ESP, 20
    
    ; 恢复 ESI
    POP ESI
    
after_print:

    ; 下一列
    INC EBX
    MOVZX EAX, board_width
    CMP EBX, EAX
    JL col_loop_get

    INVOKE printf, OFFSET MsgNewLine

    ; 下一行
    INC EDI
    MOVZX EAX, board_height
    CMP EDI, EAX
    JL row_loop_get

    POP EDI
    POP ESI
    POP EBX
    ;MOV ESP, EBP
    ;POP EBP
    RET
get_game_state ENDP

;获取指定格子的状态
;参数: x-行号(0-9), y-列号(0-9)
;返回值: EAX-格子的4字节状态数据
;   BYTE 0: 是否有地雷(1-有,0-无)
;   BYTE 1: 是否打开(1-打开,0-未打开)
;   BYTE 2: 是否插旗(1-插旗,0-未插旗)
;   BYTE 3: 周围地雷数(0-8)
get_cell_state PROC x:DWORD, y:DWORD
    ; 计算偏移量 offset = x * 40 + y * 4
    ; x 是行号，每行 40 BYTE
    ; y 是列号，一个格子 4 BYTE

    MOV EAX, x      ; EAX = 行号
    MOV ECX, row_stride
    IMUL ECX        ; EAX = 行号 * row_stride

    MOV ECX, y      ; ECX = 列号
    SHL ECX , 2     ; ECX = 列号 * 4

    ADD EAX, ECX    ; EAX = offset

    MOV EDX, OFFSET board_grid  ; board_grid 基址
    MOV EAX, [EDX + EAX]        ; EAX = board_grid[offset]

    RET
get_cell_state ENDP

;递归展开空白区域
;参数: x-行号(0-9), y-列号(0-9)
expand_blank PROC USES EBX ESI EDI x:DWORD, y:DWORD
    LOCAL i:DWORD, j:DWORD

    ;1. 边界检查(0 ~ board_height-1, 0 ~ board_width-1)
    CMP x, 0
    JL ret_expand
    MOVZX EAX, board_height
    DEC EAX
    CMP x, EAX
    JG ret_expand
    CMP y, 0
    JL ret_expand
    MOVZX EAX, board_width
    DEC EAX
    CMP y, EAX
    JG ret_expand

    ;2. 计算地址并获取指针
    MOV EAX, x
    MOV ECX, row_stride
    IMUL ECX            ; EAX = x * row_stride
    MOV ECX, y
    SHL ECX, 2
    ADD EAX, ECX        ;EAX = offset
    MOV ESI, OFFSET board_grid ;board_grid基址
    ADD ESI, EAX        ;ESI = &board_grid[offset]

    ;3. 检查是否已打开
    ;如果已翻开(第2个字节=1)或已插旗(第3个字节=1),则跳过
    MOV AL, [ESI + 1]   ;Open byte
    CMP AL, 1
    JE ret_expand
    MOV AL, [ESI + 2]   ;Flag byte
    CMP AL, 1
    JE ret_expand

    ;4. 翻开当前格子(第2个字节=1)
    MOV BYTE PTR [ESI + 1], 1

    ;=== 更新剩余格子数 ===
    DEC cells_left
    CMP cells_left, 0
    JNE check_around_mines
    ;如果剩余格子数为0，设置游戏状态为胜利
    MOV game_state, 3
    JMP ret_expand

check_around_mines:
    ;5. 检查周围雷数(第三个字节)
    ; 如果周围有雷(>0)，则停止扩散(只翻开边界上的数字格)
    MOV AL, [ESI + 3]
    CMP AL, 0
    JNE ret_expand

    ;6. 如果周围无雷(=0)，递归展开8个方向,一列一列地展开
    MOV i, 0FFFFFFFFh
loop_i:
    MOV j, 0FFFFFFFFh
loop_j:
    ;跳过(0,0)自己
    CMP i, 0
    JNE do_recurse
    CMP j, 0
    JE next_j   ;跳过自己

do_recurse:
    ;计算邻居坐标并递归调用
    MOV EAX, x
    ADD EAX, i
    MOV EBX, y
    ADD EBX, j
    ;递归调用
    INVOKE expand_blank, EAX, EBX

next_j:
    INC j
    CMP j, 1
    JLE loop_j

    INC i
    CMP i, 1
    JLE loop_i

ret_expand:
    RET
expand_blank ENDP


; 点开格子逻辑
; 参数: x-行号(0-9), y-列号(0-9)
click_cell PROC x:DWORD, y:DWORD
    ; 默认认为本次点击不是雷
    MOV last_click_is_mine, 0
    ;1. 边界检查(0 ~ board_height-1, 0 ~ board_width-1)
    CMP x, 0
    JL ret_click
    MOVZX EAX, board_height
    DEC EAX
    CMP x, EAX
    JG ret_click
    CMP y, 0
    JL ret_click
    MOVZX EAX, board_width
    DEC EAX
    CMP y, EAX
    JG ret_click

    ;2. 计算地址并获取指针
    MOV EAX, x
    MOV ECX, row_stride
    IMUL ECX            ; EAX = x * row_stride
    MOV ECX, y
    SHL ECX, 2
    ADD EAX, ECX        ;EAX = offset
    MOV EDX, OFFSET board_grid ;board_grid基址
    ADD EDX, EAX        ;EDX = &board_grid[offset]

    ;3. 检查状态,是否插旗或已翻开
    MOV AL, [EDX + 2]   ;Flag byte
    CMP AL, 1
    JE ret_click      ;有旗子，不能点开
    MOV AL, [EDX + 1]   ;Open byte
    CMP AL, 1
    JE ret_click      ;已翻开，不能点开


    ;4. 检查是否有地雷
    MOV AL, [EDX]     ;Mine byte
    CMP AL, 1
    JE hit_mine

    ;5. 安全,调用 expand_blank 递归展开
    INVOKE expand_blank, x, y
    JMP ret_click

hit_mine:
    ; 记录被点击雷的索引 index = x * board_width + y
    MOV EAX, x
    MOVZX ECX, board_width
    IMUL EAX, ECX
    ADD EAX, y
    MOV last_click_index, EAX

    ; 标记本次点击踩到了雷
    MOV last_click_is_mine, 1

    ; 翻开所有雷并设置游戏状态为失败
    CALL reveal_all_mines
    MOV BYTE PTR game_state, 2

ret_click:
    RET
click_cell ENDP


; 插旗/取消旗
; 参数: x-行号(0-9), y-列号(0-9)
toggle_flag PROC x:DWORD, y:DWORD
    ;1. 边界检查(0 ~ board_height-1, 0 ~ board_width-1)
    CMP x, 0
    JL ret_flag
    MOVZX EAX, board_height
    DEC EAX
    CMP x, EAX
    JG ret_flag
    CMP y, 0
    JL ret_flag
    MOVZX EAX, board_width
    DEC EAX
    CMP y, EAX
    JG ret_flag

    ;2. 计算地址并获取指针
    MOV EAX, x
    MOV ECX, row_stride
    IMUL ECX            ; EAX = x * row_stride
    MOV ECX, y
    SHL ECX, 2
    ADD EAX, ECX        ;EAX = offset
    MOV EDX, OFFSET board_grid ;board_grid基址
    ADD EDX, EAX        ;EDX = &board_grid[offset]

    ;3. 检查是否已翻开(第2个字节),已翻开不能插旗
    MOV AL , [EDX + 1]
    CMP AL, 1
    JE ret_flag

    ;4. 切换旗子状态(第3个字节)
    MOV AL, [EDX + 2]
    CMP AL, 1
    JE remove_flag

    ;插旗
    MOV BYTE PTR [EDX +2], 1  ;设置插旗标志
    DEC mines_left            ;剩余地雷数减1
    JMP ret_flag

remove_flag:
    ;取消旗
    MOV BYTE PTR [EDX +2], 0  ;取消插旗标志
    INC mines_left          ;剩余地雷数加1


ret_flag:
    RET
toggle_flag ENDP

; 翻开棋盘上所有的雷格子（将其 Open 字节设为 1）
reveal_all_mines PROC
    PUSH EAX
    PUSH ECX
    PUSH ESI

    MOV ESI, OFFSET board_grid
    XOR ECX, ECX              ; cell index 0..total_cells-1

ram_loop:
    MOV EAX, total_cells
    CMP ECX, EAX
    JGE ram_done

    MOV AL, [ESI + ECX*4]     ; bMine
    CMP AL, 1
    JNE ram_next

    ; 设置已翻开标志
    MOV BYTE PTR [ESI + ECX*4 + 1], 1

ram_next:
    INC ECX
    JMP ram_loop

ram_done:
    POP ESI
    POP ECX
    POP EAX
    RET
reveal_all_mines ENDP

; 游戏初始化: 清空棋盘、重新布雷、计算周围雷数，设置初始状态
init_game PROC
    PUSH EAX
    PUSH ECX
    PUSH EDX
    PUSH EDI

    INVOKE printf, OFFSET MsgInitGameStart

    ; 清空 board_grid 最大区域
    LEA EDI, board_grid
    MOV ECX, 1920
    XOR EAX, EAX
    REP STOSB

    ; 初始化计数
    MOV AL, mine_count
    MOV mines_left, AL

    ; 计算布局相关值（row_stride、total_cells、board_org_x/board_org_y）
    CALL update_layout

    ; cells_left = total_cells - mine_count
    MOV EAX, total_cells
    MOVZX EDX, mine_count
    SUB EAX, EDX
    MOV cells_left, EAX

    MOV game_state, 1          ; 游戏进行中

    ; 随机布雷并计算周围雷数
    INVOKE r_places_mines
    INVOKE calc_around_mines

    ; 控制台输出当前棋盘，便于调试
    INVOKE get_game_state
    INVOKE printf, OFFSET MsgNewLine

    INVOKE printf, OFFSET MsgInitGameEnd

    POP EDI
    POP EDX
    POP ECX
    POP EAX
    RET
init_game ENDP

; 将嵌入资源中的二进制数据写出到指定路径的文件
; 参数: resID (资源 ID), pPath(指向完整路径缓冲区)
; 返回: EAX = 0 表示成功, 非 0 表示失败
extract_resource_to_file PROC USES EBX ESI EDI resID:DWORD, pPath:DWORD
    LOCAL hResInfo:DWORD, hResData:DWORD, pBytes:DWORD
    LOCAL dwSize:DWORD, hFile:DWORD, written:DWORD

    ; 查找资源
    INVOKE FindResource, hInstance, resID, RT_RCDATA
    TEST EAX, EAX
    JZ erf_fail
    MOV hResInfo, EAX

    ; 加载资源
    INVOKE LoadResource, hInstance, EAX
    TEST EAX, EAX
    JZ erf_fail
    MOV hResData, EAX

    ; 锁定资源，取得数据指针
    INVOKE LockResource, EAX
    TEST EAX, EAX
    JZ erf_fail
    MOV pBytes, EAX

    ; 获取资源大小
    INVOKE SizeofResource, hInstance, hResInfo
    TEST EAX, EAX
    JZ erf_fail
    MOV dwSize, EAX

    ; 创建目标文件
    INVOKE CreateFile, pPath, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    CMP EAX, INVALID_HANDLE_VALUE
    JE erf_fail
    MOV hFile, EAX

    ; 写入数据
    INVOKE WriteFile, hFile, pBytes, dwSize, ADDR written, NULL

    ; 关闭文件句柄
    INVOKE CloseHandle, hFile

    XOR EAX, EAX
    RET

erf_fail:
    MOV EAX, 1
    RET
extract_resource_to_file ENDP

; 根据当前棋盘宽高，更新 row_stride、total_cells 和棋盘在窗口中的位置
update_layout PROC
    LOCAL board_pix_w:DWORD, board_pix_h:DWORD

    PUSH EAX
    PUSH ECX

    ; 计算每行字节数 row_stride = board_width * 4
    MOVZX EAX, board_width
    IMUL EAX, 4
    MOV row_stride, EAX

    ; 计算总格子数 total_cells = board_width * board_height
    MOVZX EAX, board_width
    MOVZX ECX, board_height
    IMUL EAX, ECX
    MOV total_cells, EAX

    ; 计算棋盘像素宽高
    ; board_pix_w = board_width * CELL_SIZE
    MOVZX EAX, board_width
    IMUL EAX, CELL_SIZE
    MOV board_pix_w, EAX

    ; board_pix_h = board_height * CELL_SIZE
    MOVZX ECX, board_height
    IMUL ECX, CELL_SIZE
    MOV board_pix_h, ECX

    ; 根据棋盘大小计算期望的客户端宽高，并至少不小于基础 WINDOW_* 尺寸
    ; gWinWidth = max(WINDOW_WIDTH, board_pix_w + 80)
    MOV EAX, board_pix_w
    ADD EAX, 80              ; 左右各留 40 像素空白
    MOV ECX, WINDOW_WIDTH
    CMP EAX, ECX
    JGE @f
    MOV EAX, ECX
@@:
    MOV gWinWidth, EAX

    ; gWinHeight = max(WINDOW_HEIGHT, board_pix_h + 160)
    MOV EAX, board_pix_h
    ADD EAX, 160             ; 顶部用于按钮/时间/雷数，底部留空白
    MOV ECX, WINDOW_HEIGHT
    CMP EAX, ECX
    JGE @f_height
    MOV EAX, ECX
@f_height:
    MOV gWinHeight, EAX

    ; 计算棋盘左上角位置
    ; 水平居中：board_org_x = (gWinWidth - board_pix_w) / 2
    MOV EAX, gWinWidth
    SUB EAX, board_pix_w
    SHR EAX, 1
    MOV board_org_x, EAX

    ; 垂直方向：在顶部预留 80 像素 HUD，再在剩余空间中居中
    ; board_org_y = 80 + (gWinHeight - 80 - board_pix_h) / 2
    MOV EAX, gWinHeight
    SUB EAX, board_pix_h
    SUB EAX, 80
    SHR EAX, 1
    ADD EAX, 80
    MOV board_org_y, EAX

    POP ECX
    POP EAX
    RET
update_layout ENDP

; 根据 gWinWidth/gWinHeight 调整主窗口实际大小
resize_main_window PROC hWnd:DWORD
    LOCAL rc:RECT

    PUSH EAX
    PUSH EBX
    PUSH ECX
    PUSH EDX

    ; 期望的客户端区域：0,0,gWinWidth,gWinHeight
    MOV rc.left, 0
    MOV rc.top, 0
    MOV EAX, gWinWidth
    MOV rc.right, EAX
    MOV EAX, gWinHeight
    MOV rc.bottom, EAX

    ; 获取当前窗口样式并根据样式和菜单调整外框大小
    INVOKE GetWindowLong, hWnd, GWL_STYLE
    MOV EBX, EAX
    INVOKE AdjustWindowRect, ADDR rc, EBX, TRUE

    ; 计算新的外部宽高
    MOV EAX, rc.right
    SUB EAX, rc.left
    MOV ECX, EAX              ; ECX = width
    MOV EAX, rc.bottom
    SUB EAX, rc.top           ; EAX = height

    ; 调整窗口位置和大小（左上角固定在 400,50）
    PUSH TRUE                 ; bRepaint
    PUSH EAX                  ; nHeight
    PUSH ECX                  ; nWidth
    PUSH 50                   ; Y
    PUSH 400                  ; X
    PUSH hWnd
    CALL MoveWindow

    POP EDX
    POP ECX
    POP EBX
    POP EAX
    RET
resize_main_window ENDP

; 扫描整个棋盘，检查是否还有未打开的非雷格子
; 若所有非雷格子都已打开，则将 game_state 置为 3（胜利）
check_win PROC
    PUSH EAX
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI

    ; 若已失败或已胜利，则不再判断
    MOV AL, game_state
    CMP AL, 2
    JE cw_ret
    CMP AL, 3
    JE cw_ret

    MOV ESI, OFFSET board_grid
    XOR EDX, EDX          ; cell index = 0..99

cw_next_cell:
    MOV EAX, total_cells
    CMP EDX, EAX
    JGE cw_all_open

    MOV AL, [ESI + EDX*4]      ; bMine
    CMP AL, 1
    JE cw_skip_cell            ; 有雷，忽略

    MOV AL, [ESI + EDX*4 + 1]  ; bOpen
    CMP AL, 0
    JE cw_ret                  ; 发现未打开的非雷格子，尚未胜利

cw_skip_cell:
    INC EDX
    JMP cw_next_cell

cw_all_open:
    MOV BYTE PTR game_state, 3

cw_ret:
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    POP EAX
    RET
check_win ENDP

; 下面保留原来的控制台版本主循环，供需要时手动调用调试
console_main PROC

    INVOKE init_game

game_loop:

    ;1.提示用户输入格子坐标
    INVOKE printf, OFFSET MsgInputPrompt
    ;2.接受输入: 操作类型, 行, 列
    INVOKE scanf, OFFSET InputFormat, OFFSET input_op, OFFSET input_x, OFFSET input_y

    ;3 根据输入的操作执行相应函数
    CMP input_op, 2
    JE do_flag

    ; 点击格子
    INVOKE click_cell, input_x, input_y
    JMP chech_state

do_flag:
    ; 插旗/取消旗
    INVOKE toggle_flag, input_x, input_y

chech_state:
    ;4. 再次显示盘面（查看翻开效果）
    INVOKE get_game_state

    ;5.检查游戏状态
    CMP game_state, 2
    JE state_fail
    CMP game_state, 3
    JE state_win

    JMP game_loop
state_fail:
    INVOKE printf, OFFSET MsgGameOver_fail
    JMP game_over
state_win:
    INVOKE printf, OFFSET MsgGameOver_win
    JMP game_over

game_over:
    RET
console_main ENDP
 
; 初始化界面所需的字体和画刷
init_ui PROC
    PUSH EAX

    ; 使用系统默认 GUI 字体绘制文字
    INVOKE GetStockObject, DEFAULT_GUI_FONT
    MOV hFontCell, EAX

    ; 创建几种背景画刷
    ; 颜色为 BGR 格式
    INVOKE CreateSolidBrush, 0C0C0C0h   ; 深灰色，未翻开
    MOV hBrushClosed, EAX

    ; 整体背景改为浅灰色，看起来更柔和
    INVOKE CreateSolidBrush, 0E0E0E0h   ; 浅灰色，窗口背景
    MOV hBrushOpen, EAX

    INVOKE CreateSolidBrush, 000000FFh  ; 红色，地雷
    MOV hBrushMine, EAX

    INVOKE CreateSolidBrush, 0000FF00h  ; 绿色，旗子
    MOV hBrushFlag, EAX

    ; 橙色，用于显示除被点击雷以外的其他雷
    INVOKE CreateSolidBrush, 0045A5FFh  ; 橙色（BGR）
    MOV hBrushMineOther, EAX

    POP EAX
    RET
init_ui ENDP


; 使用 GDI 绘制 10x10 棋盘
; 参数: hWnd, hDc
DrawGameBoard PROC hWnd:DWORD, hDc:DWORD
    LOCAL @row:DWORD, @col:DWORD
    LOCAL @x:DWORD, @y:DWORD, @x2:DWORD, @y2:DWORD
    LOCAL szOne[2]:BYTE
    LOCAL szMineText[32]:BYTE
    LOCAL szTimeText[32]:BYTE
    LOCAL @mineTextX:DWORD, @mineTextY:DWORD, @mineTextLen:DWORD
    LOCAL @timeTextX:DWORD, @timeTextY:DWORD, @timeTextLen:DWORD
    LOCAL @timeSec:DWORD
    LOCAL bMine:BYTE, bOpen:BYTE, bFlag:BYTE, bAround:BYTE
    LOCAL tileIndex:DWORD, srcY:DWORD

    PUSH ESI
    PUSH EDI

    ; 填充窗口背景
    INVOKE SelectObject, hDc, hBrushOpen
    INVOKE Rectangle, hDc, 0, 0, gWinWidth, gWinHeight

    ; 设置文字绘制属性
    INVOKE SetBkMode, hDc, TRANSPARENT
    INVOKE SelectObject, hDc, hFontCell

    ; 左上角绘制重置按钮
    INVOKE SelectObject, hDc, hBrushClosed
    INVOKE Rectangle, hDc, RESET_BTN_X, RESET_BTN_Y, RESET_BTN_X+RESET_BTN_W, RESET_BTN_Y+RESET_BTN_H
    INVOKE SetTextColor, hDc, 00000000h
    INVOKE TextOut, hDc, RESET_BTN_X+10, RESET_BTN_Y+7, OFFSET szResetText, 5

    ; 右上角显示剩余雷数
    ; szMineText = "Mines left: %d"
    INVOKE wsprintf, ADDR szMineText, ADDR szMinesLeftFmt, mines_left
    MOV @mineTextLen, EAX

    ; 计算显示位置（靠右）
    MOV EAX, gWinWidth
    SUB EAX, 180
    MOV @mineTextX, EAX                 ; x 约在右上角
    MOV @mineTextY, 20                  ; y

    INVOKE TextOut, hDc, @mineTextX, @mineTextY, ADDR szMineText, @mineTextLen

    ; 右上角显示用时（秒）
    ; 如果已经开始计时，则根据当前时间计算秒数；否则为 0
    CMP timer_started, 0
    JE dg_time_zero

    INVOKE GetTickCount
    MOV ECX, EAX
    SUB ECX, start_tick
    JBE dg_time_zero       ; 防止溢出为负
    MOV EAX, ECX
    XOR EDX, EDX
    MOV ECX, 1000
    DIV ECX                ; EAX = 秒
    JMP dg_time_set

dg_time_zero:
    XOR EAX, EAX

dg_time_set:
    MOV @timeSec, EAX

    ; szTimeText = "Time: %d s"
    INVOKE wsprintf, ADDR szTimeText, ADDR szTimeFmt, @timeSec
    MOV @timeTextLen, EAX

    MOV EAX, gWinWidth
    SUB EAX, 180
    MOV @timeTextX, EAX
    MOV @timeTextY, 40

    INVOKE TextOut, hDc, @timeTextX, @timeTextY, ADDR szTimeText, @timeTextLen

    MOV ESI, OFFSET board_grid
    MOV @row, 0

row_loop_draw:
    ; if row >= board_height -> done
    MOV EAX, @row
    MOVZX ECX, board_height
    CMP EAX, ECX
    JGE draw_done

    MOV @col, 0

col_loop_draw:
    ; if col >= board_width -> next row
    MOV EAX, @col
    MOVZX ECX, board_width
    CMP EAX, ECX
    JGE next_row_draw

    ; 计算当前格子在 board_grid 中的偏移
    MOV EAX, @row
    MOV ECX, row_stride
    IMUL ECX                 ; EAX = row * row_stride
    MOV ECX, @col
    SHL ECX, 2
    ADD EAX, ECX
    LEA EDI, [ESI + EAX]

    ; 读取格子状态到局部变量，避免后续算坐标时改写寄存器
    MOV AL, [EDI]      ; bMine
    MOV bMine, AL
    MOV AL, [EDI+1]    ; bOpen
    MOV bOpen, AL
    MOV AL, [EDI+2]    ; bFlag
    MOV bFlag, AL
    MOV AL, [EDI+3]    ; bAround
    MOV bAround, AL

    ;======================================
    ; 计算当前格子应使用的贴图下标 tileIndex
    ; 参照原 Mine 工程中 STATE_* 的顺序：
    ; 0: 未点击；1: 旗；3: 失败时其他雷；4: 失败时踩雷；
    ; 5: 成功时所有雷；7..14: 数字 8..1；15: 空白(0)
    ;======================================

    XOR EAX, EAX
    MOV tileIndex, EAX        ; 默认未点击格子 0

    MOV AL, game_state
    CMP AL, 2
    JE dg_fail_state
    CMP AL, 3
    JE dg_win_state
    JMP dg_play_state

; ---- 游戏进行中 / 未开始 ----
dg_play_state:
    MOV AL, bOpen
    CMP AL, 0
    JNE dg_play_opened

    ; 未翻开
    MOV AL, bFlag
    CMP AL, 1
    JNE dg_tile_done
    MOV tileIndex, 1          ; 插旗
    JMP dg_tile_done

dg_play_opened:
    ; 已翻开的非雷格，按数字显示
    MOV AL, bMine
    CMP AL, 1
    JE dg_tile_done           ; 正常流程中不会出现已翻开的雷

    MOVZX EAX, bAround        ; 0..8
    CMP EAX, 8
    JA dg_tile_done
    ; 数字贴图从 8,7,..,1,0(空) 对应索引 7..15
    ; 映射：index = 15 - around
    MOV ECX, 15
    SUB ECX, EAX
    MOV tileIndex, ECX
    JMP dg_tile_done

; ---- 游戏失败：显示所有雷，区分踩雷 / 其他雷 ----
dg_fail_state:
    MOV AL, bMine
    CMP AL, 1
    JNE dg_fail_not_mine

    ; 计算 index = row * board_width + col，用于判断是否是踩中的雷
    MOV EAX, @row
    MOVZX ECX, board_width
    IMUL EAX, ECX
    ADD EAX, @col
    MOV EDX, last_click_index
    CMP EAX, EDX
    JE dg_fail_clicked

    MOV tileIndex, 3          ; 失败时其他雷
    JMP dg_tile_done

dg_fail_clicked:
    MOV tileIndex, 4          ; 失败时踩中的雷
    JMP dg_tile_done

dg_fail_not_mine:
    ; 非雷格子按照进行中时的显示规则
    MOV AL, bOpen
    CMP AL, 0
    JNE dg_fail_opened
    MOV AL, bFlag
    CMP AL, 1
    JNE dg_tile_done
    MOV tileIndex, 1          ; 旗
    JMP dg_tile_done

dg_fail_opened:
    MOVZX EAX, bAround
    CMP EAX, 8
    JA dg_tile_done
    MOV ECX, 15
    SUB ECX, EAX
    MOV tileIndex, ECX
    JMP dg_tile_done

; ---- 游戏胜利：所有雷用成功贴图 5 显示 ----
dg_win_state:
    MOV AL, bMine
    CMP AL, 1
    JNE dg_win_not_mine
    MOV tileIndex, 5          ; 成功时所有雷
    JMP dg_tile_done

dg_win_not_mine:
    MOV AL, bOpen
    CMP AL, 0
    JNE dg_win_opened
    MOV AL, bFlag
    CMP AL, 1
    JNE dg_tile_done
    MOV tileIndex, 1          ; 旗
    JMP dg_tile_done

dg_win_opened:
    MOVZX EAX, bAround
    CMP EAX, 8
    JA dg_tile_done
    MOV ECX, 15
    SUB ECX, EAX
    MOV tileIndex, ECX

dg_tile_done:

    ; 计算像素坐标
    MOV EAX, @col
    IMUL EAX, CELL_SIZE
    MOV ECX, board_org_x
    ADD EAX, ECX
    MOV @x, EAX

    MOV EAX, @row
    IMUL EAX, CELL_SIZE
    MOV ECX, board_org_y
    ADD EAX, ECX
    MOV @y, EAX

    MOV EAX, @x
    ADD EAX, CELL_SIZE
    MOV @x2, EAX

    MOV EAX, @y
    ADD EAX, CELL_SIZE
    MOV @y2, EAX

    ; 使用位图 MINE_COLOR.BMP 绘制当前格子
    ; 源矩形：x=0, y=tileIndex*16, 宽高=16x16
    MOV EAX, tileIndex
    MOV ECX, 16
    IMUL ECX                 ; EAX = tileIndex * 16
    MOV srcY, EAX

    INVOKE StretchBlt, hDc, @x, @y, CELL_SIZE, CELL_SIZE, hMemMineDC, 0, srcY, 16, 16, SRCCOPY

skip_text:
    INC @col
    JMP col_loop_draw

next_row_draw:
    INC @row
    JMP row_loop_draw

draw_done:
    POP EDI
    POP ESI
    RET
DrawGameBoard ENDP


; 窗口消息处理函数
ProcWinMain PROC hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL @stPs:PAINTSTRUCT
    LOCAL @hDc:DWORD
    LOCAL @row:DWORD, @col:DWORD
    LOCAL @mx:DWORD, @my:DWORD
    LOCAL @beforeState:DWORD, @afterState:DWORD

    MOV EAX, uMsg

    .IF EAX == WM_CREATE
        INVOKE printf, OFFSET MsgWMCreate
        INVOKE init_game
        INVOKE init_ui
        ; 启动一个 1 秒间隔的窗口定时器，用于刷新计时显示
        INVOKE SetTimer, hWnd, 1, 1000, NULL
        ; 根据当前棋盘大小调整窗口尺寸
        INVOKE resize_main_window, hWnd
        ; 取得临时目录
        INVOKE GetTempPath, 260, ADDR szTempDir

        ; 组合点击/爆炸音效的临时文件完整路径
        INVOKE wsprintf, ADDR szClickTmpPath, ADDR szClickTmpFmt, ADDR szTempDir
        INVOKE wsprintf, ADDR szBoomTmpPath,  ADDR szBoomTmpFmt,  ADDR szTempDir

        ; 从资源中释放 mp3 到临时文件
        INVOKE extract_resource_to_file, IDR_CLICK_MP3, ADDR szClickTmpPath
        INVOKE extract_resource_to_file, IDR_BOOM_MP3,  ADDR szBoomTmpPath

        ; 根据临时文件路径构造 MCI 打开命令
        INVOKE wsprintf, ADDR szMciOpenClickCmd, ADDR szMciOpenFmtClick, ADDR szClickTmpPath
        INVOKE wsprintf, ADDR szMciOpenBoomCmd,  ADDR szMciOpenFmtBoom,  ADDR szBoomTmpPath

        ; 打开点击音效 mp3
        INVOKE mciSendStringA, ADDR szMciOpenClickCmd, NULL, 0, NULL
        CMP EAX, 0
        JE mci_open_click_ok
        INVOKE printf, OFFSET MsgMciOpenErr, EAX
    mci_open_click_ok:

        ; 打开爆炸音效 mp3
        INVOKE mciSendStringA, ADDR szMciOpenBoomCmd, NULL, 0, NULL
        CMP EAX, 0
        JE mci_open_boom_ok
        INVOKE printf, OFFSET MsgMciOpenBoomErr, EAX
    mci_open_boom_ok:

        ; 加载格子位图 MINE_COLOR.BMP 并创建内存 DC
        INVOKE LoadBitmap, hInstance, IDB_MINE_COLOR
        MOV hBmpMine, EAX
        INVOKE CreateCompatibleDC, NULL
        MOV hMemMineDC, EAX
        ; 将位图选入内存 DC
        INVOKE SelectObject, hMemMineDC, hBmpMine

    .ELSEIF EAX == WM_CLOSE
        ; 关闭点击 / 爆炸音效
        INVOKE mciSendStringA, ADDR szMciCloseClick, NULL, 0, NULL
        INVOKE mciSendStringA, ADDR szMciCloseBoom, NULL, 0, NULL
        ; 释放格子位图与内存 DC
        INVOKE DeleteDC, hMemMineDC
        INVOKE DeleteObject, hBmpMine
        ; 删除临时 mp3 文件
        INVOKE DeleteFile, ADDR szClickTmpPath
        INVOKE DeleteFile, ADDR szBoomTmpPath
        INVOKE KillTimer, hWnd, 1
        INVOKE DestroyWindow, hWinMain
        INVOKE PostQuitMessage, NULL

    .ELSEIF EAX == WM_TIMER
        ; 只在计时已经开始且游戏进行中时刷新界面
        CMP timer_started, 0
        JE after_mouse
        MOV AL, game_state
        CMP AL, 1
        JNE after_mouse
        INVOKE InvalidateRect, hWnd, NULL, FALSE

        .ELSEIF EAX == WM_COMMAND
        ; 菜单命令：难度选择
        MOV EAX, wParam
        AND EAX, 0FFFFh        ; 低 16 位是命令 ID
        CMP EAX, IDM_DIFF_EASY
        JE on_diff_easy
        CMP EAX, IDM_DIFF_MEDIUM
        JE on_diff_medium
        CMP EAX, IDM_DIFF_EXPERT
        JE on_diff_expert

        ; 其他命令交给默认处理
        INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam
        RET

    on_diff_easy:
        ; 简单：10x10，10 雷
        MOV BYTE PTR board_width, 10
        MOV BYTE PTR board_height, 10
        MOV BYTE PTR mine_count, 10
        JMP on_diff_changed

    on_diff_medium:
        ; 中级：16x16，40 雷
        MOV BYTE PTR board_width, 16
        MOV BYTE PTR board_height, 16
        MOV BYTE PTR mine_count, 40
        JMP on_diff_changed

    on_diff_expert:
        ; 专家：16x30，99 雷
        MOV BYTE PTR board_width, 30
        MOV BYTE PTR board_height, 16
        MOV BYTE PTR mine_count, 99

    on_diff_changed:
        ; 重置计时和局面
        MOV timer_started, 0
        MOV start_tick, 0
        MOV elapsed_sec, 0
        MOV last_click_index, 0FFFFFFFFh
        INVOKE init_game
        ; 难度变化后，根据新棋盘大小调整窗口尺寸
        INVOKE resize_main_window, hWnd
        INVOKE InvalidateRect, hWnd, NULL, FALSE
        INVOKE UpdateWindow, hWnd
        XOR EAX, EAX
        RET

    .ELSEIF EAX == WM_LBUTTONDOWN || EAX == WM_RBUTTONDOWN
        ; 从 lParam 中取鼠标坐标
        MOV EAX, lParam
        MOVZX ECX, AX       ; x
        SHR EAX, 16
        MOVZX EDX, AX       ; y
        MOV @mx, ECX
        MOV @my, EDX

        ; 判断是否点击了重置按钮（仅响应左键）
        .IF uMsg == WM_LBUTTONDOWN
            MOV EAX, @mx
            CMP EAX, RESET_BTN_X
            JB not_reset
            MOV EBX, RESET_BTN_X + RESET_BTN_W
            CMP EAX, EBX
            JAE not_reset

            MOV EAX, @my
            CMP EAX, RESET_BTN_Y
            JB not_reset
            MOV EBX, RESET_BTN_Y + RESET_BTN_H
            CMP EAX, EBX
            JAE not_reset

            ; 在重置按钮区域内，重置游戏和计时
            MOV timer_started, 0
            MOV start_tick, 0
            MOV elapsed_sec, 0
            MOV last_click_index, 0FFFFFFFFh
            INVOKE init_game
            INVOKE InvalidateRect, hWnd, NULL, FALSE
            INVOKE UpdateWindow, hWnd
            JMP after_mouse

        not_reset:
        .ENDIF

        ; 判断是否在棋盘区域内
        MOV EAX, @mx
        MOV ECX, board_org_x
        CMP EAX, ECX
        JB after_mouse
        ; 右边界 = board_org_x + board_width * CELL_SIZE
        MOVZX EDX, board_width
        IMUL EDX, CELL_SIZE
        ADD EDX, ECX
        CMP EAX, EDX
        JAE after_mouse

        MOV EAX, @my
        MOV ECX, board_org_y
        CMP EAX, ECX
        JB after_mouse
        ; 下边界 = board_org_y + board_height * CELL_SIZE
        MOVZX EDX, board_height
        IMUL EDX, CELL_SIZE
        ADD EDX, ECX
        CMP EAX, EDX
        JAE after_mouse

        ; 计算行列索引 (0-9)
        MOV EAX, @mx
        MOV ECX, board_org_x   ; 使用棋盘左上角的 X 作为基准
        SUB EAX, ECX
        MOV ECX, CELL_SIZE
        XOR EDX, EDX
        DIV ECX
        MOV @col, EAX

        MOV EAX, @my
        MOV ECX, board_org_y
        SUB EAX, ECX
        MOV ECX, CELL_SIZE
        XOR EDX, EDX
        DIV ECX
        MOV @row, EAX

        ; 如有需要，启动计时器（从第一次合法点击开始计时）
        CMP timer_started, 0
        JNE after_start_time
        INVOKE GetTickCount
        MOV start_tick, EAX
        MOV timer_started, 1

    after_start_time:
        ; 记录点击前该格子的状态
        INVOKE get_cell_state, @row, @col
        MOV @beforeState, EAX

    click_time_done:

        ; 每次新的鼠标点击开始时，先假定本次不是踩雷
        MOV last_click_is_mine, 0

        ; 根据按键类型调用逻辑函数（先更新逻辑，再根据结果决定是否播放音效）
        .IF uMsg == WM_LBUTTONDOWN
            INVOKE click_cell, @row, @col
            INVOKE printf, OFFSET MsgClickInfo, @row, @col, 1
        .ELSE
            INVOKE toggle_flag, @row, @col
            INVOKE printf, OFFSET MsgClickInfo, @row, @col, 2
        .ENDIF

        ; 获取点击后的格子状态
        INVOKE get_cell_state, @row, @col
        MOV @afterState, EAX

        ; 仅当格子状态发生变化时才播放点击音效
        MOV EAX, @beforeState
        CMP EAX, @afterState
        JE no_click_sound

        INVOKE mciSendStringA, ADDR szMciPlayClick, NULL, 0, NULL
        CMP EAX, 0
        JE mci_play_ok
        INVOKE printf, OFFSET MsgMciPlayErr, EAX
mci_play_ok:

no_click_sound:

        ; 如果本次点击踩雷，则播放爆炸音效
        CMP last_click_is_mine, 0
        JE after_boom_sound
        INVOKE mciSendStringA, ADDR szMciPlayBoom, NULL, 0, NULL
        CMP EAX, 0
        JE after_boom_sound
        INVOKE printf, OFFSET MsgMciPlayBoomErr, EAX
    after_boom_sound:

        ; 控制台输出当前棋盘
        INVOKE get_game_state
        INVOKE printf, OFFSET MsgNewLine

        ; 检查是否胜利
        INVOKE check_win

        ; 先重绘一帧，使最后一次点击的效果可见
        INVOKE InvalidateRect, hWnd, NULL, FALSE
        INVOKE UpdateWindow, hWnd

        ; 然后检查游戏状态
        MOV AL, game_state
        CMP AL, 2
        JE ui_fail
        CMP AL, 3
        JE ui_win

        JMP after_mouse

ui_fail:
        INVOKE MessageBox, hWnd, OFFSET MsgGameOver_fail, OFFSET szCaptionMain, MB_OK
    MOV timer_started, 0
        INVOKE init_game
        INVOKE InvalidateRect, hWnd, NULL, FALSE
        JMP after_mouse

ui_win:
    ; 计算最终用时（秒）并在弹窗中显示
    CMP timer_started, 0
    JE ui_win_no_time

    INVOKE GetTickCount
    MOV ECX, EAX
    SUB ECX, start_tick
    JBE ui_win_no_time
    MOV EAX, ECX
    XOR EDX, EDX
    MOV ECX, 1000
    DIV ECX            ; EAX = 秒
    MOV elapsed_sec, EAX

    ; 组合带时间的胜利提示到全局缓冲区
    INVOKE wsprintf, ADDR szWinTimeText, ADDR szTimeFmt, elapsed_sec
    ; 先弹出原有胜利提示，再弹出时间提示
    INVOKE MessageBox, hWnd, OFFSET MsgGameOver_win, OFFSET szCaptionMain, MB_OK
    INVOKE MessageBox, hWnd, ADDR szWinTimeText, OFFSET szCaptionMain, MB_OK
    JMP ui_win_after_box

ui_win_no_time:
    INVOKE MessageBox, hWnd, OFFSET MsgGameOver_win, OFFSET szCaptionMain, MB_OK

ui_win_after_box:
    MOV timer_started, 0
        INVOKE init_game
        INVOKE InvalidateRect, hWnd, NULL, FALSE

after_mouse:

    .ELSEIF EAX == WM_PAINT
        INVOKE BeginPaint, hWnd, ADDR @stPs
        MOV @hDc, EAX
        INVOKE DrawGameBoard, hWnd, @hDc
        INVOKE EndPaint, hWnd, ADDR @stPs

    .ELSE
        INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam
        RET
    .ENDIF

    XOR EAX, EAX
    RET
ProcWinMain ENDP


; 注册窗口类并运行消息循环
WinMain PROC
    LOCAL @stWndClass:WNDCLASSEX
    LOCAL @stMsg:MSG

    INVOKE printf, OFFSET MsgWinMainStart

    INVOKE GetModuleHandle, NULL
    MOV hInstance, EAX

    INVOKE RtlZeroMemory, ADDR @stWndClass, SIZEOF @stWndClass

    INVOKE LoadCursor, 0, IDC_ARROW
    MOV @stWndClass.hCursor, EAX
    MOV EAX, hInstance
    MOV @stWndClass.hInstance, EAX
    MOV @stWndClass.cbSize, SIZEOF WNDCLASSEX
    MOV @stWndClass.style, CS_HREDRAW OR CS_VREDRAW
    MOV @stWndClass.lpfnWndProc, OFFSET ProcWinMain
    MOV @stWndClass.hbrBackground, COLOR_WINDOW+1
    MOV @stWndClass.lpszClassName, OFFSET szClassName

    INVOKE RegisterClassEx, ADDR @stWndClass
    INVOKE printf, OFFSET MsgAfterRegClass

        INVOKE CreateWindowEx, WS_EX_CLIENTEDGE,
            OFFSET szClassName, OFFSET szCaptionMain,
            WS_OVERLAPPEDWINDOW, 400, 50, WINDOW_WIDTH, WINDOW_HEIGHT,
            NULL, NULL, hInstance, NULL
    MOV hWinMain, EAX
    INVOKE printf, OFFSET MsgAfterCreateWin

    ; 创建顶层菜单，添加难度选项
    INVOKE CreateMenu
    MOV EBX, EAX                 ; hMenu
    INVOKE AppendMenu, EBX, MF_STRING, IDM_DIFF_EASY,   OFFSET szMenuEasy
    INVOKE AppendMenu, EBX, MF_STRING, IDM_DIFF_MEDIUM, OFFSET szMenuMedium
    INVOKE AppendMenu, EBX, MF_STRING, IDM_DIFF_EXPERT, OFFSET szMenuExpert
    INVOKE SetMenu, hWinMain, EBX

    INVOKE ShowWindow, hWinMain, SW_SHOWNORMAL
    INVOKE UpdateWindow, hWinMain

    .WHILE TRUE
        INVOKE GetMessage, ADDR @stMsg, NULL, 0, 0
        .BREAK .IF EAX == 0
        INVOKE TranslateMessage, ADDR @stMsg
        INVOKE DispatchMessage, ADDR @stMsg
    .ENDW

    RET
WinMain ENDP


main PROC
    ; 入口：启动窗口程序；控制台同时存在，用于 printf 调试
    INVOKE printf, OFFSET MsgMainStart
    INVOKE WinMain
    INVOKE ExitProcess, NULL
    RET
main ENDP

END main

