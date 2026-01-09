            REL
            DSK   MAINSEG

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs

            mx    %00

LanceVillageTiles  EXT                 ; tileset buffer
LanceVillagePalette EXT              ; palette from tileset

; Direct page variables
ScreenX       equ 0
ScreenY       equ 2
ScreenWidth   equ 4
ScreenHeight  equ 6
frameCount    equ 8
PlayerX       equ 10
PlayerY       equ 12
PlayerSpeed equ 14
SpriteFlags equ 16
SpriteAddr  equ 18
PlayerGlobalX equ 20
PlayerGlobalY equ 22
PlayerScreenX equ 24
PlayerScreenY equ 26

EnemyGlobalX equ  28
EnemyGlobalY equ  30
EnemyScreenX equ  32
EnemyScreenY equ  34
EnemyState  equ 36      ; 0=patrol, 1=chase
EnemySpeed  equ 38      ; movement speed (1=patrol, 3 for chase)
EnemyPatrolMin equ  40
EnemyPatrolMax equ  42
EnemyPatrolY   equ  44    ; Y position for patrol mode
EnemyDirection equ  46    ;0=moving left, 1=right
EnemyFlags     equ  48
SpriteTmpAddr equ   50
EnemyFrameCount equ 52
AdolTmpAddr equ 54

PlayerDirection equ 56
PlayerFrame equ 58
PlayerAnimTimer equ 60

Tmp0    equ 62
Tmp1    equ 64
Tmp2    equ 66
Tmp3    equ 68
Tmp4    equ 70
Tmp5    equ 72

WasColliding equ  74    ; Previous frame collision state (0 = no, 1 = yes)


; Constants
DEADZONE_LEFT equ 54
DEADZONE_RIGHT equ 90
DEADZONE_TOP equ 50
DEADZONE_BOT equ 78
MAX_SCROLL_X equ 888       ; 960 - 72 (world width in X-units - screen width in X-units)
MAX_SCROLL_Y equ 512       ; 640 - 128 (world height in pixels - screen height)

MAX_SPRITES equ 16
PLAYER_SLOT equ 0
PLAYER_BOT_SLOT equ 1
PLAYER_SPRITE_ID equ {SPRITE_16X16+1}
PLAYER_SPRITE_BOT_ID equ {SPRITE_16X8+65}
; Animation VBUFFs - 9 frames (Down 0-2, Left 3-5, Up 6-8)
; Top sprite VBUFFs
DOWN_TOP_VBUFF_0   equ VBUFF_SPRITE_START+6*VBUFF_SPRITE_STEP
DOWN_TOP_VBUFF_1   equ VBUFF_SPRITE_START+7*VBUFF_SPRITE_STEP
DOWN_TOP_VBUFF_2   equ VBUFF_SPRITE_START+8*VBUFF_SPRITE_STEP
LEFT_TOP_VBUFF_0   equ VBUFF_SPRITE_START+9*VBUFF_SPRITE_STEP
LEFT_TOP_VBUFF_1   equ VBUFF_SPRITE_START+10*VBUFF_SPRITE_STEP
LEFT_TOP_VBUFF_2   equ VBUFF_SPRITE_START+11*VBUFF_SPRITE_STEP
UP_TOP_VBUFF_0     equ VBUFF_SPRITE_START+12*VBUFF_SPRITE_STEP
UP_TOP_VBUFF_1     equ VBUFF_SPRITE_START+13*VBUFF_SPRITE_STEP
UP_TOP_VBUFF_2     equ VBUFF_SPRITE_START+14*VBUFF_SPRITE_STEP

; Bottom sprite VBUFFs
DOWN_BOT_VBUFF_0   equ VBUFF_SPRITE_START+15*VBUFF_SPRITE_STEP
DOWN_BOT_VBUFF_1   equ VBUFF_SPRITE_START+16*VBUFF_SPRITE_STEP
DOWN_BOT_VBUFF_2   equ VBUFF_SPRITE_START+17*VBUFF_SPRITE_STEP
LEFT_BOT_VBUFF_0   equ VBUFF_SPRITE_START+18*VBUFF_SPRITE_STEP
LEFT_BOT_VBUFF_1   equ VBUFF_SPRITE_START+19*VBUFF_SPRITE_STEP
LEFT_BOT_VBUFF_2   equ VBUFF_SPRITE_START+20*VBUFF_SPRITE_STEP
UP_BOT_VBUFF_0     equ VBUFF_SPRITE_START+21*VBUFF_SPRITE_STEP
UP_BOT_VBUFF_1     equ VBUFF_SPRITE_START+22*VBUFF_SPRITE_STEP
UP_BOT_VBUFF_2     equ VBUFF_SPRITE_START+23*VBUFF_SPRITE_STEP

; Enemy
ENEMY_SLOT_1 equ  2
ENEMY_SPRITE_ID equ {SPRITE_16X16+145}
ENEMY_VBUFF equ VBUFF_SPRITE_START+3*VBUFF_SPRITE_STEP

