; Convert 16-bit number to 4-char string
; A = number to convert
; Result in NumStr (5 bytes: length + 4 digits)
Num2Str4
            sta   Tmp0
;Thousands digit
            ldx   #0
:th_loop
            cmp   #1000
            bcc   :th_done
            sec
            sbc   #1000
            inx
            bra   :th_loop
:th_done
            pha           ; A=orig value-1000, push to stack
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'    ; add the thousand digit to 0 to get the char for digit
            sta   NumStr+1    ; +1 because the first has the length
            rep   #$20    ; Back to 16-bit mode
            pla               ; get back the origValue-1000
; Hundreds digit
            ldx   #0
:h_loop
            cmp   #100
            bcc   :h_done
            sec
            sbc   #100
            inx
            bra   :h_loop
:h_done
            pha         ; A=origValue-100, push to stack
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'      ; add the hundreds digit to 0 to get the char
            sta   NumStr+2
            rep   #$20    ; Back to 16-bit mode
            pla
; Tens
            ldx   #0
:t_loop
            cmp   #10
            bcc   :t_done
            sec
            sbc   #10
            inx
            bra   :t_loop
:t_done
            pha
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'
            sta   NumStr+3
            rep   #$20    ; Back to 16-bit mode
            pla
; Ones
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'      ; left over
            sta   NumStr+4
            lda   #4        ; length=4
            sta   NumStr
            rep   #$20    ; Back to 16-bit mode
            rts

BuildDebugStr
            sep   #$20             ; Switch to 8-bit A
            lda   #'S'
            sta   DebugStr+1
            lda   #'X'
            sta   DebugStr+2
            lda   #':'
            sta   DebugStr+3
            rep   #$20             ; Back to 16-bit A

            lda   ScreenX
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+4
            lda   NumStr+2
            sta   DebugStr+5
            lda   NumStr+3
            sta   DebugStr+6
            lda   NumStr+4
            sta   DebugStr+7
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+8
            lda   #'S'
            sta   DebugStr+9
            lda   #'Y'
            sta   DebugStr+10
            lda   #':'
            sta   DebugStr+11
            rep   #$20             ; Back to 16-bit A

            lda   ScreenY
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+12
            lda   NumStr+2
            sta   DebugStr+13
            lda   NumStr+3
            sta   DebugStr+14
            lda   NumStr+4
            sta   DebugStr+15
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+16
            lda   #'P'
            sta   DebugStr+17
            lda   #'X'
            sta   DebugStr+18
            lda   #':'
            sta   DebugStr+19
            rep   #$20             ; Back to 16-bit A

            lda   PlayerGlobalX
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+20
            lda   NumStr+2
            sta   DebugStr+21
            lda   NumStr+3
            sta   DebugStr+22
            lda   NumStr+4
            sta   DebugStr+23
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+24
            lda   #'P'
            sta   DebugStr+25
            lda   #'Y'
            sta   DebugStr+26
            lda   #':'
            sta   DebugStr+27
            rep   #$20             ; Back to 16-bit A

            lda   PlayerGlobalY
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+28
            lda   NumStr+2
            sta   DebugStr+29
            lda   NumStr+3
            sta   DebugStr+30
            lda   NumStr+4
            sta   DebugStr+31

            ; Add tile ID display
            lda   #' '
            sta   DebugStr+32
            lda   #'T'
            sta   DebugStr+33
            lda   #':'
            sta   DebugStr+34
            rep   #$20             ; Back to 16-bit A

            ; Get current tile ID at player position
            pha
            lda   PlayerGlobalX
            clc
            adc   #8
            pha
            lda   PlayerGlobalY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+1
            sta   DebugStr+35
            lda   NumStr+2
            sta   DebugStr+36
            lda   NumStr+3
            sta   DebugStr+37
            lda   NumStr+4
            sta   DebugStr+38

            lda   #39
            sta   DebugStr

            ; tile collision directional checks
            lda   #'C'
            sta   DebugStr2+1
            lda   #'T'
            sta   DebugStr2+2
            lda   #':'
            sta   DebugStr2+3
            lda   #'U'
            sta   DebugStr2+4
            lda   #':'
            sta   DebugStr2+5

            ; Tile Up
            rep   #$20
            pha
            lda   PlayerScreenX
            pha
            lda   PlayerScreenY
            sec
            sbc   PlayerSpeed
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+6
            lda   NumStr+3
            sta   DebugStr2+7
            lda   NumStr+4
            sta   DebugStr2+8

            ; Tile Left
            lda   #'L'
            sta   DebugStr2+9
            lda   #':'
            sta   DebugStr2+10

            rep   #$20
            pha
            lda   PlayerScreenX
            sec
            sbc   PlayerSpeed
            pha
            lda   PlayerScreenY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+11
            lda   NumStr+3
            sta   DebugStr2+12
            lda   NumStr+4
            sta   DebugStr2+13

            ; Tile Right
            lda   #'R'
            sta   DebugStr2+14
            lda   #':'
            sta   DebugStr2+15

            rep   #$20
            pha
            lda   PlayerScreenX
            clc
            adc   #8
            adc   PlayerSpeed
            pha
            lda   PlayerScreenY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+16
            lda   NumStr+3
            sta   DebugStr2+17
            lda   NumStr+4
            sta   DebugStr2+18

            ; Tile Down
            lda   #'D'
            sta   DebugStr2+19
            lda   #':'
            sta   DebugStr2+20

            rep   #$20
            pha
            lda   PlayerScreenX
            clc
            adc   #4
            pha
            lda   PlayerScreenY
            clc
            adc   #16
            adc   PlayerSpeed
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+21
            lda   NumStr+3
            sta   DebugStr2+22
            lda   NumStr+4
            sta   DebugStr2+23

; Add collision indicator
            sep   #$20
            lda   #' '
            sta   DebugStr2+24
            lda   #'H'
            sta   DebugStr2+25
            lda   #'I'
            sta   DebugStr2+26
            lda   #'T'
            sta   DebugStr2+27
            lda   #':'
            sta   DebugStr2+28

            rep   #$20
            jsr   CheckEnemyCollision
            clc
            adc   #'0'                  ; Convert 0/1 to '0'/'1'
            sep   #$20
            sta   DebugStr2+29

            lda   #29
            sta   DebugStr2             ; Update length

            rep   #$20             ; Back to 16-bit A
            rts


DebugPrinter
            jsr   BuildDebugStr

            lda   #DebugStr         ; No bank byte needed
            ldx   #160*190
            ldy   #$FFFF
            jsr   DrawString

            lda   #DebugStr2
            ldx   #160*180
            ldy   #$ffff
            jsr   DrawString

            lda   #TestStr
            ldx   #160*170
            ldy   #$ffff
            jsr   DrawString
            rts            
