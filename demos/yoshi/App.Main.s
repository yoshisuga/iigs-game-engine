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
DEADZONE_LEFT equ 54
DEADZONE_RIGHT equ 90
DEADZONE_TOP equ 50
DEADZONE_BOT equ 78
MAX_SCROLL_X equ 888       ; 960 - 72 (world width in X-units - screen width in X-units)
MAX_SCROLL_Y equ 512       ; 640 - 128 (world height in pixels - screen height)

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
            lda   #64
            sta   PlayerGlobalX
            lda   #120
            sta   PlayerGlobalY

            stz   ScreenX
            stz   ScreenY

*             lda   #80
*             sta   PlayerScreenX
*             lda   #100
*             sta   PlayerScreenY

* ; Calculate initial scroll position
*             lda   PlayerGlobalX
*             sec
*             sbc   PlayerScreenX
*             sta   ScreenX

*             lda   PlayerGlobalY
*             sec
*             sbc   PlayerScreenY
*             bpl   :initial_y_ok         ; if positive, ok
*             lda   #0
* :initial_y_ok            
*             sta   ScreenY            

            jsr   UpdateCamera

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

; Check collision at LEFT EDGE of sprite
            lda   PlayerScreenX
            sec
            sbc   PlayerSpeed
            tax
            lda   PlayerScreenY
            clc
            adc   #8              ; Check middle of sprite height
            tay
            jsr   CheckTileCollision
            bcs   :not_left

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

; Check collision at RIGHT EDGE of sprite
            lda   PlayerScreenX
            clc
            adc   #8             
            adc   PlayerSpeed
            tax
            lda   PlayerScreenY
            clc
            adc   #8              ; Check middle of sprite height
            tay
            jsr   CheckTileCollision
            bcs   :not_right

            lda   PlayerGlobalX
            clc
            adc   PlayerSpeed
            cmp   #960             ; World width in X-units
            bcc   :set_right
            lda   #959
:set_right
            sta   PlayerGlobalX
:not_right
            pla
            pha

            cmp   #UP_ARROW
            bne   :not_up

; Check collision at TOP EDGE of sprite
            lda   PlayerScreenY
            sec
            sbc   PlayerSpeed
            tay
            lda   PlayerScreenX
            clc
            adc   #4              ; Check middle of sprite width
            tax
            jsr   CheckTileCollision
            bcs   :not_up

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

; Check collision at BOTTOM EDGE of sprite
            lda   PlayerScreenY
            clc
            adc   #16             ; Bottom edge of 16x16 sprite
            adc   PlayerSpeed
            tay
            lda   PlayerScreenX
            clc
            adc   #4              ; Check middle of sprite width
            tax
            jsr   CheckTileCollision
            bcs   :not_down

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

; Render test string
            * lda   #^TestStr
            * pha
            * pea   #TestStr
            * pla           ; A = low word of pointer
            * ldx   #160*190    ; Screen pos=row 190, col 0
            * ldy   #$ffff      ; color: white?
            * jsr   DrawString

            jsr   BuildDebugStr

            lda   #DebugStr         ; No bank byte needed
            ldx   #160*190
            ldy   #$FFFF
            jsr   DrawString

            lda   #DebugStr2
            ldx   #160*180
            ldy   #$ffff
            jsr   DrawString

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

; Params:
; X = pixel X, Y = pixel Y
; Output: Carry clear if passable, set if solid
CheckTileCollision
            pha       ; Space for result
            phx       ; push x
            phy       ; push y
            _GTEGetTileAt
            pla       ; get tile data
            and   #TILE_ID_MASK

; temp return to disable
            * clc
            * rts

            cmp   #0
            beq   :solid
            cmp   #3
            bcc   :passable   ; ID < 2 passable (1-2)
            cmp   #33
            bcc   :solid   ; ID < 33
            cmp   #35
            bcc   :passable ; ID < 35 (33-34)
:solid      sec
            rts
:passable
            clc
            rts            
                        


; Convert 16-bit number to 4-char string
; A = number to convert
; Result in NumStr (5 bytes: length + 4 digits)
Num2Str4
            sta   Tmp0
;Thousands digit
            ldx   #0
:th_loop
            cmp   #1000
            bcc   :th_done
            sec
            sbc   #1000
            inx
            bra   :th_loop
:th_done
            pha           ; A=orig value-1000, push to stack
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'    ; add the thousand digit to 0 to get the char for digit
            sta   NumStr+1    ; +1 because the first has the length
            rep   #$20    ; Back to 16-bit mode
            pla               ; get back the origValue-1000
; Hundreds digit
            ldx   #0
:h_loop
            cmp   #100
            bcc   :h_done
            sec
            sbc   #100
            inx
            bra   :h_loop
:h_done
            pha         ; A=origValue-100, push to stack
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'      ; add the hundreds digit to 0 to get the char
            sta   NumStr+2
            rep   #$20    ; Back to 16-bit mode
            pla
; Tens
            ldx   #0
:t_loop
            cmp   #10
            bcc   :t_done
            sec
            sbc   #10
            inx
            bra   :t_loop
:t_done
            pha
            txa
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'
            sta   NumStr+3
            rep   #$20    ; Back to 16-bit mode
            pla
; Ones
            sep   #$20    ; Switch to 8-bit mode
            clc
            adc   #'0'      ; left over
            sta   NumStr+4
            lda   #4        ; length=4
            sta   NumStr
            rep   #$20    ; Back to 16-bit mode
            rts

