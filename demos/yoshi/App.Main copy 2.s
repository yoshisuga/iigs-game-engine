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

:eventloop
            pha
            _GTEReadControl
            pla

; Check for arrow keys
            and   #$007F
            pha

            cmp   #$08                  ; LEFT_ARROW
            bne   :not_left
            lda   ScreenX
            beq   :not_left             ; Don't scroll past 0
            dec
            sta   ScreenX
:not_left
            pla                         ; Restore key code
            pha                         ; Save key code

            cmp   #$15                  ; RIGHT_ARROW
            bne   :not_right
            lda   ScreenX
            inc
            sta   ScreenX
:not_right
            pla
            pha

            cmp   #UP_ARROW
            bne   :not_up
            lda   ScreenY
            beq   :not_up
            dec
            sta   ScreenY
:not_up
            pla
            pha

            cmp   #DOWN_ARROW
            bne   :not_down
            lda   ScreenY
            inc
            sta   ScreenY
        
:not_down
            pla
            
            pha
            _GTEReadControl
            pla

            jsr HandleKeys          ; generic handler for quit

            pei   ScreenX               ; BG0 X-origin
            pei   ScreenY               ; BG0 Y-origin
            _GTESetBG0Origin

            pea   $0000                 ; Render flags
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


MyDirectPage    ds    2
MyUserId        ds    2

            PUT   ../kfest-2022/StartUp.s
            PUT   ../shell/Overlay.s
            PUT   gen/LanceVillage.TileMap.s
