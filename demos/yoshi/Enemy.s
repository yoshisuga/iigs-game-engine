; ========================================
; ENEMY AI FUNCTIONS
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

            stz   EnemyDirection
            stz   EnemyState

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

            ; check current state
            lda   EnemyState
            beq   :in_patrol

:in_chase   
            jsr   UpdateChase

; check if should return to patrol if too far
            jsr   CalculateDistance     ; distance in A
            cmp   #ESCAPE_RANGE
            bcc   :stay_chase

; return to patrol
            stz   EnemyState
            lda   #ENEMY_SPEED_PATROL
            sta   EnemySpeed
            bra   :move_sprite
:stay_chase
            bra   :move_sprite
:in_patrol
            jsr   UpdatePatrol

; check if should change to chase
            jsr   CalculateDistance
            cmp   #DETECTION_RANGE
            bcs   :stay_patrol

; Chase Mode
            lda   #STATE_CHASE
            sta   EnemyState
            lda   #ENEMY_SPEED_CHASE
            sta   EnemySpeed

:stay_patrol

:move_sprite
            ; update position
            pea   ENEMY_SLOT_1
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEMoveSprite
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
            ; calc abs deltas for both axes
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            bpl   :pos_dx
            eor   #$FFFF
            inc
:pos_dx
            sta   Tmp0                  ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            sta   Tmp1                  ; abs(deltaY)

; Compare: move in axis with larger distance
            lda   Tmp0
            cmp   Tmp1
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
            sta   Tmp0                  ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            clc
            adc   Tmp0                  ; abs(deltaY) + abs(deltaX)
            rts

CheckEnemyCollision
; Returns A=1 if collision, A=0 if no collision
            jsr   CalculateDistance
            cmp   #16                   ; Collision threshold (sprites overlap)
            bcs   :no_collision

            lda   #1                    ; Collision detected
            rts

:no_collision
            lda   #0
            rts
