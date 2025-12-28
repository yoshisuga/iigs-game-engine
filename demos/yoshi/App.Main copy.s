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

YS2TileSet  EXT                 ; tileset buffer

ScreenWidth   equ 0
ScreenHeight  equ 2
frameCount    equ 4

Main
            phk
            plb

            bra :start
            dfb $B0,$0B,$1E,$55

:start
            sta   MyUserId
            tdc
            sta   MyDirectPage

            _MTStartUp

            lda   #ENGINE_MODE_USER_TOOL
            jsr   GTEStartUp

            pea   #160
            pea   #200
            _GTESetScreenMode

            pea   0
            pea   360
            pea   #^YS2TileSet
            pea   #YS2TileSet
            _GTELoadTileSet

            jsr   SetLimits

            _GTERefresh

:eventloop
            pha
            _GTEReadControl
            pla

            jsr HandleKeys          ; generic handler for quit

            _GTERefresh
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
