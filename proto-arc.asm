; ============================================================================
; Prototype Framework - stripped back from stniccc-archie.
; ============================================================================

.equ _DEBUG, 1
.equ _ENABLE_MUSIC, 0
.equ _FIX_FRAME_RATE, 0					; useful for !DDT breakpoints
.equ _SYNC_EDITOR, 1

.equ Screen_Banks, 3
.equ Screen_Mode, 9
.equ Screen_Width, 320
.equ Screen_Height, 240
.equ Mode_Height, 256
.equ Screen_PixelsPerByte, 2
.equ Screen_Stride, Screen_Width/Screen_PixelsPerByte
.equ Screen_Bytes, Screen_Stride*Screen_Height
.equ Mode_Bytes, Screen_Stride*Mode_Height

.include "lib/swis.h.asm"

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
	MOV r0,#22	;Set MODE
	SWI OS_WriteC
	MOV r0,#Screen_Mode
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

	MOV r0,#23	;Disable cursor
	SWI OS_WriteC
	MOV r0,#1
	SWI OS_WriteC
	MOV r0,#0
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC
	SWI OS_WriteC

	; LOAD STUFF HERE!

.if _ENABLE_MUSIC
	; Load module
	adrl r0, module_filename
	mov r1, #0
	swi QTM_Load

	mov r0, #48
	swi QTM_SetSampleSpeed
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
	adr r2, blue_palette
	bl palette_set_block

	; Sync tracker.
	bl rocket_init
	bl rocket_start

	; Enable Vsync event
	mov r0, #OSByte_EventEnable
	mov r1, #Event_VSync
	SWI OS_Byte

main_loop:

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
	bl rocket_update

	; show debug
	.if _DEBUG
	bl debug_write_vsync_count
	.endif

	; DO STUFF HERE!
	bl get_next_screen_for_writing
	bl tunnel_fx
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
	mov r0, #30
	swi OS_WriteC

.if _ENABLE_MUSIC
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

	mov r0, r3
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex2
	adr r0, debug_string
	swi OS_WriteO
.else
	ldr r0, vsync_delta	; rocket_sync_time
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex4

	adr r0, debug_string
	swi OS_WriteO
.endif
	mov pc, r14

debug_string:
	.skip 8
.endif

get_screen_addr:
	str lr, [sp, #-4]!
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi OS_ReadVduVariables
	ldr pc, [sp], #4
	
screen_addr_input:
	.long VD_ScreenStart, -1

screen_addr:
	.long 0					; ptr to the current VIDC screen bank being written to.

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
; Additional code modules
; ============================================================================

.include "lib/rocket.asm"
.include "lib/mode9-palette.asm"

.macro PIXEL_LOOKUP_TO reg
	; r0 = XXvv00uu
	add r3, r0, r9				; XXvv00uu + YYbb00aa
	and r0, r3, #0x000000ff
	and r1, r3, #0x00ff0000
	add r0, r0, r11
	ldrb \reg, [r0, r1, lsr #8]
	; 8c
.endm

tunnel_fx:
	str lr, [sp, #-4]!

	mov r0, #0
	bl rocket_sync_get_val_hi	; offset
	mov r9, r1

	mov r0, #1
	bl rocket_sync_get_val_hi	; offset
	orr r9, r9, r1, lsl #16		; 00bb00aa

	ldr r12, screen_addr
	add r2, r12, #Screen_Stride
	add r5, r12, #Screen_Bytes

	adr r11, xor_texture		; 256x256 pixels = 256x256 bytes
	adr r10, tunnel_map			; 160x128 half-words

.1:
    .rept Screen_Stride / 8
	ldmia r10!, {r5-r8}			; 8 pixels worth of (u,v)
	; 3+4*1.25 = 8c

	; r5 = v1v0u1u0
	; pixel 0
	bic r0, r5, #0x0000ff00
	; r0 = XXvv00uu
	PIXEL_LOOKUP_TO r4
	; 10c

	; pixel 1
	mov r0, r5, lsr #8
	bic r0, r0, #0x0000ff00
	; r0 = 00vv00uu
	PIXEL_LOOKUP_TO r3
	orr r4, r4, r3, lsl #8		; pixel << 8
	; 11c

	; r6 = v3v2u3u2
	; pixel 2
	bic r0, r6, #0x0000ff00
	; r0 = XXvv00uu
	PIXEL_LOOKUP_TO r3
	orr r4, r4, r3, lsl #16		; pixel << 16
	; 11c

	; pixel 3
	mov r0, r6, lsr #8
	bic r0, r0, #0x0000ff00
	; r0 = 00vv00uu
	PIXEL_LOOKUP_TO r3
	orr r4, r4, r3, lsl #24		; pixel << 24
	; 11c

	; r7 = v1v0u1u0
	; pixel 4
	bic r0, r7, #0x0000ff00
	; r0 = XXvv00uu
	PIXEL_LOOKUP_TO r5
	; 10c

	; pixel 5
	mov r0, r7, lsr #8
	bic r0, r0, #0x0000ff00
	; r0 = 00vv00uu
	PIXEL_LOOKUP_TO r3
	orr r5, r5, r3, lsl #8		; pixel << 8
	; 11c

	; r8 = v3v2u3u2
	; pixel 6
	bic r0, r8, #0x0000ff00
	; r0 = XXvv00uu
	PIXEL_LOOKUP_TO r3
	orr r5, r5, r3, lsl #16		; pixel << 16
	; 11c

	; pixel 7
	mov r0, r8, lsr #8
	bic r0, r0, #0x0000ff00
	; r0 = 00vv00uu
	PIXEL_LOOKUP_TO r3
	orr r5, r5, r3, lsl #24		; pixel << 24
	; 11c

	stmia r12!, {r4-r5}			; finally write 8 pixels to the screen!
	stmia r2!, {r4-r5}
	; 6.5c*2 = 13c

	; 8+43+43+13 = 

	.endr

	; 103c * 20 = 2060c + DRAM per row

	add r2, r2, #Screen_Stride
	add r12, r12, #Screen_Stride

	; r9 does triple duty! Use top byte as line counter!
	adds r9, r9, #0x01<<24
	cmp r9, #Screen_Height<<23
	blt .1
	; 8c

	; 2068c per row * 128 = 248,160c + DRAM per screen

	ldr pc, [sp], #4


; ============================================================================
; Data Segment
; ============================================================================

.if _ENABLE_MUSIC
module_filename:
	.byte "<Demo$Dir>.Music",0
	.align 4
.endif

blue_palette:
	.long 0x00000000
	.long 0x00110000
	.long 0x00220000
	.long 0x00330000
	.long 0x00440000
	.long 0x00550000
	.long 0x00660000
	.long 0x00770000
	.long 0x00880000
	.long 0x00990000
	.long 0x00AA0000
	.long 0x00BB0000
	.long 0x00CC0000
	.long 0x00DD0000
	.long 0x00EE0000
	.long 0x00FF0000

; (u,v) coordinates interleaved, 1 byte each
; 1 word = 2 pixels worth
tunnel_map:
.incbin "data/tun.bin"

; MODE 9 texture, 4 bpp x 2
xor_texture:
.incbin "data/xor.bin"

; ============================================================================
; BSS Segment
; ============================================================================

palette_osword_block:
    .skip 8
    ; logical colour
    ; physical colour (16)
    ; red
    ; green
    ; blue
    ; (pad)
