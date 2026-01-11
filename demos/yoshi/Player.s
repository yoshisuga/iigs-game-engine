; ========================================
; PLAYER SYSTEM
; ========================================
;
; Manages the player sprite (16x24 using two sprites: 16x16 top + 16x8 bottom)
; Handles animation with 3 frames per direction (Down, Left, Right, Up)
; Direction 0 = Down, 1 = Right, 2 = Left, 3 = Up
;
; Uses data structure approach for easy expansion of stats, equipment, etc.

; ========================================
; PLAYER DATA STRUCTURE
; ========================================
; All player data grouped together for easy access and expansion

; Position and movement
PlayerGlobalX      ds   2      ; World X position
PlayerGlobalY      ds   2      ; World Y position
PlayerScreenX      ds   2      ; Screen X position (calculated from scroll)
PlayerScreenY      ds   2      ; Screen Y position (calculated from scroll)
PlayerSpeed        ds   2      ; Movement speed (pixels per frame)

; Animation state
PlayerDirection    ds   2      ; 0=Down, 1=Right, 2=Left, 3=Up
PlayerFrame        ds   2      ; Current animation frame (0-2)
PlayerAnimTimer    ds   2      ; Frame counter for animation timing

; Combat stats (for future RPG features)
PlayerHealth       ds   2      ; Current HP
PlayerMaxHealth    ds   2      ; Maximum HP
PlayerAttack       ds   2      ; Attack power
PlayerDefense      ds   2      ; Defense power
PlayerExp          ds   2      ; Experience points
PlayerLevel        ds   2      ; Character level

; Equipment slots (for future expansion)
PlayerWeapon       ds   2      ; Equipped weapon ID
PlayerArmor        ds   2      ; Equipped armor ID
PlayerShield       ds   2      ; Equipped shield ID
PlayerAccessory    ds   2      ; Equipped accessory ID

; Inventory/status
PlayerGold         ds   2      ; Currency
PlayerKeys         ds   2      ; Number of keys
PlayerStatus       ds   2      ; Status effects (bitfield)
PlayerInvincibilityTimer ds 2 ; Frames remaining of invincibility (0 = can take damage)

; ========================================
; COMPILED SPRITE ADDRESS ARRAYS
; ========================================
; Filled by InitPlayerSpriteFrames
; 3 frames per direction × 2 bytes per address

DownTopCompiled    ds   6      ; Down direction - top sprite (3 frames)
DownBotCompiled    ds   6      ; Down direction - bottom sprite (3 frames)
LeftTopCompiled    ds   6      ; Left direction - top sprite
LeftBotCompiled    ds   6      ; Left direction - bottom sprite
UpTopCompiled      ds   6      ; Up direction - top sprite
UpBotCompiled      ds   6      ; Up direction - bottom sprite
; Note: Right direction reuses Left frames with HFLIP

; ========================================
; INITIALIZATION
; ========================================

InitPlayer
; Initialize player position, stats, and animation state
            ; Set starting world position
            lda   #32
            sta   PlayerGlobalX
            lda   #60
            sta   PlayerGlobalY

            ; Initialize screen position (will be updated by UpdateCamera)
            stz   PlayerScreenX
            stz   PlayerScreenY

            ; Set movement speed
            lda   #2
            sta   PlayerSpeed

            ; Animation state
            stz   PlayerDirection    ; Face down (0)
            stz   PlayerFrame        ; Frame 0
            stz   PlayerAnimTimer    ; Animation timer

            ; Initialize combat stats
            lda   #100
            sta   PlayerHealth
            sta   PlayerMaxHealth    ; Start with 100 HP
            lda   #10
            sta   PlayerAttack       ; Base attack = 10
            lda   #5
            sta   PlayerDefense      ; Base defense = 5
            stz   PlayerExp          ; Start with 0 exp
            lda   #1
            sta   PlayerLevel        ; Start at level 1

            ; Initialize equipment (0 = no equipment)
            stz   PlayerWeapon
            stz   PlayerArmor
            stz   PlayerShield
            stz   PlayerAccessory

            ; Initialize inventory
            stz   PlayerGold         ; Start with 0 gold
            stz   PlayerKeys         ; Start with 0 keys
            stz   PlayerStatus       ; No status effects
            stz   PlayerInvincibilityTimer ; Not invincible at start

            ; Create all sprite frames and add to screen
            jsr   InitPlayerSpriteFrames

            rts