; AI enum
STATE_PATROL equ  0
STATE_CHASE equ   1

; AI Behavior
ENEMY_SPEED_PATROL equ  1
ENEMY_SPEED_CHASE equ 1
DETECTION_RANGE equ 36      ; Start chasing when player within 36 pixels
ESCAPE_RANGE equ 60         ; Stop chasing when player > 60 pixels away (prevents oscillation)


; Keycodes
LEFT_ARROW    equ   $08
RIGHT_ARROW   equ   $15
UP_ARROW      equ   $0B
DOWN_ARROW    equ   $0A

; Player Direction enums
DIR_DOWN  equ 0
DIR_LEFT  equ 1
DIR_RIGHT   equ 2
DIR_UP    equ 3

ANIM_SPEED equ 8

Main
            phk
            plb

            bra :start
            dfb $AA,$BB,$CC,$DD       ; for finding this in the debugger

:start
            sta   MyUserId
            tdc
            sta   MyDirectPage

; Init vars
            lda   #80
            sta   PlayerGlobalX
            sta   PlayerScreenX

            lda   #100
            sta   PlayerGlobalY
            sta   PlayerScreenY            

            stz   ScreenX                ; Initialize scroll position X
            stz   ScreenY                ; Initialize scroll position Y

            stz   PlayerDirection
            stz   PlayerFrame
            stz   PlayerAnimTimer

            _MTStartUp

            lda   #ENGINE_MODE_USER_TOOL
            jsr   GTEStartUp

            * pea   #144
            * pea   #128
            pea   #7
            pea   #0
            _GTESetScreenMode

            pea   0
            pea   511
            pea   #^LanceVillageTiles
            pea   #LanceVillageTiles
            _GTELoadTileSet

; Set the palette
            pea   $0000
            pea   #^LanceVillagePalette
            pea   #LanceVillagePalette
            _GTESetPalette

            jsr   SetLimits

; Set up the tilemap on BG0
            jsr   BG0SetUp

; Init player position
            lda   #2
            sta   PlayerSpeed

; start player at world position
            lda   #32
            sta   PlayerGlobalX
            lda   #60
            sta   PlayerGlobalY

            stz   ScreenX
            stz   ScreenY

            jsr   UpdateCamera
            jsr   InitSprites
            jsr   InitDialog

:eventloop

            jsr   HandleInput
            jsr   UpdateCamera
            jsr   UpdatePlayerAnimation
            jsr   UpdateEnemy

            ; Check collision with enemy (triggers dialog if colliding)
            jsr   CheckEnemyCollision

; Move the sprite
            jsr   MovePlayer

            ; Enemy sprite is moved by UpdateEnemy, not here!

            pei   ScreenX               ; BG0 X-origin
            pei   ScreenY               ; BG0 Y-origin
            _GTESetBG0Origin

            pea   RENDER_WITH_SHADOWING ; Proper sprite rendering
            _GTERender

            jsr   DebugPrinter

            ; Check for dialog (pauses game if dialog is active)
            jsr   CheckAndShowDialog

            brl :eventloop

; Shut down everything
Exit
            _GTEShutDown
            _QuitGS qtRec
qtRec       adrl         $0000
            da         $00

; Called by StartUp function callbacks when the screen size changes
SetLimits
                pha                       ; Allocate space for x, y, width, height
                pha
                pha
                pha
                _GTEGetScreenInfo
                pla
                pla                       ; Discard screen corner
                pla
                sec
                sbc   #8
                sta   ScreenWidth         ; Pre-adjust to keep sprites on the visible playfield (for compiled sprites)
                pla
                sec
                sbc   #16
                sta   ScreenHeight
                rts

InitPlayerSpriteFrames
; Create and compile sprite stamps for 9 animation frames
; Each frame gets its own VBUFF to avoid overwriting

; Down Frame 0 - Top
            pea   SPRITE_16X16+1
            pea   DOWN_TOP_VBUFF_0
            _GTECreateSpriteStamp
            pha                          ; Space for result
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

; Add initial sprite (Down Frame 0) with compiled stamps
            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            lda   DownTopCompiled+0
            pha
            pei   PlayerScreenX
            pei   PlayerScreenY
            _GTEAddSprite

            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            lda   DownBotCompiled+0
            pha
            pei   PlayerScreenX
            lda   PlayerScreenY
            clc
            adc   #15
            pha
            _GTEAddSprite
            rts

InitSprites
* ; Create sprite stamp from tile data
*             pea   PLAYER_SPRITE_ID       ; Sprite tile ID (SPRITE_16X16+TileIndex)
*             pea   PLAYER_VBUFF     ; Virtual buffer address
*             _GTECreateSpriteStamp

