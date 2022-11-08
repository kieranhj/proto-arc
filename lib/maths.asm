; ============================================================================
; Maths routines.
; Start with dot product, matmul etc.
; ============================================================================

.equ PRECISION_BITS, 16
.equ PRECISION_SHIFT, 8

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

dot_product:
    ldmia r1, {r3-r5}                   ; [s10.10]
    ldmia r2, {r6-r8}                   ; [s10.10]

    mov r3, r3, asr #PRECISION_SHIFT    ; [s10.5]
    mov r4, r4, asr #PRECISION_SHIFT    ; [s10.5]
    mov r5, r5, asr #PRECISION_SHIFT    ; [s10.5]
    mov r6, r6, asr #PRECISION_SHIFT    ; [s10.5]
    mov r7, r7, asr #PRECISION_SHIFT    ; [s10.5]
    mov r8, r8, asr #PRECISION_SHIFT    ; [s10.5]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s20.10]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s20.10]
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s20.10]

    mov pc, lr

; Dot product.
; Parameters:
;  R1=ptr to vector A.
;  R2=ptr to unit vector B.
; Returns:
;  R0=dot product of A and B.
; Trashes: R3-R8
;
; Computes R0 = A . B where B is a unit vector.

dot_product_unit:
    ldmia r1, {r3-r5}                   ; [s10.10]
    ldmia r2, {r6-r8}                   ; [s1.10]

    mul r0, r3, r6                      ; r0 = a1 * b1  [s10.20]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s10.20]
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s10.20]

    mov r0, r0, asr #PRECISION_BITS     ; [s10.10]
    mov pc, lr

; R0=ptr to 9x9 matrix M stored in row order.
; R1=ptr to vector A.
; R2=ptr to vector B.
; Trashes: R3-R9
;
; Compute B = M.A where:
;
; M = [ a b c ]  A = [ x ]
;     [ d e f ]      [ y ]
;     [ g h i ]      [ z ]
;
; B = M . A = [ a.x + b.y + c.z ]
;             [ d.x + e.y + f.z ]
;             [ g.x + h.y + i.z ]

