; ========================================
; NPC SYSTEM - Simple array-based NPCs
; ========================================

; Constants
MAX_NPCS        equ 4           ; Start with just 4 NPCs
NPC_SLOT_BASE   equ 2           ; Sprite slots 2+ (0=player top, 1=player bot)
                                ; Each NPC uses 2 slots: top (16x16) + bottom (16x8)
                                ; NPC 0: slots 2,3
                                ; NPC 1: slots 4,5
                                ; NPC 2: slots 6,7
                                ; NPC 3: slots 8,9

; NPC Types (behavior on collision)
NPC_FRIENDLY    equ 0           ; Triggers dialog on collision
NPC_HOSTILE     equ 1           ; Damages player on collision

; AI Types (can be used by both friendly and hostile NPCs)
AI_NONE         equ 0           ; Stationary (shopkeeper, sign)
AI_PATROL       equ 1           ; Patrol between two points (guard, enemy)
AI_CHASE        equ 2           ; Chase player when nearby (aggressive enemy)
AI_WANDER       equ 3           ; Random wandering (villager, passive enemy)

; ========================================
; NPC DATA ARRAYS
; ========================================
; Each NPC has an index (0-3), all arrays use same indexing

NPCActive       ds  MAX_NPCS*2  ; 0=inactive, 1=active
NPCGlobalX      ds  MAX_NPCS*2  ; World X position (top-left of 16x24 sprite)
NPCGlobalY      ds  MAX_NPCS*2  ; World Y position
NPCScreenX      ds  MAX_NPCS*2  ; Screen X position (calculated from scroll)
NPCScreenY      ds  MAX_NPCS*2  ; Screen Y position

; Sprite data (top 16x16 sprite)
NPCTopSpriteID  ds  MAX_NPCS*2  ; Top sprite tile ID
NPCTopVBuff     ds  MAX_NPCS*2  ; Top sprite VBUFF
NPCTopFlags     ds  MAX_NPCS*2  ; Top sprite flags
NPCTopAddr      ds  MAX_NPCS*2  ; Compiled sprite address

; Sprite data (bottom 16x8 sprite)
NPCBotSpriteID  ds  MAX_NPCS*2  ; Bottom sprite tile ID
NPCBotVBuff     ds  MAX_NPCS*2  ; Bottom sprite VBUFF
NPCBotFlags     ds  MAX_NPCS*2  ; Bottom sprite flags
NPCBotAddr      ds  MAX_NPCS*2  ; Compiled sprite address

; Behavior and type
NPCBehavior         ds  MAX_NPCS*2  ; NPC_FRIENDLY or NPC_HOSTILE
NPCCharacterID  ds  MAX_NPCS*2  ; Dialog character ID (for friendly NPCs)

; Combat data (for hostile NPCs)
NPCHealth       ds  MAX_NPCS*2  ; Current health (0=dead)
NPCMaxHealth    ds  MAX_NPCS*2  ; Maximum health
NPCDamage       ds  MAX_NPCS*2  ; Damage dealt to player on collision

; AI data
NPCAIType       ds  MAX_NPCS*2  ; AI behavior type (AI_NONE, AI_PATROL, etc.)
NPCState        ds  MAX_NPCS*2  ; AI state (patrol direction, etc.)
NPCSpeed        ds  MAX_NPCS*2  ; Movement speed
NPCPatrolMin    ds  MAX_NPCS*2  ; Patrol minimum X (for AI_PATROL)
NPCPatrolMax    ds  MAX_NPCS*2  ; Patrol maximum X (for AI_PATROL)
NPCPatrolDir    ds  MAX_NPCS*2  ; Patrol direction (0=left, 1=right) - for AI_PATROL
NPCFrameCount   ds  MAX_NPCS*2  ; Frame counter for AI timing

; Animation state (for 16x24 sprite animation)
NPCDirection     ds  MAX_NPCS*2  ; Animation direction: 0=Down, 1=Right, 2=Left, 3=Up
NPCFrame         ds  MAX_NPCS*2  ; Current animation frame (0-1, only 2 frames)
NPCAnimTimer     ds  MAX_NPCS*2  ; Frame counter for animation timing

; Collision tracking
NPCWasColliding ds  MAX_NPCS*2  ; Collision state from last frame (rising edge detection)

