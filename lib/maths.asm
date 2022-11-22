; ============================================================================
; Maths routines.
; ============================================================================

.equ PRECISION_BITS, 16
.equ MULTIPLICATION_SHIFT, PRECISION_BITS/2
.equ PRECISION_MULTIPLIER, 1<<PRECISION_BITS

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
;
; TODO: Update all this to s15.16.

maths_init:
    str lr, [sp, #-4]!
    .if _MAKE_SINUS_TABLE
    bl MakeSinus
    .endif
    .if _USE_RECIPROCAL_TABLE
    bl MakeReciprocal
    .endif
    .if _INCLUDE_SPAN_GEN
    bl gen_code
    .endif
    ldr pc, [sp], #4

.if _DEBUG
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
    .long 1<<PRECISION_BITS * (\value)
.endm

; ============================================================================

.include "lib/sine.asm"
.include "lib/vector.asm"
.include "lib/matrix.asm"
.include "lib/divide.asm"
.include "lib/polygon.asm"
.if _INCLUDE_SQRT
.include "lib/sqrt.asm"
.endif
.if _INCLUDE_SPAN_GEN
.include "lib/span_gen.asm"
.endif

; ============================================================================