InitPlayerSpriteFrames
; Create and compile sprite stamps for all 9 animation frames
; Each direction has 3 frames
; Uses separate VBUFFs to avoid overwriting

; ========================================
; DOWN FRAMES (0-2)
; ========================================

; Down Frame 0 - Top
            pea   SPRITE_16X16+1
            pea   DOWN_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   DOWN_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   DownTopCompiled+0
; Down Frame 0 - Bottom
            pea   SPRITE_16X8+65
            pea   DOWN_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   DOWN_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   DownBotCompiled+0

; Down Frame 1 - Top
            pea   SPRITE_16X16+3
            pea   DOWN_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   DOWN_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   DownTopCompiled+2
; Down Frame 1 - Bottom
            pea   SPRITE_16X8+67
            pea   DOWN_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   DOWN_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   DownBotCompiled+2

; Down Frame 2 - Top
            pea   SPRITE_16X16+5
            pea   DOWN_TOP_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   DOWN_TOP_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   DownTopCompiled+4
; Down Frame 2 - Bottom
            pea   SPRITE_16X8+69
            pea   DOWN_BOT_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   DOWN_BOT_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   DownBotCompiled+4

; ========================================
; LEFT FRAMES (0-2)
; ========================================

; Left Frame 0 - Top
            pea   SPRITE_16X16+7
            pea   LEFT_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   LEFT_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   LeftTopCompiled+0
; Left Frame 0 - Bottom
            pea   SPRITE_16X8+71
            pea   LEFT_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   LEFT_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   LeftBotCompiled+0

; Left Frame 1 - Top
            pea   SPRITE_16X16+9
            pea   LEFT_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   LEFT_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   LeftTopCompiled+2
; Left Frame 1 - Bottom
            pea   SPRITE_16X8+73
            pea   LEFT_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   LEFT_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   LeftBotCompiled+2

; Left Frame 2 - Top
            pea   SPRITE_16X16+11
            pea   LEFT_TOP_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   LEFT_TOP_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   LeftTopCompiled+4
; Left Frame 2 - Bottom
            pea   SPRITE_16X8+75
            pea   LEFT_BOT_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   LEFT_BOT_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   LeftBotCompiled+4

; ========================================
; UP FRAMES (0-2)
; ========================================

; Up Frame 0 - Top
            pea   SPRITE_16X16+13
            pea   UP_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   UP_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   UpTopCompiled+0
; Up Frame 0 - Bottom
            pea   SPRITE_16X8+77
            pea   UP_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   UP_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            sta   UpBotCompiled+0

; Up Frame 1 - Top
            pea   SPRITE_16X16+15
            pea   UP_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   UP_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   UpTopCompiled+2
; Up Frame 1 - Bottom
            pea   SPRITE_16X8+79
            pea   UP_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   UP_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            sta   UpBotCompiled+2

; Up Frame 2 - Top
            pea   SPRITE_16X16+17
            pea   UP_TOP_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   UP_TOP_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   UpTopCompiled+4
; Up Frame 2 - Bottom
            pea   SPRITE_16X8+81
            pea   UP_BOT_VBUFF_2
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   UP_BOT_VBUFF_2
            _GTECompileSpriteStamp
            pla
            sta   UpBotCompiled+4

            ; Add player sprites to screen (uses first down frame)
            jsr   AddPlayerSprites

            rts

AddPlayerSprites
; Add top and bottom player sprites to screen
            ; Top sprite (slot 0)
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            lda   DownTopCompiled+0      ; First down frame
            pha
            lda   PlayerScreenX
            pha
            lda   PlayerScreenY
            pha
            _GTEAddSprite

            ; Bottom sprite (slot 1)
            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            lda   DownBotCompiled+0      ; First down frame
            pha
            lda   PlayerScreenX
            pha
            lda   PlayerScreenY
            clc
            adc   #15                    ; Offset Y by 15 for bottom sprite
            pha
            _GTEAddSprite

            rts

; ========================================
; UPDATE AND ANIMATION
; ========================================

UpdatePlayerAnimation
; Slow animation - only update every 2 frames
            lda   PlayerAnimTimer
            inc   a
            cmp   #2
            bcc   :no_update

            ; Reset timer
            lda   #0
            sta   PlayerAnimTimer

            ; Advance frame
            lda   PlayerFrame
            inc   a
            cmp   #3                     ; 3 frames per direction
            bcc   :set_frame
            lda   #0                     ; Wrap back to frame 0