; ========================================
; PER-NPC COMPILED SPRITE ADDRESSES
; ========================================
; Each NPC gets 12 compiled sprite addresses (2 frames × 6 arrays)
; 24 bytes per NPC × MAX_NPCS = 96 bytes total

; Down direction
NPCDownTopCompiled0    ds   MAX_NPCS*2    ; Down frame 0 - top sprite
NPCDownTopCompiled1    ds   MAX_NPCS*2    ; Down frame 1 - top sprite
NPCDownBotCompiled0    ds   MAX_NPCS*2    ; Down frame 0 - bottom sprite
NPCDownBotCompiled1    ds   MAX_NPCS*2    ; Down frame 1 - bottom sprite

; Left direction
NPCLeftTopCompiled0    ds   MAX_NPCS*2    ; Left frame 0 - top sprite
NPCLeftTopCompiled1    ds   MAX_NPCS*2    ; Left frame 1 - top sprite
NPCLeftBotCompiled0    ds   MAX_NPCS*2    ; Left frame 0 - bottom sprite
NPCLeftBotCompiled1    ds   MAX_NPCS*2    ; Left frame 1 - bottom sprite

; Up direction
NPCUpTopCompiled0      ds   MAX_NPCS*2    ; Up frame 0 - top sprite
NPCUpTopCompiled1      ds   MAX_NPCS*2    ; Up frame 1 - top sprite
NPCUpBotCompiled0      ds   MAX_NPCS*2    ; Up frame 0 - bottom sprite
NPCUpBotCompiled1      ds   MAX_NPCS*2    ; Up frame 1 - bottom sprite

; Right reuses Left with HFLIP (no storage needed)

; Temp variables for NPC system (Direct Page)
CurrentNPCIndex equ 72          ; Current NPC being processed
NPCTmp0         equ 74          ; Temp for AI calculations
NPCTmp1         equ 76          ; Temp for AI calculations
NPCTmp2         equ 78          ; Temp for AI calculations

; AI Constants
DETECTION_RANGE equ 36          ; Start chasing when player within 36 pixels
ESCAPE_RANGE    equ 60          ; Stop chasing when player > 60 pixels away

; ========================================
; INITIALIZATION
; ========================================

InitNPCs
            ; Clear all arrays
            ldx   #0
:clear
            stz   NPCActive,x
            stz   NPCGlobalX,x
            stz   NPCGlobalY,x
            stz   NPCScreenX,x
            stz   NPCScreenY,x
            stz   NPCTopSpriteID,x
            stz   NPCTopVBuff,x
            stz   NPCTopFlags,x
            stz   NPCTopAddr,x
            stz   NPCBotSpriteID,x
            stz   NPCBotVBuff,x
            stz   NPCBotFlags,x
            stz   NPCBotAddr,x
            stz   NPCBehavior,x
            stz   NPCCharacterID,x
            stz   NPCHealth,x
            stz   NPCMaxHealth,x
            stz   NPCDamage,x
            stz   NPCAIType,x
            stz   NPCState,x
            stz   NPCSpeed,x
            stz   NPCPatrolMin,x
            stz   NPCPatrolMax,x
            stz   NPCDirection,x
            stz   NPCFrameCount,x
            stz   NPCWasColliding,x
            inx
            inx
            cpx   #MAX_NPCS*2
            bcc   :clear

            ; Spawn the enemy (now as NPC 0)
            jsr   SpawnEnemy

            rts

; ========================================
; SPAWN NPCs
; ========================================

