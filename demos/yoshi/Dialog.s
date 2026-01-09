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

; Dialog queue constants
MAX_DIALOG_QUEUE    equ 8        ; Maximum number of queued dialogs

; Dialog state
DialogState         ds  2    ; 0 = no dialog, 1 = show dialog
DialogMessagePtr    ds  4    ; 32-bit pointer to message string (or array of strings)
DialogLineCount     ds  2    ; Number of lines to draw (1-4)

; Dialog queue
DialogQueueMsgPtr   ds  MAX_DIALOG_QUEUE*4   ; Array of message pointers
DialogQueueLineCount ds MAX_DIALOG_QUEUE*2   ; Array of line counts
DialogQueueHead     ds  2    ; Queue head index (next to dequeue)
DialogQueueTail     ds  2    ; Queue tail index (next to enqueue)
DialogQueueCount    ds  2    ; Number of items in queue

; Initialize dialog system
InitDialog
            stz   DialogState
            stz   DialogMessagePtr
            stz   DialogMessagePtr+2
            stz   DialogLineCount
            stz   DialogQueueHead
            stz   DialogQueueTail
            stz   DialogQueueCount
            rts

; Check if dialog should be shown and handle it
; Call this from main game loop after _GTERender
CheckAndShowDialog
            lda   DialogState
            beq   :no_dialog

            jsr   ShowDialog         ; Enter dialog loop (game pauses here)

            ; Dialog was dismissed - check if there's another in queue
            jsr   DequeueDialog      ; Try to load next dialog from queue
            bcs   :no_dialog         ; Carry set = queue empty

            ; There was another dialog - it's now loaded and DialogState is set
            rts

:no_dialog
            stz   DialogState
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

            lda   DialogLineCount
            beq   :no_message         ; No lines to draw
            sta   Tmp3                ; Tmp3 = line counter

            ; Copy DialogMessagePtr to direct page for indirect indexed addressing
            lda   DialogMessagePtr
            sta   Tmp4                ; Tmp4 = pointer to string array

            stz   Tmp2                ; Tmp2 = current line index (0-based)

:draw_line
            ; Calculate Y position for this line
            ; Y = DIALOG_Y + 8 + (line_index * 8)
            lda   Tmp2                ; Current line index
            asl   a                   ; × 2
            asl   a                   ; × 4
            asl   a                   ; × 8 pixels per line
            clc
            adc   #DIALOG_Y
            adc   #8                  ; Y = DIALOG_Y + 8 + (line * 8)
            sta   Tmp0

            ; Multiply Y by 160
            lda   Tmp0
            asl   a                   ; × 2
            asl   a                   ; × 4
            asl   a                   ; × 8
            asl   a                   ; × 16
            asl   a                   ; × 32
            sta   Tmp1                ; Save × 32
            lda   Tmp0
            asl   a                   ; × 2
            asl   a                   ; × 4
            asl   a                   ; × 8
            asl   a                   ; × 16
            asl   a                   ; × 32
            asl   a                   ; × 64
            asl   a                   ; × 128
            clc
            adc   Tmp1                ; × 128 + × 32 = × 160

            ; Add X offset
            clc
            adc   #DIALOG_X
            adc   #8                  ; 8 pixels from left of box
            tax

            ; Get string pointer for this line
            ; Assume DialogMessagePtr points to array of word pointers
            lda   Tmp2
            asl                       ; × 2 for word offset
            tay
            lda   (Tmp4),y            ; Get pointer to this line's string
            beq   :next_line          ; Skip if null

            ldy   #$FFFF              ; White text color
            jsr   DrawString

:next_line
            inc   Tmp2                ; Next line
            dec   Tmp3                ; Decrement counter
            bne   :draw_line          ; Continue if more lines

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
; If a dialog is already active, this will be queued
TriggerDialogSimple
            pha                       ; Save message pointer

            ; Check if dialog already active
            lda   DialogState
            beq   :no_active_dialog

            ; Dialog active - enqueue this one
            pla                       ; Get message pointer
            ldx   #1                  ; Single line
            jsr   EnqueueDialog
            rts

:no_active_dialog
            ; No active dialog - show immediately
            pla
            sta   DialogMessagePtr
            stz   DialogMessagePtr+2    ; Assume same bank
            lda   #1
            sta   DialogLineCount       ; Single line
            sta   DialogState
            rts

; Trigger dialog with multiple lines
; Input: A = pointer to array of string pointers
;        X = number of lines (1-4)
; If a dialog is already active, this will be queued
TriggerMultiLineDialog
            pha                       ; Save message pointer
            txa
            pha                       ; Save line count

            ; Check if dialog already active
            lda   DialogState
            beq   :no_active_dialog

            ; Dialog active - enqueue this one
            pla                       ; Get line count
            tax
            pla                       ; Get message pointer
            jsr   EnqueueDialog
            rts

