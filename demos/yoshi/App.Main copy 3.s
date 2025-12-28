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

; Constants
DEADZONE_LEFT equ 60
DEADZONE_RIGHT equ 100
DEADZONE_TOP equ 80
DEADZONE_BOT equ 120
MAX_SCROLL_X equ 1760      ; 1920 - 160 (world width - screen width)
MAX_SCROLL_Y equ 440


MAX_SPRITES equ 16
PLAYER_SLOT equ 0
PLAYER_SPRITE_ID equ {SPRITE_16X16+151}
PLAYER_VBUFF equ VBUFF_SPRITE_START+0*VBUFF_SPRITE_STEP

; Keycodes
LEFT_ARROW    equ   $08
RIGHT_ARROW   equ   $15
UP_ARROW      equ   $0B
DOWN_ARROW    equ   $0A

Main
            phk
            plb

            bra :start
            dfb $B0,$0B,$1E,$55

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

            pea   #160
            pea   #200
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

; start player at world position 160,80
            lda   #160
            sta   PlayerGlobalX
            lda   #100
            sta   PlayerGlobalY

            lda   #80
            sta   PlayerScreenX
            lda   #100
            sta   PlayerScreenY

; Calculate initial scroll position
            lda   PlayerGlobalX
            sec
            sbc   PlayerScreenX
            sta   ScreenX

            lda   PlayerGlobalY
            sec
            sbc   PlayerScreenY
            bpl   :initial_y_ok         ; if positive, ok
            lda   #0
:initial_y_ok            
            sta   ScreenY            

            jsr   InitSprites

:eventloop
            pha
            _GTEReadControl
            pla

; Check for arrow keys
            and   #$007F
            pha

            cmp   #$08                  ; LEFT_ARROW
            bne   :not_left
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
            lda   PlayerGlobalX
            clc
            adc   PlayerSpeed
            cmp   #1920
            bcc   :set_right
            lda   #1919
:set_right
            sta   PlayerGlobalX
:not_right
            pla
            pha

            cmp   #UP_ARROW
            bne   :not_up
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

            jsr UpdateCamera

; Move the sprite
            pea   PLAYER_SLOT
            pei   PlayerScreenX
            pei   PlayerScreenY
            _GTEMoveSprite

            pei   ScreenX               ; BG0 X-origin
            pei   ScreenY               ; BG0 Y-origin
            _GTESetBG0Origin

            pea   RENDER_WITH_SHADOWING ; Proper sprite rendering
            _GTERender
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
            pea   VBUFF_SPRITE_START     ; Virtual buffer address
            _GTECreateSpriteStamp

; Compile the sprite for fast rendering
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   SpriteFlags
            pha                          ; Space for result
            pea   SPRITE_16X16           ; Sprite size
            pea   VBUFF_SPRITE_START     ; Source vbuff
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

            rts

UpdateCamera
; Calc screen position - TODO!
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

MyDirectPage    ds    2
MyUserId        ds    2
Tmp0            ds    2

            PUT   ../kfest-2022/StartUp.s
            PUT   ../shell/Overlay.s
            PUT   gen/LanceVillage.TileMap.s