SpawnEnemy
; Spawn enemy at index 0 - Patrol/Chase AI with dialog
            ldx   #0*2              ; NPC index 0 (array offset = index*2)

            ; Mark active
            lda   #1
            sta   NPCActive,x

            ; Set world position (matches old InitEnemy)
            lda   #150
            sta   NPCGlobalX,x
            lda   #200
            sta   NPCGlobalY,x

            ; Set sprite IDs (16x16 enemy sprite)
            lda   #{SPRITE_16X16+145}
            sta   NPCTopSpriteID,x
            ; No bottom sprite for this enemy (single 16x16)

            ; Set VBUFF (NPC 0 uses VBUFF slot 3 - matches old ENEMY_VBUFF)
            lda   #VBUFF_SPRITE_START+3*VBUFF_SPRITE_STEP
            sta   NPCTopVBuff,x

            ; Set sprite flags
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x

            ; Set type and behavior
            lda   #NPC_FRIENDLY     ; Friendly (triggers dialog)
            sta   NPCBehavior,x
            lda   #0                ; Character ID 0
            sta   NPCCharacterID,x

            ; Set AI: Patrol with chase behavior
            lda   #AI_PATROL
            sta   NPCAIType,x
            lda   #1                ; Patrol speed
            sta   NPCSpeed,x
            lda   #100              ; Patrol min X
            sta   NPCPatrolMin,x
            lda   #350              ; Patrol max X
            sta   NPCPatrolMax,x
            stz   NPCDirection,x    ; Start moving left
            stz   NPCState,x        ; Start in patrol mode (0)

            ; Create top sprite stamp
            pea   {SPRITE_16X16+145}
            lda   NPCTopVBuff,x
            pha
            _GTECreateSpriteStamp

            ; Compile top sprite
            pha                     ; Space for result
            pea   SPRITE_16X16
            lda   NPCTopVBuff,x
            pha
            _GTECompileSpriteStamp
            pla
            sta   NPCTopAddr,x

            ; Calculate screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add sprite (NPC 0 uses slot 2 - matches old ENEMY_SLOT_1)
            pea   2                 ; Slot 2
            lda   NPCTopFlags,x
            pha
            lda   NPCTopAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEAddSprite

            rts

; Spawn NPC 1 - Hostile enemy (patrol)
SpawnNPC1
; Example hostile NPC with patrol AI
            ldx   #1*2              ; NPC index 1

            lda   #1
            sta   NPCActive,x

            ; Position
            lda   #600
            sta   NPCGlobalX,x
            lda   #300
            sta   NPCGlobalY,x

            ; Sprites
            lda   #{SPRITE_16X16+145}
            sta   NPCTopSpriteID,x
            lda   #{SPRITE_16X8+65}
            sta   NPCBotSpriteID,x

            ; VBUFFs (NPC 1 uses VBUFF slots 12-13)
            lda   #VBUFF_SPRITE_START+12*VBUFF_SPRITE_STEP
            sta   NPCTopVBuff,x
            lda   #VBUFF_SPRITE_START+13*VBUFF_SPRITE_STEP
            sta   NPCBotVBuff,x

            ; Flags
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x
            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   NPCBotFlags,x

            ; Type: Hostile enemy
            lda   #NPC_HOSTILE
            sta   NPCBehavior,x

            ; Combat stats
            lda   #10               ; 10 HP
            sta   NPCHealth,x
            sta   NPCMaxHealth,x
            lda   #1                ; 1 damage per hit
            sta   NPCDamage,x

            ; AI: Patrol
            lda   #AI_PATROL
            sta   NPCAIType,x
            lda   #1                ; Speed
            sta   NPCSpeed,x
            lda   #500              ; Patrol min
            sta   NPCPatrolMin,x
            lda   #700              ; Patrol max
            sta   NPCPatrolMax,x
            stz   NPCDirection,x    ; Start moving left

            ; Create sprites (same as NPC0 but with different VBUFFs/slots)
            pea   {SPRITE_16X16+145}
            lda   NPCTopVBuff,x
            pha
            _GTECreateSpriteStamp

            pha
            pea   SPRITE_16X16
            lda   NPCTopVBuff,x
            pha
            _GTECompileSpriteStamp
            pla
            sta   NPCTopAddr,x

            pea   {SPRITE_16X8+65}
            lda   NPCBotVBuff,x
            pha
            _GTECreateSpriteStamp

            pha
            pea   SPRITE_16X8
            lda   NPCBotVBuff,x
            pha
            _GTECompileSpriteStamp
            pla
            sta   NPCBotAddr,x

            ; Screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add sprites (NPC 1 uses slots 4,5)
            pea   4
            lda   NPCTopFlags,x
            pha
            lda   NPCTopAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEAddSprite

            pea   5
            lda   NPCBotFlags,x
            pha
            lda   NPCBotAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #16
            pha
            _GTEAddSprite

            rts

; ========================================
; UPDATE ALL NPCs
; ========================================

