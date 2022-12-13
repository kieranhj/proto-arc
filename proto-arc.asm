; ============================================================================
; Prototype Framework - stripped back from stniccc-archie.
; ============================================================================

.equ _DEBUG, 1
.equ _DEBUG_RASTERS, (_DEBUG && 1)
.equ _ENABLE_MUSIC, 1
.equ _ENABLE_ROCKET, 1
.equ _FIX_FRAME_RATE, 0					; useful for !DDT breakpoints
.equ _SYNC_EDITOR, 1

.equ _RUBBER_CUBE, 0

.equ Screen_Banks, 3
.equ Screen_Mode, 9
.equ Screen_Width, 320
.equ Screen_Height, 256
.equ Mode_Height, 256
.equ Screen_PixelsPerByte, 2
.equ Screen_Stride, Screen_Width/Screen_PixelsPerByte
.equ Screen_Bytes, Screen_Stride*Screen_Height
.equ Mode_Bytes, Screen_Stride*Mode_Height

.include "lib/swis.h.asm"
.include "lib/config.h.asm"

.macro SET_BORDER rgb
	.if _DEBUG_RASTERS
	mov r4, #\rgb
	bl palette_set_border
	.endif
.endm

.org 0x8000

; ============================================================================
; Stack
; ============================================================================

Start:
    adrl sp, stack_base
	B main

.skip 1024
stack_base:

; ============================================================================
; Main
; ============================================================================

main:
	SWI OS_WriteI + 22		; Set base MODE
	SWI OS_WriteI + Screen_Mode

	SWI OS_WriteI + 23		; Disable cursor
	SWI OS_WriteI + 1
	MOV r0,#0
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC

	; Set screen size for number of buffers
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	MOV r0, #DynArea_Screen
	MOV r2, #Mode_Bytes * Screen_Banks
	SUBS r1, r2, r1
	SWI OS_ChangeDynamicArea
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	CMP r1, #Mode_Bytes * Screen_Banks
	ADRCC r0, error_noscreenmem
	SWICC OS_GenerateError

	; LOAD STUFF HERE!

.if _ENABLE_MUSIC
	; Load module
	adrl r0, module_filename
	mov r1, #0
	swi QTM_Load
.endif

	; Clear all screen buffers
	mov r1, #1
.1:
	str r1, scr_bank

	; CLS bank N
	mov r0, #OSByte_WriteVDUBank
	swi OS_Byte
	mov r0, #12
	SWI OS_WriteC

	ldr r1, scr_bank
	add r1, r1, #1
	cmp r1, #Screen_Banks
	ble .1

	; EARLY INITIALISATION HERE! (Tables etc.)
	bl maths_init
	; bl initialise_span_buffer

	.if _ENABLE_ROCKET
	bl rocket_init
	.endif

	; Start with bank 1
	mov r1, #1
	str r1, scr_bank
	
	; Claim the Error vector
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Claim

	; Claim the Event vector
	mov r0, #EventV
	adr r1, event_handler
	mov r2, #0
	swi OS_AddToVector

	; LATE INITALISATION HERE!
	bl init_3d_scene
	.if _RUBBER_CUBE
	bl init_rubber_cube
	.else
	adr r2, grey_palette
	bl palette_set_block
	.endif

	; Sync tracker.
	.if _ENABLE_ROCKET
	bl rocket_start		; handles music.
	.else
	.IF _ENABLE_MUSIC
	swi QTM_Start
	.endif
	.endif

	; Enable Vsync event
	mov r0, #OSByte_EventEnable
	mov r1, #Event_VSync
	SWI OS_Byte

main_loop:

	SET_BORDER 0x0000ff	; red
	.if _RUBBER_CUBE
	bl update_rubber_cube
	.else
	bl update_3d_scene
	.endif

	SET_BORDER 0x000000	; black
	; Really we need something more sophisticated here.
	; Block only if there's no free buffer to write to.

.if Screen_Banks == 2
	; Block if there's a buffer pending to be displayed when double buffered.
	; This means that we overran the previous frame. Triple buffering may
	; help here. Or not. ;)
.2:
	ldr r1, buffer_pending
	cmp r1, #0
	bne .2	
