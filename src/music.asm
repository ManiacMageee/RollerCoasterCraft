; =============================================================================
; music.asm - chiptune arrangements of classical pieces (public domain)
;
;   0  Mozart   - Eine kleine Nachtmusik, K.525 (I. Allegro)      title / day
;   1  Vivaldi  - The Four Seasons: Spring (I. Allegro)           day
;   2  Mozart   - Rondo alla Turca, K.331                         day
;   3  Chopin   - Nocturne in E-flat major, Op.9 No.2             night
;   4  Debussy  - Clair de Lune                                   night
;
; Each song: dd samples per tick (tick = one 16th note)
;            3 x (db volume, decay, sustain, duty)   melody, harmony, bass
;            3 x dd track offset
; Track events: db note, length   (note 0 = rest)
;               db 0xFE, volume   (dynamics change)
;               db 0xFF           (end -> loop)
; =============================================================================

; ---- note names: C4 = middle C = MIDI 60, sharps "s", flats "b"
%assign o 0
%rep 8
C%[o]  equ (o+1)*12+0
Cs%[o] equ (o+1)*12+1
Db%[o] equ (o+1)*12+1
D%[o]  equ (o+1)*12+2
Ds%[o] equ (o+1)*12+3
Eb%[o] equ (o+1)*12+3
E%[o]  equ (o+1)*12+4
F%[o]  equ (o+1)*12+5
Fs%[o] equ (o+1)*12+6
Gb%[o] equ (o+1)*12+6
G%[o]  equ (o+1)*12+7
Gs%[o] equ (o+1)*12+8
Ab%[o] equ (o+1)*12+8
A%[o]  equ (o+1)*12+9
As%[o] equ (o+1)*12+10
Bb%[o] equ (o+1)*12+10
B%[o]  equ (o+1)*12+11
%assign o o+1
%endrep
R   equ 0
; lengths in 16th notes
S   equ 1
E   equ 2
ED  equ 3
Q   equ 4
QD  equ 6
H   equ 8
HD  equ 12
W   equ 16

%define TICK(bpm) (22050*60/((bpm)*4))
%macro VOL 1
    db 0xFE, %1
%endmacro
%macro END_TRACK 0
    db 0xFF
%endmacro
; staccato repeated bass eighths: note for a 16th, rest for a 16th
%macro BASS8 2                      ; note, count
%rep %2
    db %1,S, R,S
%endrep
%endmacro
; left hand nocturne figure: rest, chord tone 1, chord tone 2 (eighths)
%macro LH 2
    db R,E, %1,E, %2,E
%endmacro

section .data
song_table  dq song_mozart, song_spring, song_turca, song_nocturne, song_clair
mode_playlists dq pl_none, pl_title, pl_day, pl_night
pl_none     db 1, 0
pl_title    db 1, 0
pl_day      db 3, 1, 2, 0
pl_night    db 2, 3, 4

; =============================================================================
song_mozart:
    dd TICK(132)
    db 11, 2, 7, 1                  ; melody: 25% pulse
    db 7, 2, 4, 0                   ; harmony: 12.5% pulse
    db 15, 0, 15, 0                 ; bass: triangle
    dd .m - song_mozart, .h - song_mozart, .b - song_mozart
.m:
    db G4,Q, R,E, D4,E, G4,Q, R,E, D4,E
    db G4,E, D4,E, G4,E, B4,E, D5,H
    db C5,Q, R,E, A4,E, C5,Q, R,E, A4,E
    db C5,E, A4,E, Fs4,E, A4,E, D4,H
    db D5,Q, G5,Q, Fs5,E, E5,E, D5,E, C5,E
    db B4,Q, D5,Q, A4,H
    db G4,E, B4,E, D5,E, G5,E, Fs5,E, A5,E, D5,Q
    db G5,Q, D5,Q, G4,H
    END_TRACK
.h:
    db G3,Q, R,E, D3,E, G3,Q, R,E, D3,E
    db G3,E, D3,E, G3,E, B3,E, D4,H
    db C4,Q, R,E, A3,E, C4,Q, R,E, A3,E
    db C4,E, A3,E, Fs3,E, A3,E, D3,H
    db B4,Q, D5,Q, D5,E, C5,E, B4,E, A4,E
    db G4,Q, B4,Q, Fs4,H
    db D4,E, G4,E, B4,E, D5,E, D5,E, Fs5,E, A4,Q
    db B4,Q, A4,Q, B3,H
    END_TRACK
