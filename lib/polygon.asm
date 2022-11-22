; ============================================================================
; Polygon routines.
; ============================================================================

; Parameters:
;  R2=ptr to projected vertex array (x,y)
;  R3=4x vertex indices for quad
;  R4=colour byte?
;  R12=ptr to edge_dda_table [xs, m, ys, ye]
quad_store_edge_list:
    str lr, [sp, #-4]!

    and r0, r3, #0xff           ; index 0
    add r5, r2, r0, lsl #3      ; projected_verts + index*8
    ldmia r5, {r6, r7}          ; x_start, y_start
    mov r7, r7, asr #16         ; int(y_start)


    mov r0, r3, lsr #8          ; 
    and r0, r0, #0xff           ; index 1
    add r5, r2, r0, lsl #3      ; projected_verts + index*8
    ldmia r5, {r8, r9}          ; x_end, y_end
    mov r9, r9, asr #16         ; int(y_end)

    subs r1, r9, r7             ; int(y_end) - int(y_start)
    ; Skip horizontal edges.
    beq .1                      ; y_end == y_start?

    ; Store edge 0->1 dda data:
    stmia r12!, {r6, r7, r9}    ; [xs, ys, ye]

    mov r1, r1, asl #16         ; (ye-ys) [16.0]
    ; Compute m = (xe-xs) / (ye-ys) for edge 0->1
    sub r0, r8, r6              ; xs = xe-xs
    mov r6, r8                  ; (index 1 x_start)
    mov r7, r9                  ; (index 1 y_start)
    bl divide                   ; m = (xe-xs) / (ye-ys)

    ; Store edge 0->1 dda data:
    str r0, [r12], #4           ; [m]
    .1:

                                
    mov r0, r3, lsr #16         ; 
    and r0, r0, #0xff           ; index 2
    add r5, r2, r0, lsl #3      ; projected_verts + index*8
    ldmia r5, {r8, r9}          ; x_end, y_end
    mov r9, r9, asr #16         ; int(y_end)

    subs r1, r9, r7             ; int(y_end) - int(y_start)
    ; Skip horizontal edges.
    beq .2                      ; y_end == y_start?

    ; Store edge 1->2 dda data:
    stmia r12!, {r6, r7, r9}    ; [xs, ys, ye]

    mov r1, r1, asl #16         ; (ye-ys) [16.0]
    ; Compute m = (xe-xs) / (ye-ys) for edge 1->2
    sub r0, r8, r6              ; xs = xe-xs
    mov r6, r8                  ; (index 2 x_start)
    mov r7, r9                  ; (index 2 y_start)
    bl divide                   ; m = (xe-xs) / (ye-ys)

    ; Store edge 1->2 dda data:
    str r0, [r12], #4           ; [m]
    .2:


    mov r0, r3, lsr #24         ; index 3
    add r5, r2, r0, lsl #3      ; projected_verts + index*8
    ldmia r5, {r8, r9}          ; x_end, y_end
    mov r9, r9, asr #16         ; int(y_end)

    subs r1, r9, r7             ; int(y_end) - int(y_start)
    ; Skip horizontal edges.
    beq .3                      ; y_end == y_start?

    ; Store edge 2->3 dda data:
    stmia r12!, {r6, r7, r9}    ; [xs, ys, ye]

    mov r1, r1, asl #16         ; (ye-ys) [16.0]
    ; Compute m = (xe-xs) / (ye-ys) for edge 2->3
    sub r0, r8, r6              ; xs = xe-xs
    mov r6, r8                  ; (index 3 x_start)
    mov r7, r9                  ; (index 3 y_start)
    bl divide                   ; m = (xe-xs) / (ye-ys)

    ; Store edge 2->3 dda data:
    str r0, [r12], #4           ; [m]
    .3:


    and r0, r3, #0xff           ; index 0
    add r5, r2, r0, lsl #3      ; projected_verts + index*8
    ldmia r5, {r8, r9}          ; x_end, y_end
    mov r9, r9, asr #16         ; int(y_end)

    subs r1, r9, r7             ; int(y_end) - int(y_start)
    ; Skip horizontal edges.
    beq .4                      ; y_end == y_start?

    ; Store edge 3->0 dda data:
    stmia r12!, {r6, r7, r9}    ; [xs, ys, ye]

    ; Compute m = (xe-xs) / (ye-ys) for edge 3->0
    sub r0, r8, r6              ; xs = xe-xs
    bl divide                   ; m = (xe-xs) / (ye-ys)

    ; Store edge 3->0 dda data:
    str r0, [r12], #4           ; [m]
    .4:

    ldr pc, [sp], #4


; R12=ptr to edge_dda_table [xs, m, ys, ye]
polygon_rasterise_edge:
    ldmia r12, {r3-r6}          ; [xs, ys, ye, m]

    ; Record lowest y value.
    ldr r0, polygon_min_y
    cmp r4, r0
    strlt r4, polygon_min_y

    adr r11, polygon_span_table
.1:
    ; Clip to screen.
    ; Off top of screen? (y<0)
    cmp r4, #0
    bmi .2                      ; skip line.
    ; Off bottom of screen? (y>=height)
    cmp r4, #Screen_Height
    bge .3                      ; nothing else to do.

    ldr r0, [r11, r4, lsl #2]   ; span[y]
    mov r0, r0, lsl #16         ; can only have two values for convex polys.

    ; Clip to screen.
    mov r2, r3
    ; Off left hand side? (x<0)
    cmp r3, #0
    movmi r2, #0                ; clamp left.
    ; Off right hand side? (x>=width)
    cmp r3, #Screen_Width<<PRECISION_BITS
    ldrge r2, .4                ; clamp right.

    orr r0, r0, r3, lsr #16     ; mask in integer portion.
    str r0, [r11, r4, lsl #2]   ; span[y]

    ; Next scanline.
.2:
    add r3, r3, r6              ; x+=m
    add r4, r4, #1              ; y++
    cmp r4, r5                  ; y < ye
    blt .1
.3:

    ; Record highest y value.
    ldr r0, polygon_max_y
    cmp r4, r0
    strlt r4, polygon_max_y
    mov pc, lr

.4:
    FLOAT_TO_FP Screen_Width-1  ; clamp X to this value.


; TODO: polygon_plot!


; Blat the spans from the table to the screen.
; Params:
;  R9 = colour word.
polygon_plot_spans:
    str lr, [sp, #-4]!
    ldr r11, screen_addr
    ldr r5, polygon_max_y
    cmp r5, #0
    bmi .3                      ; nothing to do.

    adr r6, gen_code_pointers
    adr r7, polygon_span_table

    ldr r8, polygon_min_y       ; y
.1:
    ldr r0, [r7, r8, lsl #2]    ; packed span [x1, x2] for scanline y
    mov r1, r0, lsr #16         ; x2
    mov r0, r0, lsl #16
    mov r0, r0, lsr #16         ; x1

    ; Ensure x1 < x2
    cmp r0, r1
    movgt r2, r0
    movgt r0, r1
    movgt r1, r2

    sub r3, r1, r0              ; length of span
    subs r3, r3, #1             ; omit last pixel for polygon plot.
    bmi .2                      ; skip if no pixels.

    and r4, r0, #7              ; x start offset [0-7] pixel
    add r4, r4, r3, lsl #8      ; + span length * 8
    adr lr, .2                  ; return here.
    ldr pc, [r6, r4, lsl #2]    ; jump to plot function.

    .2:
    add r8, r8, #1
    cmp r8, r5
    blt .1

    ; Reset polygon min/max y.
    mov r0, #-1
    str r0, polygon_max_y
    mov r0, #256
    str r0, polygon_min_y

.3:
    ldr pc, [sp], #4


polygon_min_y:
    .long 256

polygon_max_y:
    .long -1

polygon_span_table:
    .skip Screen_Height * 4     ; per scanline.
