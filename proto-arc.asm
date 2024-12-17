; ============================================================================
; Prototype Framework - stripped back from stniccc-archie.
; ============================================================================

.equ _DEBUG, 1
.equ _ENABLE_MUSIC, 0
.equ _FIX_FRAME_RATE, 0					; useful for !DDT breakpoints
.equ _SYNC_EDITOR, 0

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

    bl MakeSinus

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

    ;adr r2, gradient_pal
    ;bl set_gradient

    adr r2, itm_pal
    bl palette_set_block

	; Sync tracker.
	;bl rocket_init
	;bl rocket_start

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
	;bl rocket_update

	; show debug
	.if _DEBUG
	bl debug_write_vsync_count
	.endif

	; DO STUFF HERE!
	bl get_next_screen_for_writing

    mov r0, #24             ; border
    mov r4, #0x000000ff     ; red
    bl palette_set_colour

	bl rotate_fx

    mov r0, #24             ; border
    mov r4, #0x00000000     ; black
    bl palette_set_colour

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

;.include "lib/rocket.asm"
.include "lib/mode9-palette.asm"

.if 0
tunnel_offset_u:
    .byte 0

tunnel_offset_v:
    .byte 0

.p2align 2

tunnel_fx:
	str lr, [sp, #-4]!

    ldrb r9, tunnel_offset_u
    add r9, r9, #1
    and r9, r9, #0x7f           ; u [0, 127]
    strb r9, tunnel_offset_u

    ldrb r1, tunnel_offset_v
    add r1, r1, #1
    and r1, r1, #0x7f           ; v [0, 127]
    strb r1, tunnel_offset_v

	ldr r12, screen_addr

    adr r8, xor_texture		    ; base of the texture

    add r8, r8, r9              ; add u offset
    add r8, r8, r1, lsl #7      ; add v offset (128 bytes per row)

    add r9, r8, #4096           ; only 4096 bytes are addressable at a time
    add r10, r9, #4096          ; using offset load, so use registers
    add r11, r10, #4096         ; 4*4096 = 16384 = 128*128

    b unrolled_code

MakeUnrolledCode:
    str lr, [sp, #-4]!

    adr r12, unrolled_code          ; dest
    adr r11, tunnel_map             ; uv data
	; Each word is 2 pixels of packed U,V  = v1v0u1u0
    ; u,v [0, 255] => we're going to use half resolution.

    mov r10, #128                   ; rows to plot
.1:

    mov r6, #160                    ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    ; Load 4 pixels worth of (u,v)

    ldmia r11!, {r0-r1}             ; R0=v1v0u1u0 R1=v3v2u3u2

    ; Copy one snippet for 4 pixels = assemble 1 word for writing

    adr r8, unrolled_code_snippet

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg
    and r2, r0, #0xfe               ; u0<<1  [0, 127]
    and r3, r0, #0xfe0000           ; v0<<17 [0, 127]
    mov r4, r3, lsl #10             ; bottom 5 bits of v0
    mov r2, r2, lsr #1
    orr r2, r2, r4, lsr #20         ; v0 | u0
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #22             ; top 2 bits of v0
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 0

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r0, #0xfe00             ; u1<<9  [0, 127]
    and r3, r0, #0xfe000000         ; v1<<25 [0, 127]
    mov r4, r3, lsl #2              ; bottom 5 bits of v1
    mov r2, r2, lsr #9
    orr r2, r2, r4, lsr #20         ; v1 | u1
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #30             ; top 2 bits of v1
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 1

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r1, #0xfe               ; u2<<1  [0, 127]
    and r3, r1, #0xfe0000           ; v2<<17 [0, 127]
    mov r4, r3, lsl #10             ; bottom 5 bits of v2
    mov r2, r2, lsr #1
    orr r2, r2, r4, lsr #20         ; v2 | u2
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #22             ; top 2 bits of v2
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 3

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #16
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    and r2, r1, #0xfe00             ; u3<<9  [0, 127]
    and r3, r1, #0xfe000000         ; v3<<25 [0, 127]
    mov r4, r3, lsl #2              ; bottom 5 bits of v3
    mov r2, r2, lsr #9
    orr r2, r2, r4, lsr #20         ; v3 | u3
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r3, lsr #30             ; top 2 bits of v3
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 5

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #24
    orr r7, r7, r9, lsl #12         ; dest reg
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2

    ; Write out plot snippet.
    ldmia r8!, {r0-r2}
    stmia r12!, {r0-r2}

    subs r6, r6, #32                ; 8 words at a time = 32 chunky pixels.
    bne .3

    ; Write out increment screen ptr to skip a line.
    ldr r0, [r8], #4
    str r0, [r12], #4

    subs r10, r10, #1               ; next row
    bne .1

    ; Write out rts.
    ldr r0, [r8], #4
    str r0, [r12], #4

    ldr pc, [sp], #4
.endif

; R0=U0
; R1=V0
; R10=du
; R11=dv
MakeUnrolledRot:
    str lr, [sp, #-4]!

    adr r12, unrolled_code          ; dest

    mov r6, #160                    ; columns to plot
.3:
    mov r9, #0                      ; dest register

.2:
    adr r8, unrolled_code_snippet

    ; Calculate 12-bit offset.

    ldr r7, [r8], #4                ; ldrb rX, [rY, #Z]
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 0

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 

    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 1

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 2

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 
    
    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 3

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 4

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 
    
    ldr r7, [r8], #4                ; ldrb r14, [rY, #Z]
    ; Dest reg fixed (R14)
    mov r2, r1, lsr #25             ; INT(v) 7 bits total
    and r2, r2, #31                 ; Select bottom 5 bits of V.
    mov r2, r2, lsl #7              ; * tex_width
    add r2, r2, r0, lsr #25         ; + INT(u) for 12 bits total.
    orr r7, r7, r2                  ; offset [0, 4095]
    mov r3, r1, lsr #30             ; INT(v) 7 bits total select top 2 bits
    add r3, r3, #8                  ; [8, 11]
    orr r7, r7, r3, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 5

    ldr r7, [r8], #4                ; orr r0, r0, r14, lsl #8
    orr r7, r7, r9, lsl #12         ; dest reg (CONST)
    orr r7, r7, r9, lsl #16         ; base reg
    str r7, [r12], #4               ; write out instruction 6

    ; Update u,v.
    add r0, r0, r11                 ; u+=dudx
    sub r1, r1, r10                 ; v+=dvdx 

    ; Four pixels per word.

    ; Do this 8 times for R0-7
    add r9, r9, #1
    cmp r9, #8
    bne .2

    ; Write out plot snippet.
    ldmia r8!, {r2-r4}
    stmia r12!, {r2-r4}

    subs r6, r6, #32                ; 8 words at a time = 32 chunky pixels.
    bne .3

    ; Write out increment screen ptr to skip a line.
    ldr r0, [r8], #4
    str r0, [r12], #4

    ; Write out rts.
    ldr r0, [r8], #4
    str r0, [r12], #4

    ldr pc, [sp], #4


unrolled_code_snippet:
    ldrb r0, [r0, #0]               ; 4c    <= mod imm offset, base reg, dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #8         ; 1c    <= mod dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #16        ; 1c    <= mod dest reg
    ldrb r14, [r0, #0]              ; 4c    <= mod imm offset, base reg
    orr r0, r0, r14, lsl #24        ; 1c    <= mod dest reg

    ; Plot the pixels.
    add r14, r12, #Screen_Stride    ; 1c
    stmia r12!, {r0-r7}             ; 3+8*1.25=13c
    stmia r14!, {r0-r7}             ; 3+8*1.25=13c

    ; 19c per word * 8 + 27 = 179c for 8 words * 5 = 895c per row * 128 = 114560c per screen

    ; Skip a line.
    add r12, r12, #Screen_Stride    ; 1c

    ; Return.
    ldr pc, [sp], #4

; ============================================================================

; R2=ptr to gradient in 0x0rgb format.
set_gradient:
    str lr, [sp, #-4]!

    mov r3, #0
.1:
    ldr r0, [r2], #4

    mov r1, r0, lsr #8
    orr r1, r1, r1, lsl #4

    and r4, r0, #0x00f0
    orr r4, r4, r4, lsr #4
    orr r4, r1, r4, lsl #8

    and r1, r0, #0x000f
    orr r1, r1, r1, lsl #4
    orr r4, r4, r1, lsl #16

    bl palette_set_colour

    add r3, r3, #1
    cmp r3, #16
    bne .1

    ldr pc, [sp], #4

; ******************************************************************
; * Makes sine values [0-0x10000]
; * Converted to ARM from https://github.com/askeksa/Rose/blob/master/engine/Sinus.S
; ******************************************************************

sinus_table_p:
    .long sinus_table_no_adr    ; address patched by the linker from bss segment

.equ Sinus_TableBits,     14                  ; 16384
.equ Sinus_TableSize,     1<<Sinus_TableBits
.equ Sinus_TableShift,    32-Sinus_TableBits

MakeSinus:
    ldr r8, sinus_table_p
    mov r10, #Sinus_TableSize/2*4       ; offset halfway through the table.
    sub r11, r10, #4            ; #Sinus_TableSize/2*4-4

    mov r0, #0
    str r0, [r8], #4
    add r9, r8, r11             ; #Sinus_TableSize/2*4-4
    str r0, [r9]

    mov r7, #1
.1:
    mov r1, r7
    mul r1, r7, r1              ; r7 ^2
    mov r1, r1, asr #8

    mov r0, #2373
    mul r0, r1, r0
    mov r0, r0, asr #16
    rsb r0, r0, #0
    add r0, r0, #21073
    mul r0, r1, r0
    mov r0, r0, asr #16
    rsb r0, r0, #0
    add r0, r0, #51469
    mul r0, r7, r0
    mov r0, r0, asr #13

    mov r0, r0, asl #2          ; NB. Rose originally [0x0, 0x4000]

    str r0, [r8], #4
    str r0, [r9, #-4]!
    rsb r0, r0, #0
    str r0, [r9, r10]           ; #Sinus_TableSize/2*4
    str r0, [r8, r11]           ; #Sinus_TableSize/2*4-4

    add r7, r7, #1
    cmp r7, #Sinus_TableSize/4
    blt .1

    rsb r0, r0, #0
    str r0, [r9, #-4]!
    rsb r0, r0, #0
    str r0, [r9, r10]
    mov pc, lr

; ============================================================================

rotate_angle:
    .long 0         ; {s8.16}

rotate_scale:
    .long 2<<16     ; {8.16}

rotate_dir:
    .long 1<<9

; dudy = sin(a) / scale; // horizontal step on image per vertical step on screen
; dvdy = cos(a) / scale; // vertical step on image per vertical step on screen
; dudx = dvdy;           // horizontal step on image per horizontal step on screen
; dvdx = -dudy;          // vertical step on image per horizontal step on screen

rotate_fx:
    str lr, [sp, #-4]!

    ldr r9, sinus_table_p

    ldr r0, rotate_angle
    mov r1, r0, asl #8                  ; {0.32}
    mov r1, r1, lsr #Sinus_TableShift   ; {14.0}
    ldr r1, [r9, r1, lsl #2]            ; sin(a)    {s1.16}
    mov r1, r1, asr #8                  ; {s1.8}

    add r0, r0, #64<<16                 ; cos
    mov r2, r0, asl #8                  ; {0.32}
    mov r2, r2, lsr #Sinus_TableShift   ; {14.0}
    ldr r2, [r9, r2, lsl #2]            ; cos(a)    {s1.16}
    mov r2, r2, asr #8                  ; {s1.8}

    ldr r0, rotate_scale                ; {8.16}
    mov r0, r0, asr #8                  ; {8.8}

    mul r1, r0, r1                      ; dudy {s15.16} sin(a)*scale
    mul r2, r0, r2                      ; dvdy {s15.16} cos(a)*scale

    adr r11, xor_texture                ; texture_p
    ldr r12, screen_addr                ; dest

    ; Centre rotation.
    ; Rotate vector to TL corner by -a.
    ; u = x*cos(-a) - y*sin(-a) = x*cos(a) + y*sin(a)
    ; v = x*sin(-a) + y*cos(-a) = -x*sin(a) + y*cos(a)
    mov r3, #-80                        ; TL x
    mov r4, #-64                        ; TL y

    mul r5, r2, r3                      ; x*cos(-a)
    mla r5, r1, r4, r5                  ; -y*sin(-a)

    mvn r3, r3                          ; -TL y
    mul r6, r1, r3                      ; -x*sin(-a)
    mla r6, r2, r4, r6                  ; +y*cos(-a)

    ; Reduce to 16-bit values for u,v,du,dv etc.
    mov r1, r1, asl #9
    mov r2, r2, asl #9
    mov r5, r5, asl #9
    mov r6, r6, asl #9

.if 1
    mov r10, #128                       ; rows
    stmfd sp!, {r1,r2,r5,r6,r10}

    mov r10, r1                         ; du
    mov r11, r2                         ; dv
    mov r0, #0                          ; U
    mov r1, #0                          ; V

    bl MakeUnrolledRot

    ; TODO: The above fn creates all the code from scratch.
    ;       We only need to update the offsets each frame.

    ; Pop all the regs to begin.
    ldmfd sp!, {r1,r2,r5,r6,r10}

    ldr r12, screen_addr                ; dest

    ; Loop over 128 rows.
.1:
    ; Calculate start U,V (r5, r6 above)

    ; Update texture base ptr for U and V for row.

    adr r8, xor_texture                 ; texture_p
    mov r4, r6, lsr #25                 ; retrieve top 7-bits of v
    add r8, r8, r4, lsl #7              ; v * tex_width
    add r8, r8, r5, lsr #25             ; + u

    ; Update u,v for next line.

    add r5, r5, r1                      ; u+=dudy
    add r6, r6, r2                      ; v+=dvdy

    stmfd sp!, {r1,r2,r5,r6,r10}

    ; Derive R8-11 for 4096 byte offsets.

    add r9, r8, #4096
    add r10, r9, #4096
    add r11, r10, #4096                 ; additional regs

    ; Call plot line.
    adr lr, .2
    str lr, [sp, #-4]!
    bl unrolled_code
    .2:

    ldmfd sp!, {r1,r2,r5,r6,r10}

    subs r10, r10, #1
    bne .1
.else
    ; Per row.
    mov r10, #128                       ; rows
.1:
    mov r7, r5                          ; working u
    mov r8, r6                          ; working v

    mov r9, #160                        ; cols
.2:
    ; Load texture

    ; v--- This can be computed as a register select for texture load.
    mov r4, r8, lsr #30                 ; INT(v) 7 bits total select top 2 bits
    add r14, r11, r4, lsl #12           ; Select 4096 byte chunk from top 2 bits

    ; v--- This can be computed as a 12-bit immediate offset.
    mov r4, r8, lsr #25                 ; INT(v) 7 bits total
    and r4, r4, #31                     ; Select bottom 5 bits.
    mov r4, r4, lsl #7                  ; * tex_width
    add r4, r4, r7, lsr #25             ; + INT(u) for 12 bits total.

    ; v--- This becomes lrdb rX, [rSelect, #imm offset]
    ldrb r0, [r14, r4]                  ; texel

    ; Update u,v
    add r7, r7, r2                      ; u+=dudx
    sub r8, r8, r1                      ; v+=dvdx 

    ; Plot 2x2 pixels
    strb r0, [r12, #Screen_Stride]
    strb r0, [r12], #1

    subs r9, r9, #1
    bne .2

    ; Move screen ptr.
    add r12, r12, #Screen_Stride

    ; Update u,v
    add r5, r5, r1                      ; u+=dudy
    add r6, r6, r2                      ; v+=dvdy

    subs r10, r10, #1
    bne .1
.endif

    ldr r0, rotate_angle
    add r0, r0, #1<<16
    str r0, rotate_angle

    ldr r0, rotate_scale
    ldr r1, rotate_dir
    add r0, r0, r1

    cmp r0, #4<<16          ; max
    movgt r0, #4<<16
    mvngt r1, r1

    cmp r0, #1<<15
    movlt r0, #1<<15
    mvnlt r1, r1
    
    str r0, rotate_scale
    str r1, rotate_dir

    ldr pc, [sp], #4


; ============================================================================
; Data Segment
; ============================================================================

.if _ENABLE_MUSIC
module_filename:
	.byte "<Demo$Dir>.Music",0
	.align 4
.endif

.if 0
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
.endif

; Use https://gradient-blaster.grahambates.com/ by Gigabates to generate nice palettes!
gradient_pal:
.long	0xff0,0xff3,0xfd5,0xec6,0xec7,0xeb8,0xda9,0xc9a,0xc8b,0xb7b,0xa6c,0x95d,0x84d,0x73e,0x52f,0x00f

itm_pal:
.incbin "data/itmpal.bin"

; (u,v) coordinates interleaved, 1 byte each
; 1 word = 2 pixels worth
.p2align 6
tunnel_map:
.incbin "data/tun2.bin"

; MODE 9 texture, 4 bpp x 2
.p2align 16
xor_texture:
.incbin "data/itm128.bin"
.incbin "data/itm128.bin"
;.incbin "data/xor128.bin"
;.incbin "data/xor128.bin"
;.incbin "data/cloud.bin"
;.incbin "data/cloud.bin"

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

; ******************************************************************
; * Sine table with 16384 entries in {s1.16} fixed point format.
; ******************************************************************

sinus_table_no_adr:
    .skip Sinus_TableSize*4

unrolled_code:
