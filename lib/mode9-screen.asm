; ============================================================================
; MODE 9 screen routines
; ============================================================================

; R8 = screen address
; trashes r0-r9
screen_cls:
	add r9, r8, #Screen_Bytes
	mov r0, #0
	mov r1, #0
	mov r2, #0
	mov r3, #0
	mov r4, #0
	mov r5, #0
	mov r6, #0
	mov r7, #0
.1:
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	stmia r8!, {r0-r7}
	cmp r8, r9
	blt .1
	mov pc, lr
