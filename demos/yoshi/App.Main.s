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
PLAYER_BOT_VBUFF equ VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP

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

            _MTStartUp

            lda   #ENGINE_MODE_USER_TOOL
            jsr   GTEStartUp

            * pea   #144
            * pea   #128
            pea   #7
            pea   #0
            _GTESetScreenMode

            pea   0
            pea   489
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

InitSprites
; Create sprite stamp from tile data
            pea   PLAYER_SPRITE_ID       ; Sprite tile ID (SPRITE_16X16+TileIndex)
            pea   PLAYER_VBUFF     ; Virtual buffer address
            _GTECreateSpriteStamp

; Compile the sprite for fast rendering
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   SpriteFlags
            pha                          ; Space for result
            pea   SPRITE_16X16           ; Sprite size
            pea   PLAYER_VBUFF     ; Source vbuff
            _GTECompileSpriteStamp
            pla
            sta   SpriteAddr             ; Save compiled sprite address

; Add sprite to screen
            pea   PLAYER_SLOT            ; Sprite slot 0
            pei   SpriteFlags            ; Flags (SPRITE_16X16+SPRITE_COMPILED)
            pei   SpriteAddr             ; Compiled sprite address
            pei   PlayerScreenX                ; X position (80)
            pei   PlayerScreenY                ; Y position (100)
            _GTEAddSprite

; add bottom part of sprite (composite)
            pea   PLAYER_SPRITE_BOT_ID       ; Sprite tile ID (SPRITE_16X16+TileIndex)
            pea   PLAYER_BOT_VBUFF     ; Virtual buffer address
            _GTECreateSpriteStamp

            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   SpriteFlags
            pha
            pea   SPRITE_16X8
            pea   PLAYER_BOT_VBUFF
            _GTECompileSpriteStamp
            pla
            sta   SpriteAddr

            lda   PlayerScreenY
            clc
            adc   #15

            pea   PLAYER_BOT_SLOT
            pei   SpriteFlags
            pei   SpriteAddr
            pei   PlayerScreenX
            pha
            _GTEAddSprite

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
Tmp0            ds    2
Tmp1            ds    2
TestStr         str   'YS 2 TEST BY YOSHI SUGAWARA'
NumStr          ds    5
DebugStr        ds    64
DebugStr2       ds    64

            PUT   ../kfest-2022/StartUp.s
            PUT   ../shell/Overlay.s
            PUT   InputHandler.s
            PUT   Enemy.s
            PUT   DebugPrinter.s
            PUT   gen/LanceVillagePCE.TileMap.s
            PUT   font.s