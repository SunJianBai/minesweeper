; Minesweeper UI - Group Member A
; Win32 GUI in MASM32 style

.386
.model flat, stdcall
option casemap:none

include windows.inc
include user32.inc
include gdi32.inc
include kernel32.inc

includelib user32.lib
includelib gdi32.lib
includelib kernel32.lib

WM_LBUTTONDOWN equ 0201h
WM_RBUTTONDOWN equ 0204h

CELL_SIZE      equ 20
BOARD_COLS     equ 9
BOARD_ROWS     equ 9

CELL_COVERED   equ 0
CELL_OPEN      equ 1
CELL_FLAG      equ 2

.data
szClassName db "MinesweeperClass",0
szTitle     db "Minesweeper UI (Group A)",0

; 0 = covered, 1 = open, 2 = flag
board  db BOARD_ROWS*BOARD_COLS dup(CELL_COVERED)

.data?
hInstance   HINSTANCE ?
hMainWnd    HWND ?

.code

; Prototypes to satisfy INVOKE before definitions
WinMain     PROTO :HINSTANCE, :HINSTANCE, :LPSTR, :DWORD
HandleClick PROTO :HWND, :LPARAM, :DWORD
DrawBoard   PROTO :HDC

start PROC
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax
start ENDP

; int APIENTRY WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow)
WinMain PROC hInst:HINSTANCE, hPrev:HINSTANCE, lpCmdLine:LPSTR, nCmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL rc:RECT

    mov eax, SIZEOF WNDCLASSEX
    mov wc.cbSize, eax
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInst
    mov wc.hInstance, eax
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    mov wc.hbrBackground, COLOR_WINDOW+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET szClassName

    invoke RegisterClassEx, ADDR wc

    mov rc.left, 0
    mov rc.top, 0
    mov eax, BOARD_COLS
    imul eax, CELL_SIZE
    mov rc.right, eax
    mov eax, BOARD_ROWS
    imul eax, CELL_SIZE
    mov rc.bottom, eax

    invoke AdjustWindowRectEx, ADDR rc, WS_OVERLAPPEDWINDOW and (not WS_MAXIMIZEBOX) and (not WS_THICKFRAME), FALSE, 0

    mov eax, rc.right
    sub eax, rc.left
    mov ebx, rc.bottom
    sub ebx, rc.top

    invoke CreateWindowEx, 0, ADDR szClassName, ADDR szTitle,
           WS_OVERLAPPEDWINDOW and (not WS_MAXIMIZEBOX) and (not WS_THICKFRAME),
           CW_USEDEFAULT, CW_USEDEFAULT, eax, ebx,
           NULL, NULL, hInst, NULL
    mov hMainWnd, eax

    invoke ShowWindow, hMainWnd, nCmdShow
    invoke UpdateWindow, hMainWnd

@@msg_loop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    cmp eax, 0
    jle @@exit
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp @@msg_loop
@@exit:
    mov eax, msg.wParam
    ret
WinMain ENDP

; LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
WndProc PROC hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL ps:PAINTSTRUCT
    LOCAL hdc:HDC

    .if uMsg == WM_DESTROY
        invoke PostQuitMessage, 0
        xor eax, eax
        ret

    .elseif uMsg == WM_LBUTTONDOWN
        invoke HandleClick, hWnd, lParam, 0
        xor eax, eax
        ret

    .elseif uMsg == WM_RBUTTONDOWN
        invoke HandleClick, hWnd, lParam, 1
        xor eax, eax
        ret

    .elseif uMsg == WM_PAINT
        invoke BeginPaint, hWnd, ADDR ps
        mov hdc, eax
        invoke DrawBoard, hdc
        invoke EndPaint, hWnd, ADDR ps
        xor eax, eax
        ret

    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif

WndProc ENDP