matrix_multiply_vector:
    ldmia r0!, {r3-r5}                  ; [ a b c ][s10.10]
    ldmia r1, {r6-r8}                   ; [ x y z ][s10.10]

    mov r3, r3, asr #PRECISION_SHIFT    ; [s10.5]
    mov r4, r4, asr #PRECISION_SHIFT    ; [s10.5]
    mov r5, r5, asr #PRECISION_SHIFT    ; [s10.5]
    mov r6, r6, asr #PRECISION_SHIFT    ; [s10.5]
    mov r7, r7, asr #PRECISION_SHIFT    ; [s10.5]
    mov r8, r8, asr #PRECISION_SHIFT    ; [s10.5]

    mul r9, r3, r6                      ; r9 = a * x  [s20.10]
    mla r9, r4, r7, r9                  ;   += b * y  [s20.10]
    mla r9, r5, r8, r9                  ;   += c * z  [s20.10]

    str r9, [r2, #0]                    ; vectorB[x] = r9

    ldmia r0!, {r3-r5}                  ; [ d e f ][s10.10]
    mov r3, r3, asr #PRECISION_SHIFT    ; [s10.5]
    mov r4, r4, asr #PRECISION_SHIFT    ; [s10.5]
    mov r5, r5, asr #PRECISION_SHIFT    ; [s10.5]

    mul r9, r3, r6                       ; r9 = d * x  [s20.10]
    mla r9, r4, r7, r9                  ;    += e * y  [s20.10]
    mla r9, r5, r8, r9                  ;    += f * z  [s20.10]
    str r9, [r2, #4]                    ; vectorB[y] = r9

    ldmia r0!, {r3-r5}                  ; [ g h i ][s10.10]
    mov r3, r3, asr #PRECISION_SHIFT    ; [s10.5]
    mov r4, r4, asr #PRECISION_SHIFT    ; [s10.5]
    mov r5, r5, asr #PRECISION_SHIFT    ; [s10.5]

    mul r9, r3, r6                      ; r9 = g * x  [s20.10]
    mla r9, r4, r7, r9                  ;   += h * y  [s20.10]
    mla r9, r5, r8, r9                  ;   += i * z  [s20.10]
    str r9, [r2, #8]                    ; vectorB[z] = r9
    mov pc, lr

; R0=ptr to 9x9 unit matrix M stored in row order.
; R1=ptr to vector A.
; R2=ptr to vector B.
; Trashes: R3-R9
;
; Compute B = M.A where M is a unit matrix (all elements [-1.0,+1.0])

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

.if 0
run_dot_product_tests:
    stmfd sp!, {r0-r12, lr}

    adr r10, dot_product_tests
    mov r11, #NUM_dot_product_tests
    .1:
    mov r0, r10
    add r1, r10, #12
    ldr r12, [r10, #24]

    bl dot_product

    cmp r2, r12
    bne unit_test_error

    add r10, r10, #28
    subs r11, r11, #1
    bne .1

    ldmfd sp!, {r0-r12, pc}

run_dot_product_unit_tests:
    stmfd sp!, {r0-r12, lr}

    adr r10, dot_product_unit_tests
    mov r11, #NUM_dot_product_unit_tests
    .1:
    mov r0, r10
    add r1, r10, #12
    ldr r12, [r10, #24]

    bl dot_product_unit

    cmp r2, r12
    bne unit_test_error

    add r10, r10, #28
    subs r11, r11, #1
    bne .1

    ldmfd sp!, {r0-r12, pc}


; R2=return dot product value.
unit_test_error:
    mov r0, r11
    bl debug_write_fp

    mov r0, r10
    bl debug_write_vector
    add r0, r10, #12
    bl debug_write_vector
    ldr r0, [r10, #24]
    bl debug_write_fp
    mov r0, r2
    bl debug_write_fp

	adr r0, error_vector_unit_test
	swi OS_GenerateError
    ; stop?

error_vector_unit_test:
	.long 0
	.byte "Vector failed unit test!"
	.align 4
	.long 0

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

.macro FLOAT_TO_FP value
    .float 1<<PRECISION_BITS * (\value)
.endm

.macro test_dot_prod Ax, Ay, Az, Bx, By, Bz
    ; vector A, vector B, expected result.
    FLOAT_TO_FP \Ax
    FLOAT_TO_FP \Ay
    FLOAT_TO_FP \Az
    FLOAT_TO_FP \Bx
    FLOAT_TO_FP \By
    FLOAT_TO_FP \Bz
    FLOAT_TO_FP (\Ax * \Bx + \Ay * \By + \Az * \Bz)
.endm

.equ NUM_dot_product_tests, 12

dot_product_tests:
; Unit vectors.
test_dot_prod 3.0, 4.0, 5.0,  1.0, 0.0, 0.0
test_dot_prod 3.0, 4.0, 5.0,  0.0, 1.0, 0.0
test_dot_prod 3.0, 4.0, 5.0,  0.0, 0.0, 1.0

; Zero vector.
test_dot_prod 3.0, 4.0, 5.0,  0.0, 0.0, 0.0
test_dot_prod 0.0, 0.0, 0.0,  100.0, 200.0, 300.0

; Orthogonal vectors.
test_dot_prod 10.0, 0.0, 0.0,  0.0, 20.0, 0.0
test_dot_prod 0.0, 20.0, 0.0,  0.0, 0.0, 30.0
test_dot_prod 0.0, 0.0, 30.0,  10.0, 0.0, 0.0

; Negative vectors.
test_dot_prod 10.0, 0.0, 0.0,  -1.0, 0.0, 0.0
test_dot_prod 100.0, 200.0, 300.0,  -1.0, -1.0, -1.0
test_dot_prod 100.0, 200.0, 300.0,  -1.0, -1.0, 1.0
test_dot_prod -100.0, -200.0, -300.0,  -1.0, -1.0, -1.0

.equ NUM_dot_product_unit_tests, 6

dot_product_unit_tests:
; Maximum bits.
test_dot_prod 1023.99, 0.0, 0.0,  1.0, 0.0, 0.0
test_dot_prod 0.0, 1023.99, 0.0,  0.0, -1.0, 0.0
test_dot_prod 0.0, 0.0, -1024,  0.0, 0.0, 1.0
test_dot_prod -1024.0, 0.0, 0.0  -1.0, 0.0, 0.0

test_dot_prod 100.0, 200.0, 300.0, 0.1, 0.2, 0.3
test_dot_prod -300.0, 200.0, -100.0,  0.9999, -0.9999, 0.9999

; Thoughts - tests are useful! But writing tests in assembler is
; pain! Need a way to write these in BBC BASIC and test library fns.
; etc. in isolation.
.endif