.endif

	; Block if we've not even had a vsync since last time - we're >50Hz!
	ldr r1, last_vsync
.1:
	ldr r2, vsync_count
	cmp r1, r2
	beq .1
	.if _FIX_FRAME_RATE
	mov r0, #1
	.else
	sub r0, r2, r1
	.endif
	str r2, last_vsync
	str r0, vsync_delta

	; R0 = vsync delta since last frame.
	.if _ENABLE_ROCKET
	bl rocket_update
	.endif

	; show debug
	.if _DEBUG
	bl debug_write_vsync_count
	.endif

	; DO STUFF HERE!
	bl get_next_screen_for_writing
	ldr r11, screen_addr

	SET_BORDER 0x00ff00	; green
	bl screen_cls

	SET_BORDER 0xff0000	; blue
	ldr r11, screen_addr
	.if _RUBBER_CUBE
	bl draw_rubber_cube
	.else
	bl draw_3d_scene
	.endif

	SET_BORDER 0x000000	; black
	bl show_screen_at_vsync

	; exit if Escape is pressed
	MOV r0, #OSByte_ReadKey
	MOV r1, #IKey_Escape
	MOV r2, #0xff
	SWI OS_Byte
	
	CMP r1, #0xff
	CMPEQ r2, #0xff
	BEQ exit
	
	b main_loop

error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.align 4
	.long 0

