; ============================================================================
; Vector routines.
; ============================================================================

.equ VECTOR3_SIZE, 3*4

.macro VECTOR3 x, y, z
    FLOAT_TO_FP \x
    FLOAT_TO_FP \y
    FLOAT_TO_FP \z
.endm

; TODO: make_vector?
; TODO: vector_add?

; Dot product.
; Parameters:
;  R1=ptr to vector A.
;  R2=ptr to vector B.
; Returns:
;  R0=dot product of A and B.
; Trashes: R3-R8
;
; Computes R0 = A . B where:
;
; A = [ a1 ]   B = [ b1 ]
;     [ a2 ]       [ b2 ]
;     [ a3 ]       [ b3 ]
;
; A.B = a1 * b1 + a2 * b2 + a3 * b3
; A.B = |A||B|.cos T
;
dot_product:
    ldmia r1, {r3-r5}                   ; [s10.10]
dot_product_loaded:
    ldmia r2, {r6-r8}                   ; [s10.10]

    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s10.5]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s10.5]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s10.5]
    mov r6, r6, asr #MULTIPLICATION_SHIFT    ; [s10.5]
    mov r7, r7, asr #MULTIPLICATION_SHIFT    ; [s10.5]
    mov r8, r8, asr #MULTIPLICATION_SHIFT    ; [s10.5]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s20.10]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s20.10]
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s20.10]

    mov pc, lr


.if _DEBUG
; R0=vector ptr.
debug_write_vector:
    stmfd sp!, {r0, r3, lr}
    mov r3, r0
    ldr r0, [r3, #0]
    bl debug_write_fp
    ldr r0, [r3, #4]
    bl debug_write_fp
    ldr r0, [r3, #8]
    bl debug_write_fp
    ldmfd sp!, {r0, r3, pc}
.endif
