; ============================================================================
; 3D Scene.
; ============================================================================

.equ OBJ_MAX_VERTS, 8
.equ OBJ_MAX_FACES, 6
.equ OBJ_VERTS_PER_FACE, 4

.equ VIEWPORT_SCALE, (Screen_Width/2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_X, (Screen_Width/2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_Y, (Screen_Height/2) * PRECISION_MULTIPLIER

init_3d_scene:
    ; TODO: Anything here?
    mov pc, lr

update_3d_scene:
    str lr, [sp, #-4]!
    ; Create rotation matrix as object transform.
    adr r2, object_transform
    ldr r0, object_rot              ; TODO: Properly!
    bl matrix_make_rotate_y

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

    ; TODO: Transform normals.

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r0, object_rot
    add r0, r0, #MATHS_CONST_1
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot
    ldr pc, [sp], #4

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
    stmia r12!, {r0, r1}
    add r2, r2, #VECTOR3_SIZE
    subs r11, r11, #1
    bne .1

    ; Plot verices as pixels.
    ldr r12, screen_addr
    adr r3, projected_verts
    ldr r9, object_num_verts
    .2:
    ldmia r3!, {r0, r1}
    mov r0, r0, asr #16
    mov r1, r1, asr #16

    ; TODO: Clipping.

    mov r4, #0x07               ; colour.
    bl plot_pixel

    subs r9, r9, #1
    bne .2

    ldr pc, [sp], #4

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
    mul r1, r0, r2              ; [8.24]        ; overflow?
    mov r1, r1, asr #8          ; [8.16]
    mov r8, #VIEWPORT_CENTRE_Y  ; [16.16]
    add r1, r1, r8              ; [16.16]

    mov r0, r6
    ldr pc, [sp], #4

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

; TODO: Decide on how to store these, maybe packed or separate array?
projected_verts:
    .skip OBJ_MAX_VERTS * 2 * 4
