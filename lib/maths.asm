; ============================================================================
; Maths routines.
; Start with dot product, matmul etc.
; ============================================================================

.equ PRECISION_BITS, 16
.equ MULTIPLICATION_SHIFT, PRECISION_BITS/2

.equ MATHS_CONST_0, 0
.equ MATHS_CONST_QUARTER, 1<<(PRECISION_BITS-2)
.equ MATHS_CONST_HALF, 1<<(PRECISION_BITS-1)
.equ MATHS_CONST_1, (1<<PRECISION_BITS)

; General notes.
;  Say s10.10, then lose 5 bits of precision at multiplication?
;  Max value 0x1fffff >> 5 = 0xffff. Squared 0xffff * 0xffff = 0xfffe0001
;  Allows coordinates that are [-1024, +1023] with accuracy ~0.03
;  
;  Normalised vector in s1.10. [-1.0, +1.0]
;   +1.0 => 0x400 and -1.0 => 0xc00 (or really 0xfffffc00)
;
;  TODO: Decide on precision required for demos and check with Sarah!
;        At some point you just scale up the coordinates so they're in range?
;        Might need more precision at the lower end than 10 bits if we're
;        dealing with lots of vectors that are normalised / rotations.

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

; R0=fp value.
debug_write_fp:
    stmfd sp!, {r1, r2}
	adr r1, debug_string
	mov r2, #16
	swi OS_ConvertHex8
	adr r0, debug_string
	swi OS_WriteO
    mov r0, #32
    swi OS_WriteC
    ldmfd sp!, {r1, r2}
    mov pc, lr
.endif

.macro FLOAT_TO_FP value
    .float 1<<PRECISION_BITS * (\value)
.endm

.macro VECTOR3 x, y, z
    FLOAT_TO_FP \x
    FLOAT_TO_FP \y
    FLOAT_TO_FP \z
.endm

; ============================================================================

.include "lib/sine.asm"
.include "lib/matrix.asm"

; ============================================================================

.if 0               ; Feels like too early optimisation.
; Dot product.
; Parameters:
;  R1=ptr to vector A.
;  R2=ptr to unit vector B.
; Returns:
;  R0=dot product of A and B.
; Trashes: R3-R8
;
; Computes R0 = A . B where B is a unit vector.
;
dot_product_unit:
    ldmia r1, {r3-r5}                   ; [s10.10]
    ldmia r2, {r6-r8}                   ; [s1.10]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s10.20]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s10.20]
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s10.20]

    mov r0, r0, asr #PRECISION_BITS     ; [s10.10]
    mov pc, lr

; R0=ptr to 9x9 unit matrix M stored in row order.
; R1=ptr to vector A.
; R2=ptr to vector B.
; Trashes: R3-R9
;
; Compute B = M.A where M is a unit matrix (all elements [-1.0,+1.0])
;
unit_matrix_multiply_vector:
    ldmia r0!, {r3-r5}                  ; [ a b c ]   [s1.10]
    ldmia r1, {r6-r8}                   ; [ x y z ]   [s10.10]

    mul r9, r3, r6                      ; r9 = a * x  [s10.20]
    mla r9, r4, r7, r9                  ;   += b * y  [s10.20]
    mla r9, r5, r8, r9                  ;   += c * z  [s10.20]
    mov r9, r9, asr #PRECISION_BITS     ; [s10.10]
    str r9, [r2, #0]                    ; vectorB[x] = r9

    ldmia r0!, {r3-r5}                  ; [ d e f ]   [s1.10]
    mul r9, r3, r6                      ; r9 = d * x  [s10.20]
    mla r9, r4, r7, r9                  ;   += e * y  [s10.20]
    mla r9, r5, r8, r9                  ;   += f * z  [s10.20]
    mov r9, r9, asr #PRECISION_BITS     ; [s10.10]
    str r9, [r2, #4]                    ; vectorB[y] = r9

    ldmia r0!, {r3-r5}                  ; [ g h i ]   [s1.10]
    mul r9, r3, r6                      ; r9 = g * x  [s10.20]
    mla r9, r4, r7, r9                  ;   += h * y  [s10.20]
    mla r9, r5, r8, r9                  ;   += i * z  [s10.20]
    mov r9, r9, asr #PRECISION_BITS     ; [s10.10]
    str r9, [r2, #8]                    ; vectorB[z] = r9

    mov pc, lr
.endif