.b:
    db G2,H, G2,H
    db G2,H, G2,H
    db D3,H, D3,H
    db D3,H, D2,H
    db B2,H, C3,H
    db D3,H, D2,H
    db G2,H, D3,H
    db G2,Q, D2,Q, G2,H
    END_TRACK

; =============================================================================
song_spring:
    dd TICK(100)
    db 11, 1, 8, 2                  ; melody: 50% pulse
    db 8, 1, 5, 1                   ; harmony: 25% pulse
    db 15, 0, 15, 0
    dd .m - song_spring, .h - song_spring, .b - song_spring
.m:
    VOL 11
    db E5,E
    db Gs5,E, Gs5,E, Gs5,E, Fs5,S, E5,S, B5,QD, B5,S, A5,S
    db Gs5,E, Gs5,E, Gs5,E, Fs5,S, E5,S, B5,QD, B5,S, A5,S
    db Gs5,E, A5,E, B5,E, A5,E, Gs5,E, Fs5,E, Ds5,E, B4,E
    db E5,Q, B4,Q, E5,Q, R,E, E5,E
    VOL 6                           ; the echo, softly
    db Gs5,E, Gs5,E, Gs5,E, Fs5,S, E5,S, B5,QD, B5,S, A5,S
    db Gs5,E, Gs5,E, Gs5,E, Fs5,S, E5,S, B5,QD, B5,S, A5,S
    db Gs5,E, A5,E, B5,E, A5,E, Gs5,E, Fs5,E, Ds5,E, B4,E
    db E5,Q, B4,Q, E5,Q, R,ED
    END_TRACK
.h:
    VOL 8
    db B4,E
    db E5,E, E5,E, E5,E, Ds5,S, Cs5,S, Gs5,QD, Gs5,S, Fs5,S
    db E5,E, E5,E, E5,E, Ds5,S, Cs5,S, Gs5,QD, Gs5,S, Fs5,S
    db E5,E, Fs5,E, Gs5,E, Fs5,E, E5,E, Ds5,E, B4,E, Gs4,E
    db B4,Q, Gs4,Q, B4,Q, R,E, B4,E
    VOL 4
    db E5,E, E5,E, E5,E, Ds5,S, Cs5,S, Gs5,QD, Gs5,S, Fs5,S
    db E5,E, E5,E, E5,E, Ds5,S, Cs5,S, Gs5,QD, Gs5,S, Fs5,S
    db E5,E, Fs5,E, Gs5,E, Fs5,E, E5,E, Ds5,E, B4,E, Gs4,E
    db Gs4,Q, Gs4,Q, B4,Q, R,ED
    END_TRACK
.b:
    db R,E
    BASS8 E3, 8
    BASS8 E3, 8
    BASS8 E3, 4
    BASS8 B2, 4
    BASS8 E3, 2
    BASS8 B2, 2
    db E3,Q, R,Q
    BASS8 E3, 8
    BASS8 E3, 8
    BASS8 E3, 4
    BASS8 B2, 4
    db E3,Q, B2,Q, E2,Q, R,ED
    END_TRACK

; =============================================================================
song_turca:
    dd TICK(120)
    db 11, 2, 6, 1
    db 6, 2, 3, 0
    db 15, 0, 15, 0
    dd .m - song_turca, .h - song_turca, .b - song_turca
.m:
    db B4,S, A4,S, Gs4,S, A4,S
    db C5,E, R,E, D5,S, C5,S, B4,S, C5,S
    db E5,E, R,E, F5,S, E5,S, Ds5,S, E5,S
    db B5,S, A5,S, Gs5,S, A5,S, B5,S, A5,S, Gs5,S, A5,S
    db C6,Q, A5,E, C6,E
    db B5,E, A5,E, G5,E, A5,E
    db B5,E, A5,E, G5,E, A5,E
    db B5,E, A5,E, G5,E, Fs5,E
    db E5,Q, R,Q
    END_TRACK
