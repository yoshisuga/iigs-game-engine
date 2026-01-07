; Dialog System
;
; State-based dialog display that pauses game execution
; Usage:
;   1. Set DialogMessagePtr to point to your message string
;   2. Set DialogState to 1
;   3. Main loop will call ShowDialog which enters its own loop
;   4. Dialog dismisses on A button press

; Dialog box dimensions and position
DIALOG_X        equ 20
DIALOG_Y        equ 40
DIALOG_WIDTH    equ 140
DIALOG_HEIGHT   equ 60

; Dialog box colors (palette indices)
DIALOG_BG_COLOR     equ $3333    ; Black (palette index 3, repeated for 4 pixels)
DIALOG_BORDER_COLOR equ $FFFF    ; White (palette index 15, repeated - adjust as needed)

; Dialog state
DialogState         ds  2    ; 0 = no dialog, 1 = show dialog
DialogMessagePtr    ds  4    ; 32-bit pointer to message string (or array of strings)
DialogLineCount     ds  2    ; Number of lines to draw (1-4)

; Initialize dialog system
InitDialog
            stz   DialogState
            stz   DialogMessagePtr
            stz   DialogMessagePtr+2
            rts

; Check if dialog should be shown and handle it
; Call this from main game loop after _GTERender
CheckAndShowDialog
            lda   DialogState
            beq   :no_dialog

            jsr   ShowDialog         ; Enter dialog loop (game pauses here)

            ; Clear state when dialog closes
            stz   DialogState

:no_dialog
            rts

; Show dialog and wait for dismiss
; This enters its own loop and doesn't return until player presses A
ShowDialog
            ; Draw dialog box
            jsr   DrawDialogBox

            ; Draw message text
            jsr   DrawDialogText

:wait_for_input
            pha                      ; Space for result
            _GTEReadControl
            pla

            bit   #PAD_BUTTON_A      ; Check A button
            beq   :wait_for_input    ; Loop until A pressed

            ; Optional: Small delay for button debounce
            rts

; Draw dialog box background and border
; Black background with white border
DrawDialogBox
            ; Calculate starting position in bytes
            ; X byte offset = DIALOG_X / 2 (2 pixels per byte in 320 mode)
            ; Y offset = DIALOG_Y * 160

            lda   #DIALOG_Y
            sta   Tmp0

            ; Multiply Y by 160 (bytes per line)
            ; 160 = 128 + 32 = (Y << 7) + (Y << 5)
            lda   Tmp0
            asl   a                   ; × 2
            asl   a                   ; × 4
            asl   a                   ; × 8
            asl   a                   ; × 16
            asl   a                   ; × 32
            sta   Tmp1                ; Save × 32
            asl   a                   ; × 64
            asl   a                   ; × 128
            clc
            adc   Tmp1                ; × 128 + × 32 = × 160

            ; Add X byte offset
            clc
            adc   #DIALOG_X/2
            tax                       ; X = screen offset

            ; Draw top border (white line)
            ldy   #DIALOG_WIDTH/2     ; Width in bytes
:top_border
            lda   #DIALOG_BORDER_COLOR
            stal  $E12000,x
            inx
            inx
            dey
            bne   :top_border

            ; Draw middle rows (HEIGHT - 2 lines for borders)
            lda   #DIALOG_HEIGHT-2
            sta   Tmp2                ; Row counter

:next_row
            ; Calculate start of this row
            lda   #DIALOG_Y
            clc
            adc   #DIALOG_HEIGHT
            sec
            sbc   Tmp2                ; Current Y position
            sta   Tmp0

            ; Multiply Y by 160
            lda   Tmp0
            asl   a
            asl   a
            asl   a
            asl   a
            asl   a
            sta   Tmp1
            asl   a
            asl   a
            clc
            adc   Tmp1

            clc
            adc   #DIALOG_X/2
            tax

            ; Draw left border pixel (white)
            lda   #DIALOG_BORDER_COLOR
            stal  $E12000,x
            inx
            inx

            ; Draw middle (black)
            ldy   #DIALOG_WIDTH/2-2    ; Width - 2 border bytes
:middle
            lda   #DIALOG_BG_COLOR
            stal  $E12000,x
            inx
            inx
            dey
            bne   :middle

            ; Draw right border pixel (white)
            lda   #DIALOG_BORDER_COLOR
            stal  $E12000,x

            ; Next row
            dec   Tmp2
            bne   :next_row

            ; Draw bottom border (white line)
            lda   #DIALOG_Y+DIALOG_HEIGHT-1
            sta   Tmp0

            ; Multiply Y by 160
            lda   Tmp0
            asl   a
            asl   a
            asl   a
            asl   a
            asl   a
            sta   Tmp1
            asl   a
            asl   a
            clc
            adc   Tmp1

            clc
            adc   #DIALOG_X/2
            tax

            ldy   #DIALOG_WIDTH/2
:bottom_border
            lda   #DIALOG_BORDER_COLOR
            stal  $E12000,x
            inx
            inx
            dey
            bne   :bottom_border

            rts

; Draw dialog text using font.s
DrawDialogText
            lda   DialogMessagePtr
            beq   :no_message         ; Skip if no message set

            ; Calculate screen position for text
            ; X = Y * 160 + X (for 160 bytes per line)
            lda   #DIALOG_Y
            clc
            adc   #8                  ; 8 pixels from top of box
            sta   Tmp0

            ; Multiply Y by 160
            lda   Tmp0
            sta   Tmp1
            asl   a                   ; × 2
            asl   a                   ; × 4
            asl   a                   ; × 8
            sta   Tmp2
            asl   a                   ; × 16
            asl   a                   ; × 32
            clc
            adc   Tmp2                ; × 32 + × 8 = × 40
            asl   a                   ; × 80
            asl   a                   ; × 160

            ; Add X offset
            clc
            adc   #DIALOG_X
            adc   #8                  ; 8 pixels from left of box
            tax

            ; Load message pointer
            lda   DialogMessagePtr
            ldy   #$FFFF              ; White text color (palette 15 repeated)

            jsr   DrawString

:no_message
            rts

; Trigger dialog with a message
; Input: A = low word of message pointer
;        X = high word of message pointer
TriggerDialog
            sta   DialogMessagePtr
            stx   DialogMessagePtr+2
            lda   #1
            sta   DialogState
            rts

; Quick helper to trigger dialog with a simple message
; Input: A = pointer to message string (assume in same bank)
TriggerDialogSimple
            sta   DialogMessagePtr
            stz   DialogMessagePtr+2    ; Assume same bank
            lda   #1
            sta   DialogState
            rts
