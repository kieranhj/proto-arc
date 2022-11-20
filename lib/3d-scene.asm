; ============================================================================
; 3D Scene.
; ============================================================================

.equ OBJ_MAX_VERTS, 8
.equ OBJ_MAX_FACES, 6
.equ OBJ_VERTS_PER_FACE, 4

; TODO: Think about doubling viewport scale and halving world scale
;       If that makes things easier wrt [8.16] fixed point precision.
;       E.g. [32,32,32] cube would map to [64,64] pixels.
;       Therefore camera would be at -80.0 so far plane would be
;       256-80=176, giving more room to move objects around.

.equ VIEWPORT_SCALE, (Screen_Width/2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_X, (Screen_Width/2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_Y, (Screen_Height/2) * PRECISION_MULTIPLIER

; ============================================================================
; Scene data.
; ============================================================================

camera_pos:
    VECTOR3 0.0, 0.0, -160.0

; Note camera is fixed to view down +z axis.
; TODO: Camera rotation/direction/look at?

object_pos:
    VECTOR3 0.0, 0.0, 64.0

object_rot:
    VECTOR3 0.0, 0.0, 0.0

object_transform:
    MATRIX33_IDENTITY

temp_matrix_1:
    MATRIX33_IDENTITY

temp_matrix_2:
    MATRIX33_IDENTITY

; ============================================================================
; ============================================================================

init_3d_scene:
    str lr, [sp, #-4]!

    adr r2, object_transform
    bl matrix_make_identity

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================

update_3d_scene:
    str lr, [sp, #-4]!
    .if 1
    ; Create rotation matrix as object transform.
    adr r2, temp_matrix_1
    ldr r0, object_rot + 0
    bl matrix_make_rotate_x

    adr r2, object_transform
    ldr r0, object_rot + 4
    bl matrix_make_rotate_y

    adr r0, temp_matrix_1
    adr r1, object_transform
    adr r2, temp_matrix_2
    bl matrix_multiply

    adr r2, temp_matrix_1
    ldr r0, object_rot + 8
    bl matrix_make_rotate_z

    adr r0, temp_matrix_2
    adr r1, temp_matrix_1
    adr r2, object_transform
    bl matrix_multiply
    .else
    ; Updating the rotation matrix in this way resulting in minification.
    ; Presume repeated precision loss during mutiply causing this.
    ; Would need the rotation only matrix multiplication routine here.
    adr r0, object_transform
    adr r1, delta_transform
    adr r2, temp_matrix
    bl matrix_multiply

    adr r0, object_transform
    adr r2, temp_matrix
    ldmia r2!, {r3-r11}
    stmia r0!, {r3-r11}
    .endif

    adr r11, object_pos

    ; Transform vertices in scene.
    adr r0, object_transform
    adr r1, object_verts
    adr r2, transformed_verts
    ldr r10, object_num_verts
    .1:
    ; R0=ptr to matrix, R1=vector A, R2=vector B
    bl matrix_multiply_vector
    ; TODO: Array version of this function.

    ; Add object position here to move into world space!
    ldmia r2, {r3-r5}
    ldmia r11, {r6-r8}
    add r3, r3, r6
    add r4, r4, r7
    add r5, r5, r8
    stmia r2!, {r3-r5}
    
    add r1, r1, #VECTOR3_SIZE
    subs r10, r10, #1
    bne .1

    ; Transform normals.
    adr r0, object_transform
    adr r1, object_face_normals
    adr r2, transformed_normals
    ldr r10, object_num_faces
    .2:
    ; R0=ptr to matrix, R1=vector A, R2=vector B
    bl matrix_multiply_vector
    ; TODO: Array version of this function.
    add r1, r1, #VECTOR3_SIZE
    add r2, r2, #VECTOR3_SIZE
    subs r10, r10, #1
    bne .2

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r0, object_rot+0
    add r0, r0, #MATHS_CONST_HALF
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+0

    ldr r0, object_rot+4
    add r0, r0, #MATHS_CONST_1
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+4

    ldr r0, object_rot+8
    add r0, r0, #MATHS_CONST_QUARTER
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+8

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================

draw_3d_scene:
    str lr, [sp, #-4]!

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

    ; Plot vertices as pixels.
    .if 0
    ldr r12, screen_addr
    adr r3, projected_verts
    ldr r9, object_num_verts
    .2:
    ldmia r3!, {r0, r1}

    ; TODO: Clipping.

    mov r4, #0x07               ; colour.
    bl plot_pixel
    subs r9, r9, #1
    bne .2
    .endif

    ; Plot faces as lines.
    .if 0
    ldr r12, screen_addr
    adr r11, object_face_indices
    adr r10, projected_verts
    adr r6, transformed_normals
    ldr r9, object_num_faces
    mov r4, #0x07               ; colour.
    .2:
    ldrb r5, [r11, #0]          ; vertex0 of polygon.

    adr r1, transformed_verts
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2      ; transformed_verts + index*12
    mov r2, r6                  ; face_normal

    stmfd sp!, {r4, r6}
    bl backface_cull_test       ; (vertex0 - camera_pos).face_normal
    ldmfd sp!, {r4, r6}

    cmp r0, #0
    bpl .3                      ; normal facing away from the view direction.

    ldrb r5, [r11, #0]          ; vertex0 of polygon.
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start

    ldrb r5, [r11, #1]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r2, r3}          ; x_end, y_end

    bl drawline

    ldrb r5, [r11, #1]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start

    ldrb r5, [r11, #2]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r2, r3}          ; x_end, y_end

    bl drawline

    ldrb r5, [r11, #2]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start

    ldrb r5, [r11, #3]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r2, r3}          ; x_end, y_end

    bl drawline

    ldrb r5, [r11, #3]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start

    ldrb r5, [r11, #0]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r2, r3}          ; x_end, y_end

    bl drawline

    .3:
    add r6, r6, #VECTOR3_SIZE
    add r11, r11, #4
    subs r9, r9, #1
    bne .2
    .endif

    ; Plot faces as polys.
    .if 1
    ldr r12, screen_addr
    adr r11, object_face_indices
    adr r10, projected_verts
    adr r6, transformed_normals
    ldr r9, object_num_faces
    mov r4, #0x01               ; colour.
    .2:
    ldrb r5, [r11, #0]          ; vertex0 of polygon.
    
    adr r1, transformed_verts
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2      ; transformed_verts + index*12
    mov r2, r6                  ; face_normal

    stmfd sp!, {r4, r6}
    bl backface_cull_test       ; (vertex0 - camera_pos).face_normal
    ldmfd sp!, {r4, r6}

    cmp r0, #0                  
    bpl .3                      ; normal facing away from the view direction.

    ; Simple directional lighting from -z.
    ldr r4, [r6, #8]            ; face_normal.z
    rsb r4, r4, #0              ; make positive. [0.16]
    mov r4, r4, lsr #12         ; [0.4]
    cmp r4, #0x10
    movge r4, #0x0f             ; clamp to [0-15]

    adr r8, polygon_buffer

    ldrb r5, [r11, #0]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start
    stmia r8!, {r0, r1}

    ldrb r5, [r11, #1]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start
    stmia r8!, {r0, r1}

    ldrb r5, [r11, #2]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start
    stmia r8!, {r0, r1}

    ldrb r5, [r11, #3]
    add r7, r10, r5, lsl #3     ; projected_verts + index*8
    ldmia r7, {r0, r1}          ; x_start, y_start
    stmia r8!, {r0, r1}

    mov r0, #OBJ_VERTS_PER_FACE
    adr r1, polygon_buffer
    stmfd sp!, {r4, r6, r9-r12}
    bl plot_polygon_span
    ldmfd sp!, {r4, r6, r9-r12}

    .3:
    add r6, r6, #VECTOR3_SIZE
    add r4, r4, #1
    add r11, r11, #4
    subs r9, r9, #1
    bne .2
    .endif

    ldr pc, [sp], #4

; Backfacing culling test.
; Parameters:
;  R1=ptr to vector (vertex in world space).
;  R2=ptr to face normal
; Return:
;  R0=dot product of (v0-cp).n
; Trashes: r3-r8
backface_cull_test:
    str lr, [sp, #-4]!

    ldmia r1, {r3-r5}
    ldr r6, camera_pos+0
    ldr r7, camera_pos+4
    ldr r8, camera_pos+8
    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8          ; vertex - camera_pos

    bl vector_dot_product_loaded
    ldr pc, [sp], #4

; Project world position to screen coordinates.
;
; R2=ptr to vector (position in world space).
; Returns:
;  R0=screen x
;  R1=screen y
; Trashes: R3-R10
project_to_screen:
    str lr, [sp, #-4]!

    ldmia r2, {r3-r5}           ; (x,y,z)
    ldr r6, camera_pos
    ldr r7, camera_pos+4
    ldr r8, camera_pos+8

    ; eye_pos = world_pos - camera_pos
    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    ; vp_centre_x + vp_scale * (x-cx) / (z-cz)
    mov r0, r3                  ; (x-cx)
    mov r1, r5                  ; (z-cz)
    bl divide                   ; (x-cx)/(z-cz)
                                ; [0.16]
    mov r7, #VIEWPORT_SCALE>>MULTIPLICATION_SHIFT     ; [16.8]
    mul r6, r0, r7              ; [8.24]        ; overflow?
    mov r6, r6, asr #8          ; [8.16]
    mov r8, #VIEWPORT_CENTRE_X  ; [16.16]
    add r6, r6, r8

    ; vp_centre_y + vp_scale * (y-cy) / (z-cz)
    mov r0, r4                  ; (y-cy)
    mov r1, r5                  ; (z-cz)
    bl divide                   ; (y-cy)/(z-cz)
                                ; [0.16]
    mov r7, #VIEWPORT_SCALE>>MULTIPLICATION_SHIFT     ; [16.8]
    mul r1, r0, r7              ; [8.24]        ; overflow?
    mov r1, r1, asr #8          ; [8.16]
    mov r8, #VIEWPORT_CENTRE_Y  ; [16.16]
    add r1, r1, r8              ; [16.16]

    mov r0, r6
    ldr pc, [sp], #4

; ============================================================================
; Object data: CUBE
;
;         4         5        y
;          +------+          ^  z
;         /      /|          |/
;        /      / |          +--> x
;     0 +------+ 1|
;       | 7 +  |  + 6
;       |      | /
;       |      |/
;       +------+
;      3        2
; ============================================================================

object_num_verts:
    .long 8

object_verts:
    VECTOR3 -64.0,  64.0, -64.0
    VECTOR3  64.0,  64.0, -64.0
    VECTOR3  64.0, -64.0, -64.0
    VECTOR3 -64.0, -64.0, -64.0
    VECTOR3 -64.0,  64.0,  64.0
    VECTOR3  64.0,  64.0,  64.0
    VECTOR3  64.0, -64.0,  64.0
    VECTOR3 -64.0, -64.0,  64.0

object_num_faces:
    .long 6

; Winding order is clockwise (from outside)
object_face_indices:
    .byte 0, 1, 2, 3
    .byte 1, 5, 6, 2
    .byte 5, 4, 7, 6
    .byte 4, 0, 3, 7
    .byte 0, 4, 5, 1
    .byte 2, 3, 7, 6

object_face_normals:
    VECTOR3  0.0,  0.0, -1.0
    VECTOR3  1.0,  0.0,  0.0
    VECTOR3  0.0,  0.0,  1.0
    VECTOR3 -1.0,  0.0,  0.0
    VECTOR3  0.0,  1.0,  0.0
    VECTOR3  0.0  -1.0,  0.0
 
 ;TODO: Object face colours or vertex colours etc.

; ============================================================================
; Scene data.
; ============================================================================

transformed_verts:
    .skip OBJ_MAX_VERTS * VECTOR3_SIZE

transformed_normals:
    .skip OBJ_MAX_FACES * VECTOR3_SIZE

; TODO: Decide on how to store these, maybe packed or separate array?
projected_verts:
    .skip OBJ_MAX_VERTS * 2 * 4

polygon_buffer:
    .skip OBJ_VERTS_PER_FACE * 2 * 4
