; ========================================
; ENEMY AI FUNCTIONS
; ========================================
;
; TEMP VARIABLE USAGE:
; Tmp0, Tmp1 - Used by UpdateCamera, Dialog - DO NOT USE
; Tmp2       - Used by CalculateDistance - Safe for other Enemy functions
; Tmp3, Tmp4 - Used by UpdateChase - Safe for other Enemy functions
; Tmp5+      - Generally safe to use
;
; ========================================

InitEnemy
            pea   ENEMY_SPRITE_ID
            pea   ENEMY_VBUFF
            _GTECreateSpriteStamp

            ; compiled
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   EnemyFlags
            pha           ; Space for result
            pea   SPRITE_16X16
            pea   ENEMY_VBUFF
            _GTECompileSpriteStamp
            pla
            sta   SpriteTmpAddr
            
            ; position and state
            lda   #150
            sta   EnemyGlobalX
            lda   #200
            sta   EnemyGlobalY

            lda   #100
            sta   EnemyPatrolMin
            lda   #350
            sta   EnemyPatrolMax
            lda   #200
            sta   EnemyPatrolY      ; Store patrol Y position

            stz   EnemyDirection
            stz   EnemyState
            stz   WasColliding       ; Initialize collision tracking

            lda   #ENEMY_SPEED_PATROL
            sta   EnemySpeed

            ; calculate screen pos
            lda   EnemyGlobalX
            sec
            sbc   ScreenX
            sta   EnemyScreenX
            lda   EnemyGlobalY
            sec
            sbc   ScreenY
            sta   EnemyScreenY

            ; add to screen
            pea   ENEMY_SLOT_1
            pei   EnemyFlags
            pei   SpriteTmpAddr
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEAddSprite
            rts

UpdateEnemy
; update position from scroll
            lda   EnemyGlobalX
            sec
            sbc   ScreenX
            sta   EnemyScreenX
            lda   EnemyGlobalY
            sec
            sbc   ScreenY
            sta   EnemyScreenY

            ; Check current state (patrol or chase)
            lda   EnemyState
            beq   :in_patrol

:in_chase
            ; In chase mode - pursue player
            jsr   UpdateChase

            ; SAFETY: Only check distance if enemy is on screen
            ; Offscreen enemies in chase should just keep chasing
            lda   EnemyScreenX
            bmi   :stay_chase           ; Offscreen, stay in chase
            cmp   #320
            bcs   :stay_chase           ; Offscreen, stay in chase
            lda   EnemyScreenY
            bmi   :stay_chase           ; Offscreen, stay in chase
            cmp   #200
            bcs   :stay_chase           ; Offscreen, stay in chase

            ; On screen - check if should return to patrol (player escaped)
            jsr   CalculateDistance     ; distance in A
            cmp   #ESCAPE_RANGE
            bcc   :stay_chase

            ; Return to patrol mode
            stz   EnemyState
            lda   #ENEMY_SPEED_PATROL
            sta   EnemySpeed

            ; Reset Y position to patrol level
            lda   EnemyPatrolY
            sta   EnemyGlobalY
            bra   :move_sprite

:stay_chase
            bra   :move_sprite

:in_patrol
            ; In patrol mode - walk back and forth
            jsr   UpdatePatrol

            ; SAFETY: Only check for chase if enemy is on screen
            ; Offscreen enemies should just patrol
            lda   EnemyScreenX
            bmi   :stay_patrol          ; Offscreen, stay in patrol
            cmp   #320
            bcs   :stay_patrol          ; Offscreen, stay in patrol
            lda   EnemyScreenY
            bmi   :stay_patrol          ; Offscreen, stay in patrol
            cmp   #200
            bcs   :stay_patrol          ; Offscreen, stay in patrol

            ; On screen - check if should change to chase (player detected)
            jsr   CalculateDistance
            cmp   #DETECTION_RANGE
            bcs   :stay_patrol

            ; Enter chase mode
            lda   #STATE_CHASE
            sta   EnemyState
            lda   #ENEMY_SPEED_CHASE
            sta   EnemySpeed

:stay_patrol

:move_sprite
            ; Validate screen coordinates before moving sprite
            ; If enemy is off screen, don't call _GTEMoveSprite
            lda   EnemyScreenX
            bmi   :skip_move        ; Negative X (off left)
            cmp   #320
            bcs   :skip_move        ; >= 320 (off right)

            lda   EnemyScreenY
            bmi   :skip_move        ; Negative Y (off top)
            cmp   #200
            bcs   :skip_move        ; >= 200 (off bottom)

            ; On screen - safe to move
            pea   ENEMY_SLOT_1
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEMoveSprite

:skip_move
            rts

UpdatePatrol
            lda   EnemyFrameCount
            inc
            sta   EnemyFrameCount
            and   #$0003
            beq   :do_patrol
            rts

:do_patrol
            lda   EnemyDirection
            bne   :moving_right