UpdateAllNPCs
            stz   CurrentNPCIndex

:loop
            ldx   CurrentNPCIndex

            ; Check if active
            lda   NPCActive,x
            bne   :active
            jmp   :next             ; Not active, skip to next NPC

:active
            ; Update screen position from scroll
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Update AI based on type
            lda   NPCAIType,x
            beq   :no_ai            ; AI_NONE
            cmp   #AI_PATROL
            beq   :do_patrol
            cmp   #AI_CHASE
            beq   :do_chase
            ; Add more AI types here
            bra   :no_ai

:do_patrol
            ; Patrol AI with chase detection (like old enemy)
            ; Check state: 0=patrol, 1=chase
            lda   NPCState,x
            beq   :patrol_mode

            ; In chase mode
            jsr   UpdateNPCChase
            ; Check if should return to patrol
            jsr   CalculateNPCDistance
            cmp   #ESCAPE_RANGE
            bcc   :stay_chase
            ; Return to patrol
            stz   NPCState,x
            lda   #1
            sta   NPCSpeed,x
            bra   :no_ai
:stay_chase
            bra   :no_ai

:patrol_mode
            ; In patrol mode
            jsr   UpdateNPCPatrol
            ; Check if should chase
            jsr   CalculateNPCDistance
            cmp   #DETECTION_RANGE
            bcs   :no_chase
            ; Enter chase mode
            lda   #1
            sta   NPCState,x
            lda   #1
            sta   NPCSpeed,x
:no_chase
            bra   :no_ai

:do_chase
            ; Pure chase AI (always chase player)
            jsr   UpdateNPCChase
            bra   :no_ai

:no_ai
            ; Validate screen coordinates before moving sprite
            ; Skip _GTEMoveSprite if offscreen (prevents crash)
            lda   NPCScreenX,x
            bmi   :next             ; Negative X (off left)
            cmp   #160
            bcs   :next             ; >= 160 (off right)
            lda   NPCScreenY,x
            bmi   :next             ; Negative Y (off top)
            cmp   #116
            bcs   :next             ; >= 116 (off bottom)

            ; Calculate sprite slot for this NPC
            ; Slot = NPC_SLOT_BASE + CurrentNPCIndex (since index is already *2)
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha                     ; Top sprite slot

            ; Move sprite (only top sprite for enemy)
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEMoveSprite

:next
            lda   CurrentNPCIndex
            clc
            adc   #2                ; Next NPC (2 bytes per entry)
            sta   CurrentNPCIndex
            cmp   #MAX_NPCS*2
            bcs   :done             ; If >= MAX_NPCS*2, exit
            jmp   :loop             ; Otherwise, loop back
:done
            rts

; ========================================
; AI BEHAVIORS
; ========================================

UpdateNPCPatrol
; Patrol AI - walk back and forth between PatrolMin and PatrolMax
; CurrentNPCIndex must be set, X = CurrentNPCIndex
            lda   NPCFrameCount,x
            inc
            sta   NPCFrameCount,x
            and   #$0003
            beq   :do_patrol
            rts

:do_patrol
            lda   NPCDirection,x
            bne   :moving_right

:moving_left
            lda   NPCGlobalX,x
            sec
            sbc   NPCSpeed,x
            cmp   NPCPatrolMin,x
            bcs   :set_left_pos

            ; Hit minimum - reverse direction
            lda   NPCPatrolMin,x
            sta   NPCGlobalX,x
            lda   #1
            sta   NPCDirection,x
            rts

:set_left_pos
            sta   NPCGlobalX,x
            rts

:moving_right
            lda   NPCGlobalX,x
            clc
            adc   NPCSpeed,x
            cmp   NPCPatrolMax,x
            bcc   :set_right_pos
            beq   :set_right_pos

            ; Hit maximum - reverse direction
            lda   NPCPatrolMax,x
            sta   NPCGlobalX,x
            stz   NPCDirection,x
            rts

:set_right_pos
            sta   NPCGlobalX,x
            rts

UpdateNPCChase
; Chase AI - move toward player position
; CurrentNPCIndex must be set, X = CurrentNPCIndex
            ; Throttle chase movement (every 2 frames)
            lda   NPCFrameCount,x
            inc
            sta   NPCFrameCount,x
            and   #$0001
            beq   :do_chase
            rts

