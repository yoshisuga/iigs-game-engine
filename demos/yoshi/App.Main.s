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
EnemyDirection equ  44    ;0=moving left, 1=right
EnemyFlags     equ  46
SpriteTmpAddr equ   48
EnemyFrameCount equ 50
AdolTmpAddr equ 52

PlayerDirection equ 54
PlayerFrame equ 56
PlayerAnimTimer equ 58

Tmp0    equ 60
Tmp1    equ 62
Tmp2    equ 64
Tmp3 equ 66

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
PLAYER_VBUFF equ VBUFF_SPRITE_START+0*VBUFF_SPRITE_STEP
PLAYER_VBUFF_1  equ VBUFF_SPRITE_START+4*VBUFF_SPRITE_STEP
PLAYER_BOT_VBUFF equ VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP
PLAYER_BOT_VBUFF_1 equ VBUFF_SPRITE_START+5*VBUFF_SPRITE_STEP

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
DETECTION_RANGE equ 36
ESCAPE_RANGE equ 36


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

:eventloop

            jsr   HandleInput
            jsr   UpdateCamera
            jsr   UpdatePlayerAnimation
            jsr   UpdateEnemy

; Move the sprite
            jsr   MovePlayer
            
            pea   ENEMY_SLOT_1
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEMoveSprite

            pei   ScreenX               ; BG0 X-origin
            pei   ScreenY               ; BG0 Y-origin
            _GTESetBG0Origin

            pea   RENDER_WITH_SHADOWING ; Proper sprite rendering
            _GTERender

            jsr   DebugPrinter

            brl :eventloop

; Shut down everything
Exit
            _GTEShutDown
            _QuitGS qtRec
qtRec       adrl       $0000
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
; Precompile all 9 animation frames
            ldx   #0
:compile_loop
            phx         ; Preserve X across all GTE calls
; calc tile IDs from lookup table
            txa
            asl         ; x2 for index
            asl         ; x4 = 4 bytes per entry
            tay

            lda   AnimFrames,y      ; top tile id
            sta   Tmp0
            lda   AnimFrames+2,y     ; bottom tile id
            sta   Tmp1
            
; TOP PORTION
            lda   Tmp0
            ora   #SPRITE_16X16         ; ora combines high bits (sprite flags) with low bits (tile id) - Tmp0 has tileID
            pha

            cpx   #0
            beq   :use_vbuff_0
            lda   #PLAYER_VBUFF_1
            bra   :store_vbuff
:use_vbuff_0
            lda   #PLAYER_VBUFF
:store_vbuff
            sta   Tmp2
            pha

            * lda   #PLAYER_VBUFF
            * sta   Tmp2              ; vbuff address
            * pha
            _GTECreateSpriteStamp

            pha         ; space for result
            pea   SPRITE_16X16
            pei   Tmp2
            _GTECompileSpriteStamp

            pla         ; compiled address
            pha         ; save on stack to use later
            txa         ; A = frame number
            asl         ; double it for the byte offset since we use words
            tay         ; Y = byte offset
            pla         ; get back compiled address
            sta   PlayerTopSprites,y
; BOTTOM PORTION
            lda   Tmp1
            ora   #SPRITE_16X8
            pha

            cpx   #0
            beq   :use_vbuffbot_0
            lda   #PLAYER_BOT_VBUFF_1
            bra   :store_vbuffbot
:use_vbuffbot_0
            lda   #PLAYER_BOT_VBUFF
:store_vbuffbot
            sta   Tmp2
            pha

            * lda   #PLAYER_BOT_VBUFF
            * sta   Tmp2
            * pha
            _GTECreateSpriteStamp

            pha
            pea   SPRITE_16X8
            pei   Tmp2
            _GTECompileSpriteStamp

            pla         ; compiled address
            pha         ; save on stack to use later
            txa         ; A = frame number
            asl         ; double it for the byte offset since we use words
            tay         ; Y = byte offset
            pla         ; get back compiled address
            sta   PlayerBotSprites,y