:set_frame
            sta   PlayerFrame

            ; Update sprite graphics
            jsr   UpdatePlayerSprites
            rts

:no_update
            sta   PlayerAnimTimer
            rts

UpdatePlayerSprites
; Update sprite graphics based on current direction and frame
; Uses jump table for direction handling
            lda   PlayerDirection
            asl                          ; × 2 for word offset
            tax
            jmp   (DirectionHandlers,x)

DirectionHandlers
            dw   HandleDown
            dw   HandleRight
            dw   HandleLeft
            dw   HandleUp

HandleDown
            lda   PlayerFrame
            asl                          ; × 2 for word offset
            tax
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            lda   DownTopCompiled,x
            pha
            _GTEUpdateSprite

            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            lda   DownBotCompiled,x
            pha
            _GTEUpdateSprite
            rts

HandleLeft
            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            lda   LeftTopCompiled,x
            pha
            _GTEUpdateSprite

            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            lda   LeftBotCompiled,x
            pha
            _GTEUpdateSprite
            rts

HandleRight
; Reuse left frames with horizontal flip
            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            lda   LeftTopCompiled,x      ; Reuse left frames
            pha
            _GTEUpdateSprite

            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            lda   LeftBotCompiled,x
            pha
            _GTEUpdateSprite
            rts

HandleUp
            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            lda   UpTopCompiled,x
            pha
            _GTEUpdateSprite

            lda   PlayerFrame
            asl
            tax
            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            lda   UpBotCompiled,x
            pha
            _GTEUpdateSprite
            rts

MovePlayer
; Update player sprite positions on screen
; Top sprite
            pea   PLAYER_SLOT
            lda   PlayerScreenX
            pha
            lda   PlayerScreenY
            pha
            _GTEMoveSprite

            ; Bottom sprite (Y offset +15)
            lda   PlayerScreenY
            clc
            adc   #15
            sta   Tmp0              ; Save bottom Y

            pea   PLAYER_BOT_SLOT
            lda   PlayerScreenX
            pha
            lda   Tmp0
            pha
            _GTEMoveSprite
            rts

; ========================================
; CAMERA SYSTEM
; ========================================

UpdateCamera
; Updates camera position based on player position
; Uses deadzone system to create smooth scrolling
; Calc screen position
            lda   PlayerGlobalX
            sec
            sbc   ScreenX
            sta   PlayerScreenX

            lda   PlayerGlobalY
            sec
            sbc   ScreenY
            sta   PlayerScreenY

; Check X axis: Right edge
            lda   PlayerScreenX
            cmp   #DEADZONE_RIGHT
            bcc   :check_left

; X Axis: past deadzone right edge - scroll
            sec
            sbc   #DEADZONE_RIGHT
            clc
            adc   ScreenX
            cmp   #MAX_SCROLL_X+1
            bcc   :set_scroll_x
            lda   #MAX_SCROLL_X
:set_scroll_x
            sta   ScreenX
            lda   PlayerGlobalX
            sec
            sbc   ScreenX
            sta   PlayerScreenX       ; re-calc player screen after setting scroll pos
            bra   :check_y

; Check X axis: left edge
:check_left
            lda   PlayerScreenX
            cmp   #DEADZONE_LEFT
            bcs   :check_y

; X Axis: past left edge - scroll
            lda   #DEADZONE_LEFT
            sec
            sbc   PlayerScreenX
            sta   Tmp0
            lda   ScreenX
            sec
            sbc   Tmp0
            bpl   :set_scroll_x2
            lda   #0
:set_scroll_x2
            sta   ScreenX
            lda   PlayerGlobalX
            sec
            sbc   ScreenX
            sta   PlayerScreenX

; Y Axis - bottom
:check_y
            lda   PlayerScreenY
            cmp   #DEADZONE_BOT
            bcc   :check_top

; Past bottom edge, scroll down
            sec
            sbc   #DEADZONE_BOT
            clc
            adc   ScreenY
            cmp   #MAX_SCROLL_Y+1
            bcc   :set_scroll_y
            lda   #MAX_SCROLL_Y
:set_scroll_y
            sta   ScreenY
            lda   PlayerGlobalY
            sec
            sbc   ScreenY
            sta   PlayerScreenY
            bra   :done

:check_top
            lda   PlayerScreenY
            cmp   #DEADZONE_TOP
            bcs   :done

