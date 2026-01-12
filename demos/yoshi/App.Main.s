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
; ========================================
; DIRECT PAGE VARIABLES
; ========================================
; These are performance-critical variables that need fast DP access
; Player data is now in Player.s data structure for better organization

ScreenX       equ 0      ; Current scroll X position
ScreenY       equ 2      ; Current scroll Y position
ScreenWidth   equ 4      ; Screen width
ScreenHeight  equ 6      ; Screen height
frameCount    equ 8      ; Global frame counter

; Legacy sprite vars (may be removable)
PlayerX       equ 10
PlayerY       equ 12
SpriteFlags   equ 16
SpriteAddr    equ 18

; Temporary variables (shared across systems)
Tmp0    equ 48
Tmp1    equ 50
Tmp2    equ 52
Tmp3    equ 54
Tmp4    equ 56
Tmp5    equ 58

; NPC system variables are defined in NPC.s at DP locations 72-78


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

; ========================================
; NPC VBUFF ALLOCATION
; ========================================
; Each NPC uses 12 VBUFFs (2 frames per direction × 3 directions × 2 sprites)
; With 48 total VBUFFs, we can support 2 fully-animated NPCs

; NPC 0: VBUFFs 24-35
NPC0_DOWN_TOP_VBUFF_0   equ VBUFF_SPRITE_START+24*VBUFF_SPRITE_STEP
NPC0_DOWN_TOP_VBUFF_1   equ VBUFF_SPRITE_START+25*VBUFF_SPRITE_STEP
NPC0_DOWN_BOT_VBUFF_0   equ VBUFF_SPRITE_START+26*VBUFF_SPRITE_STEP
NPC0_DOWN_BOT_VBUFF_1   equ VBUFF_SPRITE_START+27*VBUFF_SPRITE_STEP
NPC0_LEFT_TOP_VBUFF_0   equ VBUFF_SPRITE_START+28*VBUFF_SPRITE_STEP
NPC0_LEFT_TOP_VBUFF_1   equ VBUFF_SPRITE_START+29*VBUFF_SPRITE_STEP
NPC0_LEFT_BOT_VBUFF_0   equ VBUFF_SPRITE_START+30*VBUFF_SPRITE_STEP
NPC0_LEFT_BOT_VBUFF_1   equ VBUFF_SPRITE_START+31*VBUFF_SPRITE_STEP
NPC0_UP_TOP_VBUFF_0     equ VBUFF_SPRITE_START+32*VBUFF_SPRITE_STEP
NPC0_UP_TOP_VBUFF_1     equ VBUFF_SPRITE_START+33*VBUFF_SPRITE_STEP
NPC0_UP_BOT_VBUFF_0     equ VBUFF_SPRITE_START+34*VBUFF_SPRITE_STEP
NPC0_UP_BOT_VBUFF_1     equ VBUFF_SPRITE_START+35*VBUFF_SPRITE_STEP

; NPC 1: VBUFFs 36-47
NPC1_DOWN_TOP_VBUFF_0   equ VBUFF_SPRITE_START+36*VBUFF_SPRITE_STEP
NPC1_DOWN_TOP_VBUFF_1   equ VBUFF_SPRITE_START+37*VBUFF_SPRITE_STEP
NPC1_DOWN_BOT_VBUFF_0   equ VBUFF_SPRITE_START+38*VBUFF_SPRITE_STEP
NPC1_DOWN_BOT_VBUFF_1   equ VBUFF_SPRITE_START+39*VBUFF_SPRITE_STEP
NPC1_LEFT_TOP_VBUFF_0   equ VBUFF_SPRITE_START+40*VBUFF_SPRITE_STEP
NPC1_LEFT_TOP_VBUFF_1   equ VBUFF_SPRITE_START+41*VBUFF_SPRITE_STEP
NPC1_LEFT_BOT_VBUFF_0   equ VBUFF_SPRITE_START+42*VBUFF_SPRITE_STEP
NPC1_LEFT_BOT_VBUFF_1   equ VBUFF_SPRITE_START+43*VBUFF_SPRITE_STEP
NPC1_UP_TOP_VBUFF_0     equ VBUFF_SPRITE_START+44*VBUFF_SPRITE_STEP
NPC1_UP_TOP_VBUFF_1     equ VBUFF_SPRITE_START+45*VBUFF_SPRITE_STEP
NPC1_UP_BOT_VBUFF_0     equ VBUFF_SPRITE_START+46*VBUFF_SPRITE_STEP
NPC1_UP_BOT_VBUFF_1     equ VBUFF_SPRITE_START+47*VBUFF_SPRITE_STEP

; NPC 2-3: Static sprites only (no animation) if needed

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

            stz   ScreenX
            stz   ScreenY

            ; Initialize player system (position, sprites, animation)
            jsr   InitPlayer
            jsr   UpdateCamera

            ; Initialize NPCs (including enemy)
            jsr   InitNPCs
            jsr   InitDialog

:eventloop

            jsr   HandleInput
            jsr   UpdateCamera
            jsr   UpdatePlayerAnimation
            jsr   UpdateNPCAnimation        ; Update NPC animation
            jsr   UpdatePlayerInvincibility ; Update player invincibility timer
            jsr   UpdateAllNPCInvincibility ; Update NPC invincibility timers
            jsr   UpdateAllNPCs

            ; Check collision with NPCs (triggers dialog if colliding)
            jsr   CheckAllNPCCollisions

; Move the sprite
            jsr   MovePlayer

            ; NPC sprites are moved by UpdateAllNPCs, not here!

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
            PUT   Player.s
            PUT   NPC.s
            PUT   Dialog.s
            PUT   DebugPrinter.s
            PUT   gen/LanceVillagePCE2.TileMap.s
            PUT   font.s