; handle HFLIPPED versions for right facing
; frames 6-8 need HFLIP
            cpx   #6
            bcc   :next_frame
            cpx   #9
            bcs   :next_frame
            stx   Tmp3              ; Save X (frame number) for HFLIP section
; Compile HFLIP top
            lda   Tmp0
            ora   #SPRITE_16X16+SPRITE_HFLIP
            pha
            lda  #PLAYER_VBUFF
            sta  Tmp2
            pha
            _GTECreateSpriteStamp

            pha
            pea   SPRITE_16X16
            pei   Tmp2
            _GTECompileSpriteStamp

            pla         ; compiled address
            pha         ; save on stack to use later
            lda   Tmp3              ; A = frame number (from saved value)
            asl         ; double it for the byte offset since we use words
            tay         ; Y = byte offset
            pla         ; get back compiled address
            sta   PlayerTopSprites+18,Y
; Compile HFLIP bot
            lda   Tmp1
            ora   #SPRITE_16X8+SPRITE_HFLIP
            pha
            lda   #PLAYER_BOT_VBUFF
            sta   Tmp2
            pha
            _GTECreateSpriteStamp

            pha
            pea   SPRITE_16X8
            pei   Tmp2
            _GTECompileSpriteStamp

            pla         ; compiled address
            pha         ; save on stack to use later
            lda   Tmp3              ; A = frame number (from saved value)
            asl         ; double it for the byte offset since we use words
            tay         ; Y = byte offset
            pla         ; get back compiled address
            sta   PlayerBotSprites+18,y
:next_frame
            plx         ; Restore X (loop counter)
            inx
            cpx   #12
            bcs   :done_loop
            jmp   :compile_loop

:done_loop
; Now add the initial sprite (frame 0, facing down)
            lda   PlayerTopSprites
            sta   SpriteAddr

            pea   PLAYER_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            pei   SpriteAddr
            pei   PlayerScreenX
            pei   PlayerScreenY
            _GTEAddSprite

            lda   PlayerBotSprites
            sta   SpriteAddr

            pea   PLAYER_BOT_SLOT
            lda   #SPRITE_16X8+SPRITE_COMPILED
            pha
            pei   SpriteAddr
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
            cmp   #8
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
; Calculate frame index: Direction × 3 + Frame
            lda   PlayerDirection
            asl   a                      ; × 2
            clc
            adc   PlayerDirection        ; × 2 + × 1 = × 3
            clc
            adc   PlayerFrame            ; Add current frame (0-2)
            asl   a                      ; × 2 (word addresses)

; Check if right-facing (use HFLIP sprites at +18 offset)
            ldx   PlayerDirection
            cpx   #DIR_RIGHT
            bne   :normal_sprites
            clc
            adc   #18                    ; Use HFLIP versions

:normal_sprites
            tax                          ; X = offset into sprite arrays

; Get compiled sprite addresses
            lda   PlayerTopSprites,x
            sta   SpriteAddr
            lda   PlayerBotSprites,x
            sta   Tmp0

; Update top sprite stamp
            pea   PLAYER_SLOT
            pea   $0000                  ; no flags
            pei   SpriteAddr
            _GTEUpdateSprite

; Update bottom sprite stamp
            pea   PLAYER_BOT_SLOT
            pea   $0000                  ; no flags
            pei   Tmp0
            _GTEUpdateSprite

            rts

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
            bcc   :solid    ; 107-108, solid
            cmp   #112
            bcc   :passable ; 109-110, passable

            cmp   #126
            bcc   :solid    
            cmp   #128
            bcc   :passable

            cmp   #135
            beq   :passable

            ; Everything else is solid
            bra   :solid

:solid      sec
            rts
:passable
            clc
            rts

MyDirectPage    ds    2
MyUserId        ds    2
TestStr         str   'YS 2 TEST BY YOSHI SUGAWARA'
NumStr          ds    5
DebugStr        ds    64
DebugStr2       ds    64

PlayerTopSprites  ds  18*2        ; 9 frames, 2 bytes per address
PlayerBotSprites  ds  18*2        ; 9 frames, 2 bytes per address

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
            PUT   DebugPrinter.s
            PUT   gen/LanceVillagePCE.TileMap.s
            PUT   font.s