; Past top edge, scroll up
            lda   #DEADZONE_TOP
            sec
            sbc   PlayerScreenY
            sta   Tmp0
            lda   ScreenY
            sec
            sbc   Tmp0
            bpl   :set_scroll_y2
            lda   #0
:set_scroll_y2
            sta   ScreenY
            lda   PlayerGlobalY
            sec
            sbc   ScreenY
            sta   PlayerScreenY

:done
            rts

; ========================================
; COMBAT SYSTEM
; ========================================

UpdatePlayerInvincibility
; Decrement invincibility timer each frame
            lda   PlayerInvincibilityTimer
            beq   :done              ; Already 0, skip
            dec   a
            sta   PlayerInvincibilityTimer
:done
            rts

TakeDamage
; Player takes damage from enemy
; Input: A = damage amount
;        X = NPC index (for knockback calculation)
; Preserves: X register (important for caller context)
            ; Save damage amount and NPC index
            sta   Tmp0
            phx                      ; Save X (NPC index)

            ; Check if invincible
            lda   PlayerInvincibilityTimer
            bne   :skip_damage       ; Still invincible, no damage or knockback

            ; Apply defense (damage - defense, minimum 1)
            lda   Tmp0               ; Restore damage amount
            sec
            sbc   PlayerDefense
            bpl   :apply_damage
            lda   #1                 ; Minimum 1 damage
:apply_damage
            sta   Tmp0               ; Save final damage amount

            ; Subtract from health
            lda   PlayerHealth
            sec
            sbc   Tmp0
            bpl   :set_health
            lda   #0                 ; Can't go below 0
:set_health
            sta   PlayerHealth

            ; Set invincibility period
            lda   #10
            sta   PlayerInvincibilityTimer

            ; Apply knockback (X already on stack)
            plx                      ; Restore NPC index
            phx                      ; Save it again for final restore
            jsr   ApplyKnockback     ; Push player away

:skip_damage
            plx                      ; Restore X register
            rts

ApplyKnockback
; Push player away from enemy on collision
; Input: X = NPC index (must be preserved)
; Uses: Tmp0-Tmp3
            phx                     ; Save NPC index

            ; Calculate direction from enemy to player
            lda   PlayerGlobalX
            sec
            sbc   NPCGlobalX,x
            sta   Tmp0              ; Tmp0 = dx (player X - enemy X)

            lda   PlayerGlobalY
            sec
            sbc   NPCGlobalY,x
            sta   Tmp1              ; Tmp1 = dy (player Y - enemy Y)

            ; Determine if collision is more horizontal or vertical
            ; Compare absolute values
            lda   Tmp0
            bpl   :dx_positive
            eor   #$FFFF            ; Negate if negative
            inc   a
:dx_positive
            sta   Tmp2              ; Tmp2 = abs(dx)

            lda   Tmp1
            bpl   :dy_positive
            eor   #$FFFF            ; Negate if negative
            inc   a
:dy_positive
            sta   Tmp3              ; Tmp3 = abs(dy)

            ; Compare: if abs(dx) > abs(dy), knockback is horizontal
            lda   Tmp2
            cmp   Tmp3
            bcs   :horizontal_knockback

:vertical_knockback
            ; Push along Y axis
            lda   Tmp1              ; dy
            bpl   :push_down
:push_up
            ; Player is above enemy, push up
            lda   PlayerGlobalY
            sec
            sbc   #8                ; Knockback distance
            bpl   :set_y
            lda   #0
            bra   :set_y
:push_down
            ; Player is below enemy, push down
            lda   PlayerGlobalY
            clc
            adc   #8                ; Knockback distance
            cmp   #512              ; Max world Y
            bcc   :set_y
            lda   #511
:set_y
            sta   PlayerGlobalY
            bra   :done

:horizontal_knockback
            ; Push along X axis
            lda   Tmp0              ; dx
            bpl   :push_right
:push_left
            ; Player is left of enemy, push left
            lda   PlayerGlobalX
            sec
            sbc   #8                ; Knockback distance
            bpl   :set_x
            lda   #0
            bra   :set_x
:push_right
            ; Player is right of enemy, push right
            lda   PlayerGlobalX
            clc
            adc   #8                ; Knockback distance
            cmp   #960              ; Max world X
            bcc   :set_x
            lda   #959
:set_x
            sta   PlayerGlobalX

:done
            plx                     ; Restore NPC index
            rts