:no_active_dialog
            ; No active dialog - show immediately
            pla                       ; Get line count
            tax
            pla                       ; Get message pointer
            sta   DialogMessagePtr
            stz   DialogMessagePtr+2
            stx   DialogLineCount
            lda   #1
            sta   DialogState
            rts

; Enqueue a dialog to be shown after current dialogs
; Input: A = pointer to message (array of string pointers for multiline)
;        X = number of lines (1-4)
; Returns: Carry clear if enqueued, carry set if queue full
EnqueueDialog
            pha                       ; Save message pointer
            txa
            pha                       ; Save line count

            ; Check if queue is full
            lda   DialogQueueCount
            cmp   #MAX_DIALOG_QUEUE
            bcc   :not_full

            ; Queue full
            pla                       ; Clean up stack
            pla
            sec                       ; Set carry = queue full
            rts

:not_full
            ; Calculate tail offset for message pointer (4 bytes per entry)
            lda   DialogQueueTail
            asl                       ; × 2
            asl                       ; × 4
            tax

            ; Store message pointer (low word only, high word = 0)
            pla                       ; Get line count (discard for now)
            sta   Tmp5                ; Temp save line count - use Tmp5 (safe, not used by Camera/Enemy)
            pla                       ; Get message pointer
            sta   DialogQueueMsgPtr,x
            stz   DialogQueueMsgPtr+2,x  ; High word = 0 (same bank)

            ; Calculate tail offset for line count (2 bytes per entry)
            lda   DialogQueueTail
            asl                       ; × 2
            tax

            ; Store line count
            lda   Tmp5
            sta   DialogQueueLineCount,x

            ; Increment tail (with wraparound)
            lda   DialogQueueTail
            inc
            cmp   #MAX_DIALOG_QUEUE
            bcc   :no_wrap
            lda   #0
:no_wrap
            sta   DialogQueueTail

            ; Increment count
            inc   DialogQueueCount

            clc                       ; Clear carry = success
            rts

; Dequeue next dialog and load it
; Returns: Carry clear if dialog loaded, carry set if queue empty
DequeueDialog
            ; Check if queue is empty
            lda   DialogQueueCount
            bne   :not_empty
            sec                       ; Set carry = queue empty
            rts

:not_empty
            ; Calculate head offset for message pointer (4 bytes per entry)
            lda   DialogQueueHead
            asl                       ; × 2
            asl                       ; × 4
            tax

            ; Load message pointer
            lda   DialogQueueMsgPtr,x
            sta   DialogMessagePtr
            lda   DialogQueueMsgPtr+2,x
            sta   DialogMessagePtr+2

            ; Calculate head offset for line count (2 bytes per entry)
            lda   DialogQueueHead
            asl                       ; × 2
            tax

            ; Load line count
            lda   DialogQueueLineCount,x
            sta   DialogLineCount

            ; Increment head (with wraparound)
            lda   DialogQueueHead
            inc
            cmp   #MAX_DIALOG_QUEUE
            bcc   :no_wrap
            lda   #0
:no_wrap
            sta   DialogQueueHead

            ; Decrement count
            dec   DialogQueueCount

            ; Set dialog state to active
            lda   #1
            sta   DialogState

            clc                       ; Clear carry = success
            rts

; Queue multiple dialogs at once
; Input: A = pointer to array of dialog descriptors
;        X = number of dialogs to queue
; Each descriptor is 3 words: msg_ptr (2 bytes), line_count (2 bytes), unused (2 bytes)
QueueMultipleDialogs
            sta   Tmp0                ; Store descriptor array pointer
            stx   Tmp1                ; Store count

            stz   Tmp2                ; Index = 0

:loop
            ; Calculate offset: index × 6 (3 words per descriptor)
            lda   Tmp2
            asl                       ; × 2
            sta   Tmp3
            asl                       ; × 4
            clc
            adc   Tmp3                ; × 4 + × 2 = × 6
            tay

            ; Get message pointer
            lda   (Tmp0),y
            pha                       ; Save for EnqueueDialog

            ; Get line count
            iny
            iny
            lda   (Tmp0),y
            tax                       ; Line count in X

            pla                       ; Message pointer in A
            jsr   EnqueueDialog
            bcs   :queue_full         ; Queue full, stop trying

            ; Next dialog
            inc   Tmp2
            lda   Tmp2
            cmp   Tmp1
            bcc   :loop

:queue_full
            rts