.h:
    db R,Q
    db R,E, A4,E, R,E, C5,E
    db R,E, A4,E, R,E, C5,E
    db R,E, Gs4,E, R,E, B4,E
    db R,E, A4,E, R,E, C5,E
    db R,E, G4,E, R,E, B4,E
    db R,E, G4,E, R,E, C5,E
    db R,E, Fs4,E, R,E, A4,E
    db R,E, Gs4,E, R,Q
    END_TRACK
.b:
    db R,Q
    db A2,E, R,E, E3,E, R,E
    db A2,E, R,E, E3,E, R,E
    db E2,E, R,E, B2,E, R,E
    db A2,E, R,E, E3,E, R,E
    db E2,E, R,E, B2,E, R,E
    db C3,E, R,E, G2,E, R,E
    db B2,E, R,E, Fs2,E, R,E
    db E2,Q, R,Q
    END_TRACK

; =============================================================================
song_nocturne:
    dd TICK(66)                     ; 12/8, gently
    db 10, 1, 6, 1
    db 5, 1, 3, 0
    db 13, 0, 13, 0
    dd .m - song_nocturne, .h - song_nocturne, .b - song_nocturne
.m:
    db Bb4,E
    db G5,H, F5,E, G5,E, F5,QD, Eb5,Q, Bb4,E
    db G5,Q, C5,E, C6,Q, G5,E, Bb5,QD, Ab5,Q, G5,E
    db F5,QD, G5,E, D5,Q, Eb5,QD, C5,Q, Bb4,E
    db Bb4,E, D5,E, Eb5,E, F5,E, G5,E, Ab5,E, G5,Q, F5,E, Eb5,Q
    END_TRACK
.h:
    db R,E
    LH G4,Bb4
    LH G4,Bb4
    LH G4,Bb4
    LH G4,Bb4
    LH G4,C5
    LH G4,C5
    LH Ab4,C5
    LH Ab4,C5
    LH F4,Ab4
    LH F4,Ab4
    LH G4,Bb4
    LH F4,Ab4
    LH F4,Ab4
    LH F4,Ab4
    LH G4,Bb4
    db R,E, G4,E
    END_TRACK
.b:
    db R,E
    db Eb3,QD, Bb2,QD, Eb3,QD, Bb2,QD
    db C3,QD, G2,QD, Ab2,QD, Eb2,QD
    db Bb2,QD, F2,QD, Eb3,QD, Bb2,QD
    db Bb2,QD, F2,QD, Eb3,QD, Eb2,Q
    END_TRACK

; =============================================================================
song_clair:
    dd TICK(50)                     ; 9/8, very slow and soft
    db 9, 1, 7, 1
    db 6, 1, 4, 0
    db 12, 0, 12, 0
    dd .m - song_clair, .h - song_clair, .b - song_clair
.m:
    db R,Q, F5,14
    db F5,E, Eb5,Q, F5,E, Eb5,E, Db5,H
    db Eb5,E, Db5,Q, Eb5,E, Db5,E, C5,H
    db Db5,E, C5,Q, Db5,E, C5,E, Bb4,H
    db C5,E, Bb4,Q, C5,E, Bb4,E, Ab4,H
    db Bb4,Q, Ab4,Q, Gb4,Q, F4,QD
    db Ab4,QD, Db5,QD, F5,QD
    db Ab5,18
    END_TRACK
.h:
    db R,Q, Db5,14
    db Db5,E, C5,Q, Db5,E, C5,E, Bb4,H
    db C5,E, Bb4,Q, C5,E, Bb4,E, Ab4,H
    db Bb4,E, Ab4,Q, Bb4,E, Ab4,E, Gb4,H
    db Ab4,E, Gb4,Q, Ab4,E, Gb4,E, F4,H
    db Gb4,Q, F4,Q, Eb4,Q, Db4,QD
    db F4,QD, Ab4,QD, Db5,QD
    db F5,18
    END_TRACK
.b:
    db Db3,18
    db Db3,18
    db Ab2,18
    db Gb2,18
    db F2,18
    db Eb2,18
    db Ab2,18
    db Db2,18
    END_TRACK
