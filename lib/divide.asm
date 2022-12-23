; ============================================================================
; Division routines.
; ============================================================================

; Divide R0 by R1
; Parameters:
;  R0=numerator  [s15.16]       ; (a<<16)
;  R1=divisor    [s15.16]       ; (b<<16)
; Trashes:
;  R8-R10
divide:
    ; Limited precision.
    mov r1, r1, asr #10         ; [16.6] (b<<6)

    CMP R1,#0                   ; Test for division by zero
    ADREQ R0,divbyzero          ; and flag an error
    SWIEQ OS_GenerateError      ; when necessary

    cmp r0, #0                  ; Test if result is zero
    moveq pc, lr

    ; Signed division - any better way to do this?
    eor r10, r0, r1             ; R0 eor R1 indicates sign of result
    cmp r0, #0
    rsbmi r0, r0, #0            ; make positive
    cmp r1, #0
    rsbmi r1, r1, #0            ; make positive  

    .if _USE_RECIPROCAL_TABLE
    adr r9, reciprocal_table
    bic r8, r1, #0xff0000       ; [10.6]    (b<<6)
    ldr r8, [r9, r8, lsl #2]    ; [0.16]    (1<<22)/(b<<6) = (1<<16)/b
    mov r0, r0, asr #10         ; [16.6]    (a<<6)
    mul r9, r0, r8              ; [10.22]   (a<<6)*(1<<16)/b = (a<<22)/b
    mov r9, r9, asr #6          ; [10.16]   (a<<16)/b = (a/b)<<16
    .else

    ; Limited precision.
    mov r0, r0, asl #8          ; [8.16]

    ; Taken from Archimedes Operating System, page 28.
    MOV R8, #1
    MOV R9, #0
    CMP R1, #0
    .1:                         ; raiseloop
    BMI .3
    CMP R1,R0
    BHI .2
    MOVS R1,R1,LSL #1
    MOV R8,R8,LSL #1
    B .1  
    .3:                         ; raisedone
    CMP R0,R1
    SUBCS R0,R0,R1
    ADDCS R9,R9,R8              ; Accumulate result
    .2:                         ; nearlydone
    MOV R1,R1,LSR #1
    MOVS R8,R8,LSR #1
    BCC .3

    .endif

    movs r10, r10               ; get sign back
    movpl r0, r9                ; Move positive result into R0*
    rsbmi r0, r9, #0            ; Neative result into R0*
    MOV PC,R14                  ; and return

    ; * Remove the lines marked with asterisks to
    ; return R0 MOD R1 instead of R0 DIV R1

    divbyzero: ;The error block
    .long 18
	.byte "Divide by Zero"
	.align 4
	.long 0

; x = 0.0 to 256.0 [1 to 1<<8]
; There are 1<<16 table entries so x<<(16-8) = x<<8
; Table is 1<<24 / x<<8 = (1/x) << 16

; If want x = 0.0 to 1024.0 [1 to 1<<10]
; There are 1<<16 table entries so x<<(16-10) = x<<6
; Then table is 1<<22 / x<<6 = (1/x) << 16

.if _USE_RECIPROCAL_TABLE
; Trashes: r0-r2, r8-r9, r12
MakeReciprocal:
    adr r12, reciprocal_table
    mov r2, #0
    str r2, [r12], #4
 
    mov r2, #1
.4:
    mov r0, #1<<22
    mov r1, r2

    ; Taken from Archimedes Operating System, page 28.
    MOV R8, #1
    MOV R9, #0
    CMP R1, #0
    .1:                         ; raiseloop
    BMI .3
    CMP R1,R0
    BHI .2
    MOVS R1,R1,LSL #1
    MOV R8,R8,LSL #1
    B .1  
    .3:                         ; raisedone
    CMP R0,R1
    SUBCS R0,R0,R1
    ADDCS R9,R9,R8              ; Accumulate result
    .2:                         ; nearlydone
    MOV R1,R1,LSR #1
    MOVS R8,R8,LSR #1
    BCC .3

    str r9, [r12], #4
    add r2, r2, #1
    cmp r2, #1<<16
    blt .4

    mov pc, lr
.endif