BuildDebugStr
            sep   #$20             ; Switch to 8-bit A
            lda   #'S'
            sta   DebugStr+1
            lda   #'X'
            sta   DebugStr+2
            lda   #':'
            sta   DebugStr+3
            rep   #$20             ; Back to 16-bit A

            lda   ScreenX
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+4
            lda   NumStr+2
            sta   DebugStr+5
            lda   NumStr+3
            sta   DebugStr+6
            lda   NumStr+4
            sta   DebugStr+7
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+8
            lda   #'S'
            sta   DebugStr+9
            lda   #'Y'
            sta   DebugStr+10
            lda   #':'
            sta   DebugStr+11
            rep   #$20             ; Back to 16-bit A

            lda   ScreenY
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+12
            lda   NumStr+2
            sta   DebugStr+13
            lda   NumStr+3
            sta   DebugStr+14
            lda   NumStr+4
            sta   DebugStr+15
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+16
            lda   #'P'
            sta   DebugStr+17
            lda   #'X'
            sta   DebugStr+18
            lda   #':'
            sta   DebugStr+19
            rep   #$20             ; Back to 16-bit A

            lda   PlayerGlobalX
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+20
            lda   NumStr+2
            sta   DebugStr+21
            lda   NumStr+3
            sta   DebugStr+22
            lda   NumStr+4
            sta   DebugStr+23
            rep   #$20             ; Back to 16-bit A

            sep   #$20             ; Switch to 8-bit A
            lda   #' '
            sta   DebugStr+24
            lda   #'P'
            sta   DebugStr+25
            lda   #'Y'
            sta   DebugStr+26
            lda   #':'
            sta   DebugStr+27
            rep   #$20             ; Back to 16-bit A

            lda   PlayerGlobalY
            jsr   Num2Str4

            sep   #$20             ; Switch to 8-bit A
            lda   NumStr+1
            sta   DebugStr+28
            lda   NumStr+2
            sta   DebugStr+29
            lda   NumStr+3
            sta   DebugStr+30
            lda   NumStr+4
            sta   DebugStr+31

            ; Add tile ID display
            lda   #' '
            sta   DebugStr+32
            lda   #'T'
            sta   DebugStr+33
            lda   #':'
            sta   DebugStr+34
            rep   #$20             ; Back to 16-bit A

            ; Get current tile ID at player position
            pha
            lda   PlayerGlobalX
            clc
            adc   #8
            pha
            lda   PlayerGlobalY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+1
            sta   DebugStr+35
            lda   NumStr+2
            sta   DebugStr+36
            lda   NumStr+3
            sta   DebugStr+37
            lda   NumStr+4
            sta   DebugStr+38

            lda   #39
            sta   DebugStr

            ; tile collision directional checks
            lda   #'C'
            sta   DebugStr2+1
            lda   #'T'
            sta   DebugStr2+2
            lda   #':'
            sta   DebugStr2+3
            lda   #'U'
            sta   DebugStr2+4
            lda   #':'
            sta   DebugStr2+5

            ; Tile Up
            rep   #$20
            pha
            lda   PlayerScreenX
            pha
            lda   PlayerScreenY
            sec
            sbc   PlayerSpeed
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+6
            lda   NumStr+3
            sta   DebugStr2+7
            lda   NumStr+4
            sta   DebugStr2+8

            ; Tile Left
            lda   #'L'
            sta   DebugStr2+9
            lda   #':'
            sta   DebugStr2+10

            rep   #$20
            pha
            lda   PlayerScreenX
            sec
            sbc   PlayerSpeed
            pha
            lda   PlayerScreenY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+11
            lda   NumStr+3
            sta   DebugStr2+12
            lda   NumStr+4
            sta   DebugStr2+13

            ; Tile Right
            lda   #'R'
            sta   DebugStr2+14
            lda   #':'
            sta   DebugStr2+15

            rep   #$20
            pha
            lda   PlayerScreenX
            clc
            adc   #8
            adc   PlayerSpeed
            pha
            lda   PlayerScreenY
            clc
            adc   #8
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+16
            lda   NumStr+3
            sta   DebugStr2+17
            lda   NumStr+4
            sta   DebugStr2+18

            ; Tile Down
            lda   #'D'
            sta   DebugStr2+19
            lda   #':'
            sta   DebugStr2+20

            rep   #$20
            pha
            lda   PlayerScreenX
            clc
            adc   #4
            pha
            lda   PlayerScreenY
            clc
            adc   #16
            adc   PlayerSpeed
            pha
            _GTEGetTileAt
            pla
            and   #TILE_ID_MASK
            jsr   Num2Str4

            sep   #$20
            lda   NumStr+2
            sta   DebugStr2+21
            lda   NumStr+3
            sta   DebugStr2+22
            lda   NumStr+4
            sta   DebugStr2+23

            lda   #24
            sta   DebugStr2

            rep   #$20             ; Back to 16-bit A
            rts

MyDirectPage    ds    2
MyUserId        ds    2
Tmp0            ds    2
TestStr         str   'YOSHI TESTING'
NumStr          ds    5
DebugStr        ds    64
DebugStr2       ds    64

            PUT   ../kfest-2022/StartUp.s
            PUT   ../shell/Overlay.s
            PUT   gen/LanceVillage.TileMap.s
            PUT   font.s