:do_chase
            ; Calculate abs deltas for both axes
            lda   PlayerGlobalX
            sec
            sbc   NPCGlobalX,x
            bpl   :pos_dx
            eor   #$FFFF
            inc
:pos_dx
            sta   NPCTmp0           ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   NPCGlobalY,x
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            sta   NPCTmp1           ; abs(deltaY)

            ; Compare: move in axis with larger distance
            lda   NPCTmp0
            cmp   NPCTmp1
            bcs   :move_x           ; abs(deltaX) >= abs(deltaY), move in X

:move_y
            ; Move in Y direction
            lda   PlayerGlobalY
            sec
            sbc   NPCGlobalY,x
            beq   :done             ; Already aligned
            bmi   :chase_up

:chase_down
            lda   NPCGlobalY,x
            clc
            adc   NPCSpeed,x
            cmp   #640              ; World boundary
            bcc   :set_y
            lda   #639
:set_y
            sta   NPCGlobalY,x
            bra   :done

:chase_up
            lda   NPCGlobalY,x
            sec
            sbc   NPCSpeed,x
            bpl   :set_y
            lda   #0
            sta   NPCGlobalY,x
            bra   :done

:move_x
            ; Move in X direction
            lda   PlayerGlobalX
            sec
            sbc   NPCGlobalX,x
            beq   :done             ; Already aligned
            bmi   :chase_left

:chase_right
            lda   NPCGlobalX,x
            clc
            adc   NPCSpeed,x
            cmp   #960              ; World boundary
            bcc   :set_x
            lda   #959
:set_x
            sta   NPCGlobalX,x
            bra   :done

:chase_left
            lda   NPCGlobalX,x
            sec
            sbc   NPCSpeed,x
            bpl   :set_x
            lda   #0
            sta   NPCGlobalX,x

:done
            rts

CalculateNPCDistance
; Calculate Manhattan distance between player and current NPC
; Returns distance in A
; CurrentNPCIndex must be set, X = CurrentNPCIndex
            lda   PlayerGlobalX
            sec
            sbc   NPCGlobalX,x
            bpl   :pos_dx
            eor   #$FFFF            ; Two's complement
            inc
:pos_dx
            sta   NPCTmp2           ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   NPCGlobalY,x
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            clc
            adc   NPCTmp2           ; abs(deltaY) + abs(deltaX)
            rts

; ========================================
; COLLISION DETECTION
; ========================================

CheckAllNPCCollisions
            stz   CurrentNPCIndex

:loop
            ldx   CurrentNPCIndex

            ; Check if active
            lda   NPCActive,x
            beq   :next

            ; Check collision with player
            jsr   CalculateNPCDistance
            cmp   #16               ; Collision threshold
            bcs   :no_collision

            ; Colliding now - check if we were colliding last frame
            lda   NPCWasColliding,x
            bne   :mark_colliding       ; Was already colliding, don't re-trigger

            ; New collision! Check NPC type
            lda   NPCBehavior,x
            beq   :friendly_npc
            bra   :hostile_npc

:friendly_npc
            ; Trigger dialog for friendly NPCs
            lda   DialogState
            bne   :skip_trigger     ; Dialog already active

            ; Trigger dialogs (enemy NPC has 3 dialogs)
            lda   #Dialog1Lines
            ldx   #2                ; 2 lines
            jsr   TriggerMultiLineDialog

            lda   #Dialog2Lines
            ldx   #3                ; 3 lines
            jsr   TriggerMultiLineDialog

            lda   #Dialog3Lines
            ldx   #2                ; 2 lines
            jsr   TriggerMultiLineDialog

:skip_trigger
            ldx   CurrentNPCIndex
            bra   :mark_colliding

:hostile_npc
            ; TODO: Damage player
            ; For now, just mark collision
            bra   :mark_colliding

:mark_colliding
            lda   #1
            sta   NPCWasColliding,x
            bra   :next

:no_collision
            stz   NPCWasColliding,x

:next
            lda   CurrentNPCIndex
            clc
            adc   #2
            sta   CurrentNPCIndex
            cmp   #MAX_NPCS*2
            bcc   :loop

            rts

; ========================================
; DIALOG DATA (from old Enemy.s)
; ========================================

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
