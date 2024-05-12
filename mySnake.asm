    DEVICE ZXSPECTRUM48

    ORG #8000

rom_cls EQU #0DAF

sysvar_frames_count EQU +62
sysvar_attr         EQU +83

frames_in_step EQU 10

color_buffer EQU #5800 ; Screen attributes
dir_buffer   EQU color_buffer | 32768

empty_color EQU 0
snake_color EQU 6<<3
apple_color EQU 2<<3 | 64

    ASSERT snake_color < apple_color

start_x EQU 16
start_y EQU 12

left  EQU -1  ; %11111111
right EQU +1  ; %00000001
up    EQU -32 ; %11100000
down  EQU +32 ; %00100000

    MACRO LD_BC_A
        LD C, A
        ADD A, A
        SBC A, A
        LD B, A
    ENDM

    MACRO COLOR_ADDR_TO_DIR_ADDR ; Switching HL to dir_buffer
        SET 7, H ; HL |= 32768
    ENDM

    MACRO DIR_ADDR_TO_COLOR_ADDR ; Switching HL to color_buffer
        RES 7, H ; HL &= ~32768
    ENDM

start
    EI

    ; Clear screen
    XOR A ; A = empty_color = 0
    LD (IY + sysvar_attr), A
    CALL rom_cls
    ; DE = 0

    ; TODO
    ; Setting up random generator pointer
    EX DE, HL
    EXX
    ; HL' = 0

    ; Blue border
    INC A ; A = +1
    OUT (#FE), A

    ; Setting up some constants
    LD DE, 3 << 8 | snake_color

setup_snake
    LD HL, color_buffer + start_x + 32*start_y
    LD (HL), E ; E = snake_color

    COLOR_ADDR_TO_DIR_ADDR

    LD (HL), A ; A = +1 (right)
    PUSH HL
    ; HL = head, (SP) = tail, (HL) = direction

spawn_apple
    EXX

    ; Generating random address in color buffer
1
    RES 6, H

    LD C, (HL)
    INC L

    LD A, (HL)
    INC HL
    AND 3
    JR Z, 1B
    ADD A, HIGH color_buffer - 1
    LD B, A

    ; Test cell is empty
    LD A, (BC)
    OR A ; empty_color = 0
    JR NZ, 1B

    ; Drop apple
    LD A, apple_color
    LD (BC), A

    EXX

game_loop

handle_input
    ; Reading interface II keys [67890]
    LD BC, frames_in_step << 8 | #FF
1
    HALT
    LD A, #EF
    IN A, (#FE) ; A = %XXX67890
    AND C
    LD C, A
    DJNZ 1B

    ; Choosing different axis (C = now moving vertically ? left : down)
    ; and shifting key mask (%XXX67890 -> %90XXX678) if now moving vertically
    BIT 0, (HL)
    LD C, down
    JR NZ, 1F
    LD C, left
    RRCA
    RRCA
1
    ; Testing bits 1 and 2
    AND 6
    JP PE, move_head ; Neither or both keys are pressed

    ; Inverting if righter key (7 or 9) is pressed (left->right or down->up)
    SUB A, 4
    JR NZ, 1F
    SUB A, C ; A = 0
    LD C, A
1
    ; Updating direction
    LD (HL), C

move_head
    ; Move head to the next cell
    LD A, (HL)
    LD_BC_A
    ADD HL, BC

    LD (HL), C ; Store current direction in the head

    ; Checking vertical borders
    LD A, H
    AND D ; D = 3
    CP D
    JR Z, start ; Address is out of buffer

    ; Checking horizontal borders
    LD A, C ; C = direction
    RRCA
    JR NC, grab_cell ; Moved vertically
    XOR L
    AND 31
    JR Z, start ; Moved left and now at right border or vice versa

grab_cell
    DIR_ADDR_TO_COLOR_ADDR

    ; Testing cell at head positing
    LD A, E ; E = snake_color
    CP (HL)
    JR Z, start ; Bitten self

    ; Painting head
    LD (HL), E ; E = snake_color

    COLOR_ADDR_TO_DIR_ADDR

    JR C, spawn_apple ; Ate apple

move_tail
    EX (SP), HL ; Exchange head <-> tail

    ; Clear tail cell
    DIR_ADDR_TO_COLOR_ADDR
    LD (HL), empty_color
    COLOR_ADDR_TO_DIR_ADDR

    ; Move tail to the next cell
    LD A, (HL)
    LD_BC_A
    ADD HL, BC

    EX (SP), HL ; Exchange head <-> tail

    JR game_loop

    DISPLAY "Code size: ", /D, $ - start
    SAVETAP "mySnake.tap", CODE, "mySnake", start, $ - start, start