* ; Compile the sprite for fast rendering
*             lda   #SPRITE_16X16+SPRITE_COMPILED
*             sta   SpriteFlags
*             pha                          ; Space for result
*             pea   SPRITE_16X16           ; Sprite size
*             pea   PLAYER_VBUFF     ; Source vbuff
*             _GTECompileSpriteStamp
*             pla
*             sta   SpriteAddr             ; Save compiled sprite address

* ; Add sprite to screen
*             pea   PLAYER_SLOT            ; Sprite slot 0
*             pei   SpriteFlags            ; Flags (SPRITE_16X16+SPRITE_COMPILED)
*             pei   SpriteAddr             ; Compiled sprite address
*             pei   PlayerScreenX                ; X position (80)
*             pei   PlayerScreenY                ; Y position (100)
*             _GTEAddSprite

* ; add bottom part of sprite (composite)
*             pea   PLAYER_SPRITE_BOT_ID       ; Sprite tile ID (SPRITE_16X16+TileIndex)
*             pea   PLAYER_BOT_VBUFF     ; Virtual buffer address
*             _GTECreateSpriteStamp

*             lda   #SPRITE_16X8+SPRITE_COMPILED
*             sta   SpriteFlags
*             pha
*             pea   SPRITE_16X8
*             pea   PLAYER_BOT_VBUFF
*             _GTECompileSpriteStamp
*             pla
*             sta   SpriteAddr

*             lda   PlayerScreenY
*             clc
*             adc   #15

*             pea   PLAYER_BOT_SLOT
*             pei   SpriteFlags
*             pei   SpriteAddr
*             pei   PlayerScreenX
*             pha
*             _GTEAddSprite
            jsr   InitPlayerSpriteFrames
            jsr   InitEnemy
            rts

MovePlayer
            pea   PLAYER_SLOT
            pei   PlayerScreenX
            pei   PlayerScreenY
            _GTEMoveSprite

            lda   PlayerScreenY
            clc
            adc   #15

            pea   PLAYER_BOT_SLOT
            pei   PlayerScreenX
            pha
            _GTEMoveSprite
            rts

UpdatePlayerAnimation
; Slow animation - only update every 8 frames
            lda   PlayerAnimTimer
            inc   a
            cmp   #2
            bcc   :no_update

            lda   #0                     ; Reset timer
            sta   PlayerAnimTimer

            lda   PlayerFrame
            inc   a
            cmp   #3                     ; 3 frames per direction
            bcc   :set_frame
            lda   #0                     ; Wrap back to frame 0
:set_frame
            sta   PlayerFrame

            jsr   UpdatePlayerSprites
            rts

:no_update
            sta   PlayerAnimTimer
            rts

UpdatePlayerSprites
; Use jump table based on direction
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

; Compiled sprite address arrays (filled by InitPlayerSpriteFrames)
DownTopCompiled    ds   6      ; 3 frames × 2 bytes
DownBotCompiled    ds   6
LeftTopCompiled    ds   6
LeftBotCompiled    ds   6
UpTopCompiled      ds   6
UpBotCompiled      ds   6

UpdateCamera
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

CheckTileCollision
            pha       ; Space for result
            phx       ; push x
            phy       ; push y
            _GTEGetTileAt
            pla       ; get tile data
            and   #TILE_ID_MASK

            cmp   #0
            beq   :solid

            ; Check 104-106 (passable)
            cmp   #104
            bcc   :solid    ; < 104, solid
            cmp   #107
            bcc   :passable ; 104-106, passable

            cmp   #110
            bcc   :solid    ; 107-109, solid
            cmp   #112
            bcc   :passable ; 110-111, passable

            cmp   #126
            bcc   :solid
            cmp   #128
            bcc   :passable ; 126-127, passable

            cmp   #130
            beq   :passable ; 130, passable

            cmp   #134
            beq   :passable ; 134, passable

            cmp   #135
            beq   :passable ; 135, passable

            cmp   #161
            bcc   :solid
            cmp   #163
            bcc   :passable ; 161-162, passable

            cmp   #193
            bcc   :solid
            cmp   #195
            bcc   :passable ; 193-194, passable

            ; Everything else is solid
            bra   :solid

:solid      sec
            rts
:passable
            clc
            rts

MyDirectPage    ds    2
MyUserId        ds    2
TestStr         ds    64        ; Buffer for enemy debug string
NumStr          ds    5
DebugStr        ds    64
DebugStr2       ds    64

AnimFrames
; Down frames
            dw  1, 65
            dw  3, 67
            dw  5, 69
; Left
            dw  7, 71
            dw  9, 73
            dw  11, 75
; Right
            dw  7, 71
            dw  9, 73
            dw  11, 75
; Up
            dw  13, 77
            dw  15, 79
            dw  17, 81

            PUT   ../kfest-2022/StartUp.s
            PUT   ../shell/Overlay.s
            PUT   InputHandler.s
            PUT   Enemy.s
            PUT   Dialog.s
            PUT   DebugPrinter.s
            PUT   gen/LanceVillagePCE2.TileMap.s
            PUT   font.s