; ============================================================================
; MODE 9 screen routines
; ============================================================================

; R8 = screen address
; trashes r0-r9,r11,r12
screen_cls:
	add r12, r11, #Screen_Bytes
	mov r0, #0
	mov r1, #0
	mov r2, #0
	mov r3, #0
	mov r4, #0
	mov r5, #0
	mov r6, #0
	mov r7, #0
	mov r8, #0
	mov r9, #0
.if 1
.1:
	stmia r11!, {r0-r9}		; 40 bytes
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}
	stmia r11!, {r0-r9}		; *8 = 320 bytes
	cmp r11, r12
	blt .1
.else
	; No loop version - saves a couple of scanlines if desperate.
	; Better to generate this code at runtime...!
	.rept Screen_Bytes / 40
	stmia r11!, {r0-r9}
	.endr
.endif
	mov pc, lr

.if 0
screen_dup_lines:
	ldr r12, screen_addr
	add r9, r12, #Screen_Bytes
	add r11, r12, #Screen_Stride
.1:
	.rept Screen_Stride / 32
	ldmia r12!, {r0-r7}
	stmia r11!, {r0-r7}
	.endr
	add r12, r12, #Screen_Stride
	add r11, r11, #Screen_Stride
	cmp r12, r9
	blt .1
	mov pc, lr
.endif
