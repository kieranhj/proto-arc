; ============================================================================
; Rocket sync
; ============================================================================

.equ Pattern_Max, 23                ; TODO: automate from MOD file.
.equ Tracks_Max, 5                  ; TODO: automate from tracks_list file.

rocket_sync_time:
	.long 0

audio_is_playing:
	.long 0

.if _SYNC_EDITOR

podule3_base:
    .long 0x300C000

podule3_audio_is_playing:
    .long 0x300FFFC

podule3_vsync_count:
    .long 0x300FFF8

; All initialisation done by the Podule in Editor mode.
rocket_init:
    mov pc, lr

; Start in Editor mode.
rocket_start:
	str lr, [sp, #-4]!			; push lr on stack
    mov r0, #0
    bl rocket_set_audio_playing ; pause playback
    ldr pc, [sp], #4

; R0 = vsync delta since last update
rocket_update:
	str lr, [sp, #-4]!			; push lr on stack
    mov r10, r0
	bl rocket_get_audio_is_playing
	ldr r1, audio_is_playing
	cmp r1, r0
	beq .5
	; toggle audio state
	cmp r0, #0
    .if _ENABLE_MUSIC
	swieq QTM_Pause			    ; pause
    .endif
	beq .5
	; vsync_to_row
	ldr r0, rocket_sync_time
	bl rocket_sync_time_to_music_pos
    .if _ENABLE_MUSIC
	swi QTM_Pos
	swi QTM_Start			    ; play
    .endif
	mov r0, #1
	.5:
	str r0, audio_is_playing
	cmp r0, #0
	beq .3
	; If audio is playing then we need to drive the vsync counter
	ldr r0, rocket_sync_time
	add r0, r0, r10
	str r0, rocket_sync_time
	bl rocket_set_sync_time
	b .4
	.3:
	; Otherwise we obtain the vsync counter from the editor.
	bl rocket_get_sync_time
	str r0, rocket_sync_time
	; Still set the Tracker pos for debug
	bl rocket_sync_time_to_music_pos
    .if _ENABLE_MUSIC
	swi QTM_Pos
    .endif
	.4:
    ldr pc, [sp], #4

; R0 = track no.
; Returns R1 = 16.16 value
; Trashes R2, R3
rocket_sync_get_val:
    ldr r2, podule3_base
    ldr r1, [r2, r0, lsl #3]        ; r3 = podule3_base[track_no * 8]
    add r2, r2, #4
    ldr r3, [r2, r0, lsl #3]        ; r1 = podule3_base[track_no * 8 + 4]
    orr r1, r1, r3, lsl #16         ; val = r3 << 16 | r1
    mov pc, lr

; R0 = track no.
; Returns R1 = integer part only
; Trashes R2
rocket_sync_get_val_hi:
    ldr r2, podule3_base
    add r2, r2, #4
    ldr r1, [r2, r0, lsl #3]        ; r1 = podule3_base[track_no * 8 + 4]
    mov pc, lr

; R0 = track no.
; Returns R1 = fractional part only
; Trashes R2
rocket_sync_get_val_lo:
    ldr r2, podule3_base
    ldr r1, [r2, r0, lsl #3]        ; r1 = podule3_base[track_no * 8]
    mov pc, lr

rocket_get_audio_is_playing:
    ldr r2, podule3_audio_is_playing
    ldr r0, [r2]
    mov pc, lr

; R0 = audio off (0) on (otherwise)
rocket_set_audio_playing:
    ldr r2, podule3_audio_is_playing
    mov r1, r0, lsl #16             ; podule write to upper 16 bits
    str r1, [r2]
    mov pc, lr

rocket_get_sync_time:
    ldr r2, podule3_vsync_count
    ldr r0, [r2]
    mov pc, lr

rocket_set_sync_time:
    ldr r2, podule3_vsync_count
    mov r1, r0, lsl #16             ; podule write to upper 16 bits
    str r1, [r2]
    mov pc, lr

; R0 = sync time (vsync count)
; Returns R0 = pattern, R1 = line
; Trashes R2, R3
rocket_sync_time_to_music_pos:
	mov r1, r0, lsr #2		; row = vsyncs / vpr; fixed speed = 4

; If all patterns are length 64 can just do this:
;	mov r0, r1, lsr #6		; pattern = row DIV 64
;	and r1, r1, #63			; line = row MOD 64

    adr r2, rocket_music_pattern_lengths
    mov r0, #0
    .1:
    ldr r3, [r2, r0, lsl #3]
    cmp r3, r1
    bge .2
    add r0, r0, #1
    b .1
    .2:

    ; R0 = pattern
    subgt r0, r0, #1

    ; clamp to end of song.
    cmp r0, #Pattern_Max
    movge r0, #Pattern_Max-1
    movge r1, #63
    movge pc, lr

    sub r1, r1, r3          ; remove pattern start
    add r2, r2, r0, lsl #3
    ldr r3, [r2, #4]
    and r1, r1, r3          ; line in pattern
    mov pc, lr

.macro pat_len start, len
    .long \start
    .long \len-1
    .set \start, \start + \len
.endm

; TODO: automate from MOD file.
; BBPD MOD has short (32 line) patterns at 8, 15, 20, 21.
rocket_music_pattern_lengths:
    .set ps, 0
    pat_len ps, 64   ; 0
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 32   ; 8
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 32   ; 15
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 64
    pat_len ps, 32   ; 20
    pat_len ps, 32   ; 21
    pat_len ps, 64   ; 22

.else

; Set up whatever track context is required per track.
rocket_init:
    mov r0, #0
    adr r1, tracks_table
    adr r4, tracks_context
    .1:
    ldr r2, [r1, r0, lsl #2]        ; track_data_offset = tracks_table[i]
    add r2, r2, r1                  ; track_ptr = track_data_offset + tracks_table
    ldr r3, [r2], #4                ; num_keys = *track_ptr++
    str r2, [r4], #4                ; track_context[i].ptr = track_ptr
    sub r3, r3, #1                  ; num_keys--
    add r2, r2, r3, lsl #3          ; track_end = track_ptr + 8 * (num_keys-1)
    str r2, [r4], #4                ; track_context[i].end = track_end
    add r0, r0, #1
    cmp r0, #Tracks_Max
    blt .1
    mov pc, lr

; Start the sync tracker.
rocket_start:
    .if _ENABLE_MUSIC
	swi QTM_Start				    ; start audio playback
    .endif
    mov pc, lr

; R0 = vsync delta since last update.
rocket_update:
	; Sequence can only move forwards when not connected to editor.
	ldr r1, rocket_sync_time
	add r1, r1, r0
	str r1, rocket_sync_time
    mov pc, lr

; R0 = track no.                    ; pass in sync time?
; Returns R1 = 16.16 value
; Trashes R2..R9
rocket_sync_get_val:
    ; get track context
    adr r10, tracks_context
    add r10, r10, r0, lsl #3        ; track_context[i]
    ldmia r10, {r2, r3}             ; r2 = track_ptr; r3 = track_end

    .1:
    ; get current key & next key
    ldmia r2, {r4 - r7}             ; r4 = current key time
                                    ; r5 = current key value
                                    ; r6 = next key time
                                    ; r7 = next key value
    ; if last key then return last value
    cmp r2, r3
    moveq r1, r5
    moveq pc, lr

    ; if sync time < current key time then return first value
    ldr r8, rocket_sync_time        ; or pass this in?
    mov r9, r4, lsr #24             ; r9 = current key type
    bic r4, r4, #0xff000000         ; mask out current key type
    cmp r8, r4
    movlt r1, r5
    movlt pc, lr

    ; if time > next key time then move to next key
    bic r6, r6, #0xff000000         ; mask out next key type
    cmp r8, r6
    addge r2, r2, #8
    strge r2, [r10]
    bge .1

    ; switch key type
    cmp r9, #0
    ; step: return value
    moveq r1, r5
    moveq pc, lr

    ; linear: interpolate value
	; double t = (row - k[0].row) / (k[1].row - k[0].row);
	; return k[0].value + (k[1].value - k[0].value) * t;
    sub r6, r6, r4                  ; (k[1].row - k[0].row) ; const for key
    sub r8, r8, r4                  ; (row - k[0].row)
    adr r3, divisor_table
    ldr r1, [r3, r6, lsl #2]        ; r6 = 1 / (k[1].row - k[0].row) [fp 0.16]  ; const for key
    mul r8, r1, r8                  ; r8 = (row - k[0].row) / (k[1].row - k[0].row) [fp 0.16]
    mov r8, r8, asr #6              ; [fp 0.10]

    sub r7, r7, r5                  ; (k[1].value - k[0].value) [fp 16.16]  ; const for key
    mov r7, r7, asr #6              ; [fp 12.10]
    mul r1, r7, r8                  ; (k[1].value - k[0].value) * t [fp 12.20]
    add r1, r5, r1, asr #4          ; k[0].value + (k[1].value - k[0].value) * t [fp 16.16]
    mov pc, lr

rocket_set_audio_playing:
    cmp r0, #0
    swieq QTM_Pause			    ; pause
    swine QTM_Start             ; play
    mov pc, lr

rocket_sync_get_val_lo:
	str lr, [sp, #-4]!			; push lr on stack
    bl rocket_sync_get_val
    bic r1, r1, #0xff000000
    bic r1, r1, #0x00ff0000
    ldr pc, [sp], #4

rocket_sync_get_val_hi:
	str lr, [sp, #-4]!			; push lr on stack
    bl rocket_sync_get_val
    mov r1, r1, lsr #16
    ldr pc, [sp], #4

tracks_context:
    .skip Tracks_Max * 8        ; track_ptr - ptr to current key
                                ; track_end - ptr to last key

; TODO: automate this from track_list file.
tracks_table:
    .long track_stniccc_stniccc_frame - tracks_table
    .long track_stniccc_show_image - tracks_table
    .long track_stniccc_grey_scale - tracks_table
    .long track_stniccc_fade_to_white - tracks_table
    .long track_stniccc_fade_to_black - tracks_table

track_stniccc_stniccc_frame:
    .incbin "data/rocket/stniccc_stniccc_frame.track"

track_stniccc_show_image:
    .incbin "data/rocket/stniccc_show_image.track"

track_stniccc_grey_scale:
    .incbin "data/rocket/stniccc_grey_scale.track"

track_stniccc_fade_to_white:
    .incbin "data/rocket/stniccc_fade_to_white.track"

track_stniccc_fade_to_black:
    .incbin "data/rocket/stniccc_fade_to_black.track"

; TODO: Use shared divide function.
divisor_table:
    .long 0
    .set div, 1
    .rept 1023
    .set one_over, 65536 / div
    .long one_over
    .set div, div + 1
    .endr

.endif