:moving_left
            lda   EnemyGlobalX
            sec
            sbc   EnemySpeed
            cmp   EnemyPatrolMin
            bcs   :set_left_pos

            ; hit minimum distance - reverse direction
            lda   EnemyPatrolMin
            sta   EnemyGlobalX
            lda   #1
            sta   EnemyDirection
            rts
:set_left_pos
            sta   EnemyGlobalX
            rts
:moving_right
            lda   EnemyGlobalX
            clc
            adc   EnemySpeed
            cmp   EnemyPatrolMax
            bcc   :set_right_pos
            beq   :set_right_pos

            ; hit max, reverse
            lda   EnemyPatrolMax
            sta   EnemyGlobalX
            stz   EnemyDirection
            rts
:set_right_pos
            sta   EnemyGlobalX
            rts                                                            

UpdateChase
            ; Throttle chase movement (same as patrol - every 4 frames)
            lda   EnemyFrameCount
            inc
            sta   EnemyFrameCount
            and   #$0003
            beq   :do_chase
            rts

:do_chase
            ; calc abs deltas for both axes
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            bpl   :pos_dx
            eor   #$FFFF
            inc
:pos_dx
            sta   Tmp3                  ; abs(deltaX) - use Tmp3 to avoid conflicts

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            sta   Tmp4                  ; abs(deltaY) - use Tmp4 to avoid conflicts

; Compare: move in axis with larger distance
            lda   Tmp3
            cmp   Tmp4
            bcs   :move_x               ; abs(deltaX) >= abs(deltaY), move in X

:move_y
; Move in Y direction
            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            beq   :done                 ; Already aligned
            bmi   :chase_up

:chase_down
            lda   EnemyGlobalY
            clc
            adc   EnemySpeed
            cmp   #640                  ; World boundary
            bcc   :set_y
            lda   #639
:set_y
            sta   EnemyGlobalY
            bra   :done

:chase_up
            lda   EnemyGlobalY
            sec
            sbc   EnemySpeed
            bpl   :set_y
            lda   #0
            sta   EnemyGlobalY
            bra   :done

:move_x
; Move in X direction
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            beq   :done                 ; Already aligned
            bmi   :chase_left

:chase_right
            lda   EnemyGlobalX
            clc
            adc   EnemySpeed
            cmp   #960                  ; World boundary
            bcc   :set_x
            lda   #959
:set_x
            sta   EnemyGlobalX
            bra   :done

:chase_left
            lda   EnemyGlobalX
            sec
            sbc   EnemySpeed
            bpl   :set_x
            lda   #0
            sta   EnemyGlobalX

:done
            rts

CalculateDistance
; Returns Manhattan distance in A: |PlayerX - EnemyX| + |PlayerY - EnemyY|
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            bpl   :pos_dx
            eor   #$FFFF                ; Two's complement
            inc
:pos_dx
            sta   Tmp2                  ; abs(deltaX) - use Tmp2 (safe, not used by Camera/Dialog)

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            clc
            adc   Tmp2                  ; abs(deltaY) + abs(deltaX)
            rts

CheckEnemyCollision
; Returns A=1 if collision, A=0 if no collision
            jsr   CalculateDistance
            cmp   #16                   ; Collision threshold (sprites overlap)
            bcs   :no_collision

            ; We're colliding now
            ; Check if we were colliding last frame
            lda   WasColliding
            bne   :already_colliding    ; Was already colliding, don't re-trigger

            ; New collision! Trigger multiple dialogs in sequence
            lda   DialogState
            bne   :skip_trigger         ; Dialog already active, skip trigger

            ; First dialog - greeting
            lda   #Dialog1Lines
            ldx   #2              ; 2 lines
            jsr   TriggerMultiLineDialog

            ; Second dialog - introduction
            lda   #Dialog2Lines
            ldx   #3              ; 3 lines
            jsr   TriggerMultiLineDialog

            ; Third dialog - farewell
            lda   #Dialog3Lines
            ldx   #2              ; 2 lines
            jsr   TriggerMultiLineDialog


:skip_trigger
:already_colliding
            lda   #1
            sta   WasColliding          ; Remember we're colliding
            lda   #1                    ; Return collision = true
            rts

:no_collision
            stz   WasColliding          ; Clear collision state
            lda   #0
            rts

; Multiple dialogs that chain together when player collides with enemy

; Dialog 1 - Greeting (2 lines)
Dialog1Lines        dw   D1_Line1, D1_Line2
D1_Line1            str  'WELCOME TO'
D1_Line2            str  'LANCE VILLAGE!'

; Dialog 2 - Introduction (3 lines)
Dialog2Lines        dw   D2_Line1, D2_Line2, D2_Line3
D2_Line1            str  'I AM THE VILLAGE'
D2_Line2            str  'GUARDIAN. I WATCH OVER'
D2_Line3            str  'THIS PEACEFUL PLACE.'

; Dialog 3 - Farewell (2 lines)
Dialog3Lines        dw   D3_Line1, D3_Line2
D3_Line1            str  'ENJOY YOUR STAY'
D3_Line2            str  'AND BE SAFE!'
