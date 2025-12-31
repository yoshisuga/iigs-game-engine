HandleInput
            pha
            _GTEReadControl
            pla

; Check for arrow keys
            and   #$007F
            pha

            cmp   #$08                  ; LEFT_ARROW
            bne   :not_left

; Check collision at LEFT EDGE of sprite
            lda   PlayerScreenX
            sec
            sbc   PlayerSpeed
            tax
            lda   PlayerScreenY
            clc
            adc   #8              ; Check middle of sprite height
            tay
            jsr   CheckTileCollision
            bcs   :not_left

            lda   PlayerGlobalX
            sec
            sbc   PlayerSpeed
            bpl   :set_left
            lda   #0                    ; fall through - clamp to zero, no negative numbers
:set_left
            sta   PlayerGlobalX
:not_left
            pla                         ; Restore key code
            pha                         ; Save key code

            cmp   #$15                  ; RIGHT_ARROW
            bne   :not_right

; Check collision at RIGHT EDGE of sprite
            lda   PlayerScreenX
            clc
            adc   #8             
            adc   PlayerSpeed
            tax
            lda   PlayerScreenY
            clc
            adc   #8              ; Check middle of sprite height
            tay
            jsr   CheckTileCollision
            bcs   :not_right

            lda   PlayerGlobalX
            clc
            adc   PlayerSpeed
            cmp   #960             ; World width in X-units
            bcc   :set_right
            lda   #959
:set_right
            sta   PlayerGlobalX
:not_right
            pla
            pha

            cmp   #UP_ARROW
            bne   :not_up

; Check collision at TOP EDGE of sprite
            lda   PlayerScreenY
            sec
            sbc   PlayerSpeed
            tay
            lda   PlayerScreenX
            clc
            adc   #4              ; Check middle of sprite width
            tax
            jsr   CheckTileCollision
            bcs   :not_up

            lda   PlayerGlobalY
            sec
            sbc   PlayerSpeed
            bpl   :set_up
            lda   #0
:set_up
            sta   PlayerGlobalY
:not_up
            pla
            pha

            cmp   #DOWN_ARROW
            bne   :not_down

; Check collision at BOTTOM EDGE of sprite
            lda   PlayerScreenY
            clc
            adc   #16             ; Bottom edge of 16x16 sprite
            adc   PlayerSpeed
            tay
            lda   PlayerScreenX
            clc
            adc   #4              ; Check middle of sprite width
            tax
            jsr   CheckTileCollision
            bcs   :not_down

            lda   PlayerGlobalY
            clc
            adc   PlayerSpeed
            cmp   #640            ; world height in pixels
            bcc   :set_down
            lda   #639
:set_down
            sta   PlayerGlobalY                        
:not_down
            pla

            pha
            _GTEReadControl
            pla

            jsr HandleKeys          ; generic handler for quit
            rts

