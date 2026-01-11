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
            stz   NPCPatrolDir,x
            stz   NPCFrameCount,x
            stz   NPCDirection,x
            stz   NPCFrame,x
            stz   NPCAnimTimer,x
            stz   NPCWasColliding,x
            inx
            inx
            cpx   #MAX_NPCS*2
            bcc   :clear

            ; Spawn the enemy (now as NPC 0)
            jsr   SpawnEnemy

            ; Spawn NPC 1
            jsr   SpawnNPC1

            ; Spawn NPC 2 (reuses NPC 0's VBUFFs - same appearance)
            jsr   SpawnNPC2

            rts

; ========================================
; NPC SPRITE INITIALIZATION
; ========================================

InitNPC0Sprites
; Initialize all sprite frames for NPC 0
; Input: A = base tile ID (e.g., 145 for enemy slime)
; Tile layout: Down 0,2 Left 4,6 Up 8,10 (top); +64 for bottom
; Compiles 12 frames total (2 per direction × 3 directions × 2 sprites)
            sta   NPCTmp0           ; Save base tile ID
            ldx   #0*2              ; NPC index 0

; Down Frame 0 - Top
            lda   NPCTmp0           ; Base tile (e.g., 145)
            ora   #SPRITE_16X16
            pha
            pea   NPC0_DOWN_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_DOWN_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCDownTopCompiled0,x

; Down Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #64               ; Bottom tile = top + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_DOWN_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_DOWN_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCDownBotCompiled0,x

; Down Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #2                ; Frame 1 = base + 2
            ora   #SPRITE_16X16
            pha
            pea   NPC0_DOWN_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_DOWN_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCDownTopCompiled1,x

; Down Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #66               ; Frame 1 bottom = base + 2 + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_DOWN_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_DOWN_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCDownBotCompiled1,x

; Left Frame 0 - Top
            lda   NPCTmp0
            clc
            adc   #4                ; Left = base + 4
            ora   #SPRITE_16X16
            pha
            pea   NPC0_LEFT_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_LEFT_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCLeftTopCompiled0,x

; Left Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #68               ; Left bottom = base + 4 + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_LEFT_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_LEFT_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCLeftBotCompiled0,x

; Left Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #6                ; Left frame 1 = base + 6
            ora   #SPRITE_16X16
            pha
            pea   NPC0_LEFT_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_LEFT_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCLeftTopCompiled1,x

; Left Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #70               ; Left frame 1 bottom = base + 6 + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_LEFT_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_LEFT_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCLeftBotCompiled1,x

; Up Frame 0 - Top
            lda   NPCTmp0
            clc
            adc   #8                ; Up = base + 8
            ora   #SPRITE_16X16
            pha
            pea   NPC0_UP_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_UP_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCUpTopCompiled0,x

; Up Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #72               ; Up bottom = base + 8 + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_UP_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_UP_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCUpBotCompiled0,x

; Up Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #10               ; Up frame 1 = base + 10
            ora   #SPRITE_16X16
            pha
            pea   NPC0_UP_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC0_UP_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCUpTopCompiled1,x

; Up Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #74               ; Up frame 1 bottom = base + 10 + 64
            ora   #SPRITE_16X8
            pha
            pea   NPC0_UP_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC0_UP_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #0*2
            sta   NPCUpBotCompiled1,x

            rts

InitNPC1Sprites
; Initialize all sprite frames for NPC 1
; Input: A = base tile ID (e.g., 333 for second NPC)
; Tile layout: Down 0,2 Left 4,6 Up 8,10 (top); +64 for bottom
; Compiles 12 frames total (2 per direction × 3 directions × 2 sprites)
            sta   NPCTmp0           ; Save base tile ID
            ldx   #1*2              ; NPC index 1

; Down Frame 0 - Top
            lda   NPCTmp0           ; Base tile (e.g., 333)
            ora   #SPRITE_16X16
            pha
            pea   NPC1_DOWN_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_DOWN_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCDownTopCompiled0,x

; Down Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #64
            ora   #SPRITE_16X8
            pha
            pea   NPC1_DOWN_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_DOWN_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCDownBotCompiled0,x

; Down Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #2
            ora   #SPRITE_16X16
            pha
            pea   NPC1_DOWN_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_DOWN_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCDownTopCompiled1,x

; Down Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #66
            ora   #SPRITE_16X8
            pha
            pea   NPC1_DOWN_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_DOWN_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCDownBotCompiled1,x

; Left Frame 0 - Top
            lda   NPCTmp0
            clc
            adc   #4
            ora   #SPRITE_16X16
            pha
            pea   NPC1_LEFT_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_LEFT_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCLeftTopCompiled0,x

; Left Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #68
            ora   #SPRITE_16X8
            pha
            pea   NPC1_LEFT_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_LEFT_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCLeftBotCompiled0,x

; Left Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #6
            ora   #SPRITE_16X16
            pha
            pea   NPC1_LEFT_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_LEFT_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCLeftTopCompiled1,x

; Left Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #70
            ora   #SPRITE_16X8
            pha
            pea   NPC1_LEFT_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_LEFT_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCLeftBotCompiled1,x

; Up Frame 0 - Top
            lda   NPCTmp0
            clc
            adc   #8
            ora   #SPRITE_16X16
            pha
            pea   NPC1_UP_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_UP_TOP_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCUpTopCompiled0,x

; Up Frame 0 - Bottom
            lda   NPCTmp0
            clc
            adc   #72
            ora   #SPRITE_16X8
            pha
            pea   NPC1_UP_BOT_VBUFF_0
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_UP_BOT_VBUFF_0
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCUpBotCompiled0,x

; Up Frame 1 - Top
            lda   NPCTmp0
            clc
            adc   #10
            ora   #SPRITE_16X16
            pha
            pea   NPC1_UP_TOP_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X16
            pea   NPC1_UP_TOP_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCUpTopCompiled1,x

; Up Frame 1 - Bottom
            lda   NPCTmp0
            clc
            adc   #74
            ora   #SPRITE_16X8
            pha
            pea   NPC1_UP_BOT_VBUFF_1
            _GTECreateSpriteStamp
            pha
            pea   SPRITE_16X8
            pea   NPC1_UP_BOT_VBUFF_1
            _GTECompileSpriteStamp
            pla
            ldx   #1*2
            sta   NPCUpBotCompiled1,x

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
            lda   #80
            sta   NPCGlobalX,x
            lda   #60
            sta   NPCGlobalY,x

            ; Initialize animation state (NEW)
            lda   #DIR_DOWN
            sta   NPCDirection,x
            stz   NPCFrame,x        ; Start at frame 0
            stz   NPCAnimTimer,x    ; Reset timer

            ; Set type and behavior
            lda   #NPC_HOSTILE     ; Friendly (triggers dialog)
            sta   NPCBehavior,x
            stz   NPCCharacterID,x

            ; Set AI: Patrol with chase behavior
            lda   #AI_PATROL
            sta   NPCAIType,x
            lda   #1                ; Patrol speed
            sta   NPCSpeed,x
            lda   #100              ; Patrol min X
            sta   NPCPatrolMin,x
            lda   #350              ; Patrol max X
            sta   NPCPatrolMax,x
            stz   NPCPatrolDir,x    ; Start moving left
            stz   NPCState,x        ; Start in patrol mode (0)

            ; Initialize sprites for this NPC (NEW - compiles all 12 frames)
            lda   #139              ; Base tile ID for enemy slime
            jsr   InitNPC0Sprites

            ; Set sprite flags for 16x24 sprite
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x
            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   NPCBotFlags,x

            ; Set initial sprite addresses from compiled arrays (Down frame 0)
            lda   NPCDownTopCompiled0,x
            sta   NPCTopAddr,x
            lda   NPCDownBotCompiled0,x
            sta   NPCBotAddr,x

            ; Calculate screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add top sprite (NPC 0 uses slot 2)
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

            ; Add bottom sprite (NPC 0 uses slot 3) - NEW
            pea   3                 ; Slot 3
            lda   NPCBotFlags,x
            pha
            lda   NPCBotAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #15               ; Y offset for bottom sprite
            pha
            _GTEAddSprite

            rts

; Spawn NPC 1 - Man (patrol)
SpawnNPC1
; Spawn NPC 1 - Patrol AI with animation
            ldx   #1*2              ; NPC index 1

            ; Mark active
            lda   #1
            sta   NPCActive,x

            ; Set world position
            lda   #80
            sta   NPCGlobalX,x
            lda   #80
            sta   NPCGlobalY,x

            ; Initialize animation state
            lda   #DIR_DOWN
            sta   NPCDirection,x
            stz   NPCFrame,x
            stz   NPCAnimTimer,x

            ; Set type and behavior
            lda   #NPC_FRIENDLY
            sta   NPCBehavior,x
            lda   #3
            sta   NPCCharacterID,x

            ; Combat stats
            lda   #10
            sta   NPCHealth,x
            sta   NPCMaxHealth,x
            lda   #3                ; 3 damage per hit
            sta   NPCDamage,x

            ; Set AI: Patrol
            lda   #AI_PATROL
            sta   NPCAIType,x
            lda   #1                ; Patrol speed
            sta   NPCSpeed,x
            lda   #40               ; Patrol min X (near spawn at 80)
            sta   NPCPatrolMin,x
            lda   #120              ; Patrol max X (visible on screen)
            sta   NPCPatrolMax,x
            stz   NPCPatrolDir,x    ; Start moving left
            stz   NPCState,x        ; Start in patrol mode

            ; Initialize sprites for NPC 1 (compiles all 12 frames)
            lda   #333              ; Base tile ID
            jsr   InitNPC1Sprites

            ; reset x to index 1 * array stride
            ldx   #1*2

            ; Set sprite flags for 16x24 sprite
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x
            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   NPCBotFlags,x

            ; Set initial sprite addresses from compiled arrays (Down frame 0)
            lda   NPCDownTopCompiled0,x
            sta   NPCTopAddr,x
            lda   NPCDownBotCompiled0,x
            sta   NPCBotAddr,x

            ; Calculate screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add top sprite (NPC 1 uses slot 4)
            pea   4                 ; Slot 4
            lda   NPCTopFlags,x
            pha
            lda   NPCTopAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEAddSprite

            ldx #1*2

            ; Add bottom sprite (NPC 1 uses slot 5)
            pea   5                 ; Slot 5
            lda   NPCBotFlags,x
            pha
            lda   NPCBotAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #15               ; Y offset for bottom sprite
            pha
            _GTEAddSprite

            rts

SpawnNPC2
; Spawn NPC 2 - REUSES NPC 0's VBUFFs (same appearance as NPC 0)
            ldx   #2*2              ; NPC index 2 (array offset = 2*2 = 4)

            ; Mark active
            lda   #1
            sta   NPCActive,x

            ; Set world position (near player)
            lda   #100
            sta   NPCGlobalX,x
            lda   #120
            sta   NPCGlobalY,x

            ; Initialize animation state
            lda   #DIR_DOWN
            sta   NPCDirection,x
            stz   NPCFrame,x
            stz   NPCAnimTimer,x

            ; Set type and behavior
            lda   #NPC_FRIENDLY     ; Friendly NPC
            sta   NPCBehavior,x
            lda   #2                ; Character ID 2 (Merchant)
            sta   NPCCharacterID,x

            ; Combat stats
            lda   #10
            sta   NPCHealth,x
            sta   NPCMaxHealth,x
            lda   #3                ; 3 damage per hit
            sta   NPCDamage,x

            ; Set AI: Patrol
            lda   #AI_PATROL
            sta   NPCAIType,x
            lda   #1                ; Patrol speed
            sta   NPCSpeed,x
            lda   #60               ; Patrol min X
            sta   NPCPatrolMin,x
            lda   #140              ; Patrol max X
            sta   NPCPatrolMax,x
            stz   NPCPatrolDir,x    ; Start moving left
            stz   NPCState,x        ; Start in patrol mode

            ; REUSE NPC 0's compiled sprites (no InitNPC2Sprites call!)
            ; Copy compiled addresses from NPC 0 (index 0*2 = 0)
            ldy   #0*2              ; NPC 0 index
            lda   NPCDownTopCompiled0,y
            sta   NPCDownTopCompiled0,x
            lda   NPCDownTopCompiled1,y
            sta   NPCDownTopCompiled1,x
            lda   NPCDownBotCompiled0,y
            sta   NPCDownBotCompiled0,x
            lda   NPCDownBotCompiled1,y
            sta   NPCDownBotCompiled1,x

            lda   NPCLeftTopCompiled0,y
            sta   NPCLeftTopCompiled0,x
            lda   NPCLeftTopCompiled1,y
            sta   NPCLeftTopCompiled1,x
            lda   NPCLeftBotCompiled0,y
            sta   NPCLeftBotCompiled0,x
            lda   NPCLeftBotCompiled1,y
            sta   NPCLeftBotCompiled1,x

            lda   NPCUpTopCompiled0,y
            sta   NPCUpTopCompiled0,x
            lda   NPCUpTopCompiled1,y
            sta   NPCUpTopCompiled1,x
            lda   NPCUpBotCompiled0,y
            sta   NPCUpBotCompiled0,x
            lda   NPCUpBotCompiled1,y
            sta   NPCUpBotCompiled1,x

            ; Set sprite flags for 16x24 sprite
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x
            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   NPCBotFlags,x

            ; Set initial sprite addresses (Down frame 0)
            lda   NPCDownTopCompiled0,x
            sta   NPCTopAddr,x
            lda   NPCDownBotCompiled0,x
            sta   NPCBotAddr,x

            ; Calculate screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add top sprite (NPC 2 uses slot 6 - different from NPC 0's slot 2)
            pea   6                 ; Slot 6
            lda   NPCTopFlags,x
            pha
            lda   NPCTopAddr,x      ; Same VBUFF as NPC 0
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEAddSprite

            ldx   #2*2

            ; Add bottom sprite (NPC 2 uses slot 7 - different from NPC 0's slot 3)
            pea   7                 ; Slot 7
            lda   NPCBotFlags,x
            pha
            lda   NPCBotAddr,x      ; Same VBUFF as NPC 0
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #15               ; Y offset for bottom sprite
            pha
            _GTEAddSprite

            rts

; ========================================
; NPC ANIMATION UPDATE
; ========================================

UpdateNPCAnimation
; Updates animation for all active NPCs
; Called once per frame from game loop
            stz   CurrentNPCIndex

:loop
            ldx   CurrentNPCIndex

            ; Check if active
            lda   NPCActive,x
            beq   :next

            ; Update animation timer (advance every 4 frames for slower animation)
            lda   NPCAnimTimer,x
            inc   a
            cmp   #4                ; Slower than Player (2 frames only)
            bcc   :no_frame_change

            ; Reset timer and toggle frame (0 ↔ 1)
            lda   #0
            sta   NPCAnimTimer,x
            lda   NPCFrame,x
            eor   #1                ; Toggle between 0 and 1
            sta   NPCFrame,x
            bra   :update_sprites

:no_frame_change
            sta   NPCAnimTimer,x

:update_sprites
            ; Always update sprite graphics (handles direction AND frame changes)
            jsr   UpdateNPCSprites

:next
            lda   CurrentNPCIndex
            clc
            adc   #2
            sta   CurrentNPCIndex
            cmp   #MAX_NPCS*2
            bcs   :done
            jmp   :loop
:done
            rts

UpdateNPCSprites
; Updates sprite graphics based on current direction and frame
; X = CurrentNPCIndex on entry (NPC being processed)
; Supports NPC 0 and NPC 1

            ; Only handle NPC 0 and 1 (indices 0 and 2)
            cpx   #6
            bcs   :skip_update

            ; Get direction and jump to handler (use short branches)
            lda   NPCDirection,x
            beq   :go_down
            cmp   #1
            beq   :go_right
            cmp   #2
            beq   :go_left
            cmp   #3
            beq   :go_up
            rts                     ; Invalid direction, exit

:go_down    jmp   NPCHandleDown
:go_left    jmp   NPCHandleLeft
:go_right   jmp   NPCHandleRight
:go_up      jmp   NPCHandleUp

:skip_update
            rts

; Direction: Down
NPCHandleDown
            ldx   CurrentNPCIndex
            lda   NPCFrame,x        ; 0 or 1
            beq   :dframe0

:dframe1
            ; Update to frame 1 - calculate sprite slot dynamically
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha                     ; Top sprite slot
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCDownTopCompiled1,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex

            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha                     ; Bottom sprite slot
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCDownBotCompiled1,x
            pha
            _GTEUpdateSprite
            rts

:dframe0
            ; Update to frame 0
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCDownTopCompiled0,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCDownBotCompiled0,x
            pha
            _GTEUpdateSprite
            rts

; Direction: Right (uses Left frames with HFLIP)
NPCHandleRight
            ldx   CurrentNPCIndex
            lda   NPCFrame,x
            beq   :rframe0

:rframe1
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftTopCompiled1,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftBotCompiled1,x
            pha
            _GTEUpdateSprite
            rts

:rframe0
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftTopCompiled0,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED+SPRITE_HFLIP
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftBotCompiled0,x
            pha
            _GTEUpdateSprite
            rts

; Direction: Left
NPCHandleLeft
            ldx   CurrentNPCIndex
            lda   NPCFrame,x
            beq   :lframe0

:lframe1
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftTopCompiled1,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftBotCompiled1,x
            pha
            _GTEUpdateSprite
            rts

:lframe0
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftTopCompiled0,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCLeftBotCompiled0,x
            pha
            _GTEUpdateSprite
            rts

; Direction: Up
NPCHandleUp
            ldx   CurrentNPCIndex
            lda   NPCFrame,x
            beq   :uframe0

:uframe1
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCUpTopCompiled1,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCUpBotCompiled1,x
            pha
            _GTEUpdateSprite
            rts

:uframe0
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCUpTopCompiled0,x
            pha
            _GTEUpdateSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            ldx   CurrentNPCIndex
            lda   NPCUpBotCompiled0,x
            pha
            _GTEUpdateSprite
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
            ; NPCDirection is set by AI functions (patrol/chase)
            ; Check if sprite is on screen or needs to be moved off-screen
            lda   NPCScreenX,x
            bmi   :move_offscreen   ; Negative X (off left)
            cmp   #160
            bcs   :move_offscreen   ; >= 160 (off right)
            lda   NPCScreenY,x
            bmi   :move_offscreen   ; Negative Y (off top)
            cmp   #116
            bcs   :move_offscreen   ; >= 116 (off bottom)

            ; Sprite is on screen - move to actual position
:move_onscreen
            ; Calculate sprite slot for this NPC
            ; Slot = NPC_SLOT_BASE + CurrentNPCIndex (since index is already *2)
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha                     ; Top sprite slot

            ; Move top sprite to actual position
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEMoveSprite

            ; Move bottom sprite to actual position
            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1  ; Bottom sprite = top + 1
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #15               ; Y offset for bottom sprite
            pha
            _GTEMoveSprite
            bra   :next

:move_offscreen
            ; Sprite is off screen - move to safe off-screen position
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha                     ; Top sprite slot
            pea   200               ; Off-screen X
            pea   200               ; Off-screen Y
            _GTEMoveSprite

            ; Move bottom sprite off-screen too
            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            pea   200               ; Off-screen X
            pea   200               ; Off-screen Y
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
            lda   NPCPatrolDir,x
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
            sta   NPCPatrolDir,x
            lda   #DIR_RIGHT        ; Set animation direction
            sta   NPCDirection,x
            rts

:set_left_pos
            sta   NPCGlobalX,x
            lda   #DIR_LEFT         ; Set animation direction
            sta   NPCDirection,x
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
            stz   NPCPatrolDir,x
            lda   #DIR_LEFT         ; Set animation direction
            sta   NPCDirection,x
            rts

:set_right_pos
            sta   NPCGlobalX,x
            lda   #DIR_RIGHT        ; Set animation direction
            sta   NPCDirection,x
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
            bcc   :set_y_down
            lda   #639
:set_y_down
            sta   NPCGlobalY,x
            lda   #DIR_DOWN         ; Set animation direction
            sta   NPCDirection,x
            bra   :done

:chase_up
            lda   NPCGlobalY,x
            sec
            sbc   NPCSpeed,x
            bpl   :set_y_up
            lda   #0
:set_y_up
            sta   NPCGlobalY,x
            lda   #DIR_UP           ; Set animation direction
            sta   NPCDirection,x
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
            bcc   :set_x_right
            lda   #959
:set_x_right
            sta   NPCGlobalX,x
            lda   #DIR_RIGHT        ; Set animation direction
            sta   NPCDirection,x
            bra   :done

:chase_left
            lda   NPCGlobalX,x
            sec
            sbc   NPCSpeed,x
            bpl   :set_x_left
            lda   #0
:set_x_left
            sta   NPCGlobalX,x
            lda   #DIR_LEFT         ; Set animation direction
            sta   NPCDirection,x

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
            ; Trigger dialog for friendly NPCs using lookup table
            lda   DialogState
            bne   :skip_trigger     ; Dialog already active

            ; Get character ID from NPC
            ldx   CurrentNPCIndex
            lda   NPCCharacterID,x
            beq   :skip_trigger     ; Character ID 0 = no dialog

            ; Look up character dialog info
            ; CharacterDialogTable is indexed by Character ID * 2 (word pointers)
            asl   a                 ; × 2 for word offset
            tay
            lda   CharacterDialogTable,y
            sta   Tmp0              ; Tmp0 = pointer to character dialog info

            ; Trigger Dialog 1
            ldy   #0                ; Offset 0: Dialog 1 line count
            lda   (Tmp0),y
            beq   :skip_d1          ; Skip if 0 lines
            tax                     ; X = line count
            ldy   #2                ; Offset 2: Dialog 1 lines pointer
            lda   (Tmp0),y
            jsr   TriggerMultiLineDialog

:skip_d1
            ; Trigger Dialog 2
            ldy   #4                ; Offset 4: Dialog 2 line count
            lda   (Tmp0),y
            beq   :skip_d2          ; Skip if 0 lines
            tax                     ; X = line count
            ldy   #6                ; Offset 6: Dialog 2 lines pointer
            lda   (Tmp0),y
            jsr   TriggerMultiLineDialog

:skip_d2
            ; Trigger Dialog 3
            ldy   #8                ; Offset 8: Dialog 3 line count
            lda   (Tmp0),y
            beq   :skip_d3          ; Skip if 0 lines
            tax                     ; X = line count
            ldy   #10               ; Offset 10: Dialog 3 lines pointer
            lda   (Tmp0),y
            jsr   TriggerMultiLineDialog

:skip_d3
:skip_trigger
            ldx   CurrentNPCIndex
            bra   :mark_colliding

:hostile_npc
            ; Hostile NPC - deal damage to player (knockback handled in TakeDamage)
            ldx   CurrentNPCIndex
            lda   NPCDamage,x        ; Get NPC's damage
            jsr   TakeDamage         ; Player takes damage and knockback (X preserved)
            ldx   CurrentNPCIndex    ; Restore X to be safe
            ; Fall through to mark collision

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
            bcs   :done              ; If >= MAX_NPCS*2, exit
            brl   :loop              ; Otherwise continue (long branch)

:done       rts

; ========================================
; DIALOG DATA - Character-based lookup system
; ========================================

; Character Dialog Lookup Table
; Maps Character ID (0-based) to dialog info structure
; Each entry: 2 bytes = address of character dialog info

CharacterDialogTable
            dw   Character0DialogInfo    ; Character ID 0 (not used)
            dw   Character1DialogInfo    ; Character ID 1 (Guardian)
            dw   Character2DialogInfo    ; Character ID 2 (Merchant)
            dw   Character3DialogInfo    ; Character ID 3 (Child)
            ; Add more as needed

; Character Dialog Info Structure (6 bytes each):
; +0: Dialog 1 line count (word)
; +2: Dialog 1 lines pointer (word)
; +4: Dialog 2 line count (word)
; +6: Dialog 2 lines pointer (word)
; +8: Dialog 3 line count (word)
; +10: Dialog 3 lines pointer (word)

Character0DialogInfo
            dw   0, 0              ; No dialog
            dw   0, 0              ; No dialog
            dw   0, 0              ; No dialog

Character1DialogInfo
            dw   2, Dialog1_C1Lines    ; Dialog 1: 2 lines
            dw   3, Dialog2_C1Lines    ; Dialog 2: 3 lines
            dw   2, Dialog3_C1Lines    ; Dialog 3: 2 lines

Character2DialogInfo
            dw   2, Dialog1_C2Lines    ; Dialog 1: 2 lines
            dw   2, Dialog2_C2Lines    ; Dialog 2: 2 lines
            dw   2, Dialog3_C2Lines    ; Dialog 3: 2 lines

Character3DialogInfo
            dw   1, Dialog1_C3Lines    ; Dialog 1: 1 line
            dw   2, Dialog2_C3Lines    ; Dialog 2: 2 lines
            dw   1, Dialog3_C3Lines    ; Dialog 3: 1 line

; ========================================
; CHARACTER 1 DIALOGS (Village Guardian)
; ========================================

; Dialog 1 - Greeting (2 lines)
Dialog1_C1Lines     dw   D1_C1_Line1, D1_C1_Line2
D1_C1_Line1         str  'WELCOME TO'
D1_C1_Line2         str  'LANCE VILLAGE!'

; Dialog 2 - Introduction (3 lines)
Dialog2_C1Lines     dw   D2_C1_Line1, D2_C1_Line2, D2_C1_Line3
D2_C1_Line1         str  'I AM THE VILLAGE'
D2_C1_Line2         str  'GUARDIAN. I WATCH OVER'
D2_C1_Line3         str  'THIS PEACEFUL PLACE.'

; Dialog 3 - Farewell (2 lines)
Dialog3_C1Lines     dw   D3_C1_Line1, D3_C1_Line2
D3_C1_Line1         str  'ENJOY YOUR STAY'
D3_C1_Line2         str  'AND BE SAFE!'

; ========================================
; CHARACTER 2 DIALOGS (Merchant)
; ========================================

; Dialog 1 - Greeting (2 lines)
Dialog1_C2Lines     dw   D1_C2_Line1, D1_C2_Line2
D1_C2_Line1         str  'HELLO TRAVELER!'
D1_C2_Line2         str  'CARE TO BROWSE?'

; Dialog 2 - Sales pitch (2 lines)
Dialog2_C2Lines     dw   D2_C2_Line1, D2_C2_Line2
D2_C2_Line1         str  'I HAVE THE FINEST'
D2_C2_Line2         str  'WARES IN THE LAND!'

; Dialog 3 - Farewell (2 lines)
Dialog3_C2Lines     dw   D3_C2_Line1, D3_C2_Line2
D3_C2_Line1         str  'COME BACK SOON!'
D3_C2_Line2         str  'GOOD PRICES HERE!'

; ========================================
; CHARACTER 3 DIALOGS (Child)
; ========================================

; Dialog 1 - Greeting (1 line)
Dialog1_C3Lines     dw   D1_C3_Line1
D1_C3_Line1         str  'HI MISTER!'

; Dialog 2 - Question (2 lines)
Dialog2_C3Lines     dw   D2_C3_Line1, D2_C3_Line2
D2_C3_Line1         str  'ARE YOU AN'
D2_C3_Line2         str  'ADVENTURER?'

; Dialog 3 - Farewell (1 line)
Dialog3_C3Lines     dw   D3_C3_Line1
D3_C3_Line1         str  'BYE BYE!'