.if _DEBUG
debug_write_vsync_count:
	str lr, [sp, #-4]!
	swi OS_WriteI+30			; home text cursor

.if _ENABLE_ROCKET
	bl rocket_get_sync_time
.else
	ldr r0, vsync_delta			; or vsync_count
.endif
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex4

	adr r0, debug_string
	swi OS_WriteO
	
.if _ENABLE_MUSIC
	swi OS_WriteI+32			; ' '

    ; read current tracker position
    mov r0, #-1
    mov r1, #-1
    swi QTM_Pos

	mov r3, r1

	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex2
	adr r0, debug_string
	swi OS_WriteO

	swi OS_WriteI+58			; ':'

	mov r0, r3
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex2
	adr r0, debug_string
	swi OS_WriteO
.endif
	ldr pc, [sp], #4

debug_string:
	.skip 16
.endif

get_screen_addr:
	str lr, [sp, #-4]!
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi OS_ReadVduVariables
	ldr pc, [sp], #4
	
screen_addr_input:
	.long VD_ScreenStart, -1

exit:	
	; wait for vsync (any pending buffers)
	mov r0, #19
	swi OS_Byte

.if _ENABLE_MUSIC
	; disable music
	mov r0, #0
	swi QTM_Stop
.endif

	; disable vsync event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_VSync
	swi OS_Byte

	; release our event handler
	mov r0, #EventV
	adr r1, event_handler
	mov r2, #0
	swi OS_Release

	; release our error handler
	mov r0, #ErrorV
	adr r1, error_handler
	mov r2, #0
	swi OS_Release

	; Display whichever bank we've just written to
	mov r0, #OSByte_WriteDisplayBank
	ldr r1, scr_bank
	swi OS_Byte
	; and write to it
	mov r0, #OSByte_WriteVDUBank
	ldr r1, scr_bank
	swi OS_Byte

	SWI OS_Exit

; R0=event number
event_handler:
	cmp r0, #Event_VSync
	movnes pc, r14

	STMDB sp!, {r0-r1, lr}

	; update the vsync counter
	LDR r0, vsync_count
	ADD r0, r0, #1
	STR r0, vsync_count

	; is there a new screen buffer ready to display?
	LDR r1, buffer_pending
	CMP r1, #0
	LDMEQIA sp!, {r0-r1, pc}

	; set the display buffer
	MOV r0, #0
	STR r0, buffer_pending
	MOV r0, #OSByte_WriteDisplayBank

	; some SVC stuff I don't understand :)
	STMDB sp!, {r2-r12}
	MOV r9, pc     ;Save old mode
	ORR r8, r9, #3 ;SVC mode
	TEQP r8, #0
	MOV r0,r0
	STR lr, [sp, #-4]!
	SWI XOS_Byte

	; set full palette if there is a pending palette block
	ldr r2, palette_pending
	cmp r2, #0
	beq .4

    adr r1, palette_osword_block
    mov r0, #16
    strb r0, [r1, #1]       ; physical colour

    mov r3, #0
    .3:
    strb r3, [r1, #0]       ; logical colour

    ldr r4, [r2], #4        ; rgbx
    and r0, r4, #0xff
    strb r0, [r1, #2]       ; red
    mov r0, r4, lsr #8
    strb r0, [r1, #3]       ; green
    mov r0, r4, lsr #16
    strb r0, [r1, #4]       ; blue
    mov r0, #12
    swi XOS_Word

    add r3, r3, #1
    cmp r3, #16
    blt .3

	mov r0, #0
	str r0, palette_pending
.4:

	LDR lr, [sp], #4
	TEQP r9, #0    ;Restore old mode
	MOV r0, r0
	LDMIA sp!, {r2-r12}
	LDMIA sp!, {r0-r1, pc}

error_handler:
	STMDB sp!, {r0-r2, lr}
	MOV r0, #OSByte_EventDisable
	MOV r1, #Event_VSync
	SWI OS_Byte
	MOV r0, #EventV
	ADR r1, event_handler
	mov r2, #0
	SWI OS_Release
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Release
	MOV r0, #OSByte_WriteDisplayBank
	LDR r1, scr_bank
	SWI OS_Byte
	LDMIA sp!, {r0-r2, lr}
	MOVS pc, lr

show_screen_at_vsync:
	; Show current bank at next vsync
	ldr r1, scr_bank
	str r1, buffer_pending
	; Including its associated palette
	ldr r1, palette_block_addr
	str r1, palette_pending
	mov pc, lr

get_next_screen_for_writing:
	; Increment to next bank for writing
	ldr r1, scr_bank
	add r1, r1, #1
	cmp r1, #Screen_Banks
	movgt r1, #1
	str r1, scr_bank

	; Now set the screen bank to write to
	mov r0, #OSByte_WriteVDUBank
	swi OS_Byte

	; Back buffer address for writing bank stored at screen_addr
	b get_screen_addr

; ============================================================================
; Global vars.
; ============================================================================

; TODO: rename these to be clearer.
scr_bank:
	.long 0				; current VIDC screen bank being written to.

palette_block_addr:
	.long 0				; (optional) ptr to a block of palette data for the screen bank being written to.

vsync_count:
	.long 0				; current vsync count from start of exe.

last_vsync:
	.long 0				; vsync count at start of previous frame.

vsync_delta:
	.long 0

buffer_pending:
	.long 0				; screen bank number to display at vsync.

palette_pending:
	.long 0				; (optional) ptr to a block of palette data to set at vsync.

screen_addr:
	.long 0				; ptr to the current VIDC screen bank being written to.


; ============================================================================
; Additional code modules
; ============================================================================

.include "lib/maths.asm"
.include "lib/3d-scene.asm"
.include "lib/rubber-cube.asm"
.include "lib/mode9-screen.asm"
;.include "lib/mode9-plot.asm"
.include "lib/mode9-palette.asm"

.if _ENABLE_ROCKET
.include "lib/rocket.asm"
.endif

; ============================================================================
; Data Segment
; ============================================================================

.if _ENABLE_MUSIC
module_filename:
	.byte "<Demo$Dir>.Music",0
	.align 4
.endif

grey_palette:
	.long 0x00000000
	.long 0x00111111
	.long 0x00222222
	.long 0x00333333
	.long 0x00444444
	.long 0x00555555
	.long 0x00666666
	.long 0x00777777
	.long 0x00888888
	.long 0x00999999
	.long 0x00AAAAAA
	.long 0x00BBBBBB
	.long 0x00CCCCCC
	.long 0x00DDDDDD
	.long 0x00EEEEEE
	.long 0x00FFFFFF

palette_osword_block:
    .skip 8
    ; logical colour
    ; physical colour (16)
    ; red
    ; green
    ; blue
    ; (pad)

.include "lib/tables.asm"

; ============================================================================
; BSS Segment
; ============================================================================
