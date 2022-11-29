; ============================================================================
; Rubber cube.
; ============================================================================

; WARNING: Code must change if these do!
.equ RUBBER_CUBE_MAX_FRAMES, 256
.equ RUBBER_CUBE_FRAME_SIZE, 4 + 4 + OBJ_MAX_VISIBLE_FACES * 8  ; 32


init_rubber_cube:
    str lr, [sp, #-4]!
    mov r0, #0
    str r0, rubber_cube_frame

    ; Run the update 256 times to prime the frame list.
    .1:
    bl update_rubber_cube

    ; Update the rubber cube frame.
    ldr r0, rubber_cube_frame
    add r0, r0, #1
    ands r0, r0, #0xff           ; assumes RUBBER_CUBE_MAX_FRAMES=256
    str r0, rubber_cube_frame
    bne .1

    ldr pc, [sp], #4


update_rubber_cube:
    str lr, [sp, #-4]!

    ; Rotate the object, transform verts & normals, update scene vars.
    bl update_3d_scene

    ; Project vertices to screen.
    adr r2, transformed_verts
    ldr r11, object_num_verts
    adr r12, projected_verts
    .1:
    ; R2=ptr to world pos vector
    bl project_to_screen
    ; R0=screen_x, R1=screen_y [16.16]
    mov r0, r0, asr #16         ; [16.0]
    mov r1, r1, asr #16         ; [16.0]
    stmia r12!, {r0, r1}
    add r2, r2, #VECTOR3_SIZE
    subs r11, r11, #1
    bne .1

    ; Determine visible faces.
    mov r11, #0                 ; face_index
    ldr r9, object_num_faces    ;
    mov r6, #0                  ; visible faces

    ; R12 = ptr to edge list buffer for frame.
    ldr r0, rubber_cube_frame
    adr r12, rubber_cube_edge_list
    add r12, r12, r0, lsl #7    ; edge_list + frame * 128
    add r12, r12, r0, lsl #6    ;           + frame * 64  = &edge_list[frame]
    
    ; R10 = ptr to rubber cube frame.
    adr r10, rubber_cube_frame_list
    add r10, r10, r0, lsl #5    ; frame_ptr = frame_list + frame * 32
    str r6, [r10], #4           ; needs updating to visible faces.

    .2:

    adr r5, object_face_indices
    ldrb r5, [r5, r11, lsl #2]  ; vertex0_index=object_face_indices[face_index][0]

    adr r1, transformed_verts
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2      ; transformed_verts + vertex0_index*12

    adr r2, transformed_normals
    add r2, r2, r11, lsl #3
    add r2, r2, r11, lsl #2     ; face_normal + face_index*12

    bl backface_cull_test       ; (vertex0 - camera_pos).face_normal

    cmp r0, #0                  
    bpl .3                      ; normal facing away from the view direction.

    adr r2, projected_verts     ; projected vertex array.
    adr r5, object_face_indices
    ldr r3, [r5, r11, lsl #2]   ; quad indices = object_face_indices[face_index]

    stmfd sp!, {r6, r9-r11}
    ; Convert polygon indices to an edge list.
    ; R12 = updated ptr to edge list for frame [xs, m, ys, ye]
    bl polygon_quad_to_edge_list    ; Trashes: r0-r1, r4-r10
    mov r0, r11                 ; R11=number of edges.
    ldmfd sp!, {r6, r9-r11}

    ; Write number of edges into rubber frame face list.
    str r0, [r10], #4

    ; Write face colour into rubber frame face list.
    add r0, r11, #1             ; colour index = face index+1

    ; Convert colour index to colour word.
    orr r0, r0, r0, lsl #4
    orr r0, r0, r0, lsl #8
    orr r0, r0, r0, lsl #16

    str r0, [r10], #4           ; colour_word

    add r6, r6, #1              ; visible_faces++

    .3:
    add r11, r11, #1            ; face_index++
    cmp r11, r9
    blt .2

    ; Write number of visible faces for rubber frame.
    ldr r0, rubber_cube_frame
    ; R10 = ptr to rubber cube frame.
    adr r10, rubber_cube_frame_list
    add r10, r10, r0, lsl #5    ; frame_list + frame * 32
    str r6, [r10]               ; write number of visible faces.

    ldr pc, [sp], #4


; R11 = screen address
draw_rubber_cube:
    str lr, [sp, #-4]!

    ; For each scanline Y.
    mov r8, #0
    .1:

    ; Determine historical frame to use for this line.
    ldr r0, rubber_cube_frame   ; start simple = frame - Y
    sub r0, r0, r8
    and r0, r0, #0xff

    ; Locate ptr to edges for this frame.
    adr r12, rubber_cube_edge_list
    add r12, r12, r0, lsl #7    ; edge_list + frame * 128
    add r12, r12, r0, lsl #6    ;           + frame * 64  = &edge_list[frame]

    ; Locate ptr to frame data.
    adr r7, rubber_cube_frame_list
    add r7, r7, r0, lsl #5      ; frame_ptr = frame_list + frame * 32
    ldr r0, [r7], #4            ; visible faces

    cmp r0, #0
    beq .5                      ; no faces

    ; TODO: Store min/max y for face to eliminate this without the edge loop.

    ; For each visible face in the frame.
    .2:

    ; Get number of edges and face colour word.
    ldmia r7!, {r2, r9}

    mov r1, #0                  ; track (xs,xe) span.

    ; For each edge in the visible face.
    .3:
    ; Get edge vars.
    ldmia r12!, {r3-r6}         ; [xs, ys, ye, m]

    ;   Determine edges such that ys <= Y <= ye
    cmp r8, r4
    blt .4
    cmp r8, r5
    bge .4

    ;     Compute x = xs + m * (y - ys)
    sub r4, r8, r4              ; y-ys       [8.0]
    mul r4, r6, r4              ; (y-ys) * m [8.0] * [8.16] = [16.16]
    add r3, r3, r4              ; x = xs + m * (y - ys) [16.16]

    ; Clip span
    cmp r3, #0                  ; off left hand side of screen? (x<0)
    movlt r3, #0                ; clamp left.
    cmp r3, #Screen_Width<<PRECISION_BITS   ; off right hand side?
    ldrgt r3, polygon_clip_right_side       ; clamp right

    ; Keep track of span (xs, xe)
    mov r1, r1, lsl #16             ; shift x value to upper 16 bits.
    orr r1, r1, r3, lsr #16         ; mask integer portion into lower bits.

    ; TODO: Terminate after two matching edges in the face?

    ; Next edge.
    .4:
    subs r2,r2, #1
    bne .3

    ;     Plot span for face.

    ; Unpack [x1, x2] into separate registers.
    mov r2, r1, lsr #16         ; xs
    mov r1, r1, lsl #16
    mov r1, r1, lsr #16         ; xe

    cmp r1, r2                  ; if xe < xs?
    eorlt r1, r1, r2            ;
    eorlt r2, r1, r2            ;
    eorlt r1, r1, r2            ; swap x1, x2

    sub r1, r1, #1              ; omit last pixel for polygon plot.
    subs r3, r1, r2             ; length of span
    bmi .6                      ; skip if no pixels.

	mov r4, r2, lsr #3          ; xs DIV 8
	add r10, r11, r4, lsl #2    ; ptr to start word

    and r4, r2, #7              ; x start offset [0-7] pixel
    add r4, r4, r3, lsl #3      ; + span length * 8
    adr lr, .6                  ; link address.
	ldr r6, gen_code_pointers_p
    ; Uses: r1, r3, ,r6, r10, r11.
    ; Preserve: r0 (num faces), r7 (face list), r12 (edge list), r8 (y)
    ldr pc, [r6, r4, lsl #2]    ; jump to plot function.

    .6:

    ; Next face.
    subs r0, r0, #1
    bne .2

    .5:
    ; Next scanline Y.
    add r11, r11, #Screen_Stride
    add r8, r8, #1
    cmp r8, #Screen_Height
    blt .1

    ; Update the rubber cube frame.
    ldr r0, rubber_cube_frame
    add r0, r0, #1
    ands r0, r0, #0xff           ; assumes RUBBER_CUBE_MAX_FRAMES=256
    str r0, rubber_cube_frame

    ldr pc, [sp], #4


rubber_cube_frame:
    .long 0


; For each frame:               [MAX_FRAMES]
;  long number_of_faces         (4)
;  For each face:               [MAX_VISIBLE_FACES]
;   long number_of_edges         (4)    <= could be packed.
;   long face_colour             (4)
; 32 bytes.

rubber_cube_frame_list:
    .skip RUBBER_CUBE_MAX_FRAMES * RUBBER_CUBE_FRAME_SIZE

; WARNING: Code must change if these do!
; Actually doesn't need to be a circular buffer, we preallocate the max
; size per frame, so edge_size * max_edges * max_faces = 192.
rubber_cube_edge_list:
    .skip POLYGON_EDGE_SIZE * OBJ_MAX_EDGES_PER_FACE * OBJ_MAX_VISIBLE_FACES * RUBBER_CUBE_MAX_FRAMES
    ; 16 * 4 * 3 * 256 = 192 * 256