; void HandleClick(HWND hWnd, LPARAM lParam, int isRight)
HandleClick PROC hWnd:HWND, lParam:LPARAM, isRight:DWORD
    LOCAL x:DWORD
    LOCAL y:DWORD
    LOCAL col:DWORD
    LOCAL row:DWORD
    LOCAL idx:DWORD

    mov eax, lParam
    and eax, 0FFFFh
    mov x, eax

    mov eax, lParam
    shr eax, 16
    and eax, 0FFFFh
    mov y, eax

    mov eax, x
    mov ecx, CELL_SIZE
    cdq
    idiv ecx
    mov col, eax

    mov eax, y
    mov ecx, CELL_SIZE
    cdq
    idiv ecx
    mov row, eax

    mov eax, col
    cmp eax, BOARD_COLS
    jae @@out
    mov eax, row
    cmp eax, BOARD_ROWS
    jae @@out

    mov eax, row
    imul eax, BOARD_COLS
    add eax, col
    mov idx, eax

    mov eax, isRight
    cmp eax, 0
    jne @@right_click

    mov ebx, OFFSET board
    add ebx, idx
    mov al, [ebx]
    cmp al, CELL_COVERED
    jne @@after
    mov al, CELL_OPEN
    mov [ebx], al
    jmp @@after

@@right_click:
    mov ebx, OFFSET board
    add ebx, idx
    mov al, [ebx]
    cmp al, CELL_FLAG
    je @@set_covered
    mov al, CELL_FLAG
    mov [ebx], al
    jmp @@after
@@set_covered:
    mov al, CELL_COVERED
    mov [ebx], al

@@after:
    invoke InvalidateRect, hWnd, NULL, TRUE
@@out:
    ret
HandleClick ENDP

; void DrawBoard(HDC hdc)
DrawBoard PROC hdc:HDC
    LOCAL x:DWORD
    LOCAL y:DWORD
    LOCAL col:DWORD
    LOCAL row:DWORD
    LOCAL idx:DWORD
    LOCAL rect:RECT
    LOCAL hPenGrid:HPEN
    LOCAL hOldPen:HPEN
    LOCAL hBrush:HWND
    LOCAL hOldBrush:HWND

    invoke CreatePen, PS_SOLID, 1, 00000000h
    mov hPenGrid, eax
    invoke SelectObject, hdc, hPenGrid
    mov hOldPen, eax

    mov row, 0
@@row_loop:
    mov eax, row
    cmp eax, BOARD_ROWS
    jae @@done_rows

    mov col, 0
@@col_loop:
    mov eax, col
    cmp eax, BOARD_COLS
    jae @@next_row

    mov eax, col
    imul eax, CELL_SIZE
    mov rect.left, eax
    mov eax, col
    inc eax
    imul eax, CELL_SIZE
    mov rect.right, eax

    mov eax, row
    imul eax, CELL_SIZE
    mov rect.top, eax
    mov eax, row
    inc eax
    imul eax, CELL_SIZE
    mov rect.bottom, eax

    mov eax, row
    imul eax, BOARD_COLS
    add eax, col
    mov idx, eax

    mov ebx, OFFSET board
    add ebx, idx
    mov al, [ebx]

    cmp al, CELL_OPEN
    je @@brush_open
    cmp al, CELL_FLAG
    je @@brush_flag

    invoke CreateSolidBrush, 00C0C0C0h ; covered
    jmp @@have_brush
@@brush_open:
    invoke CreateSolidBrush, 00FFFFFFh ; open
    jmp @@have_brush
@@brush_flag:
    invoke CreateSolidBrush, 000000FFh ; flag (red-ish in BGR)
@@have_brush:
    mov hBrush, eax
    invoke SelectObject, hdc, hBrush
    mov hOldBrush, eax

    invoke Rectangle, hdc, rect.left, rect.top, rect.right, rect.bottom

    invoke SelectObject, hdc, hOldBrush
    invoke DeleteObject, hBrush

    inc col
    jmp @@col_loop

@@next_row:
    inc row
    jmp @@row_loop

@@done_rows:
    invoke SelectObject, hdc, hOldPen
    invoke DeleteObject, hPenGrid
    ret
DrawBoard ENDP

END start
