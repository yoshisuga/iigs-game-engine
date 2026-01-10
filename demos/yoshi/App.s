            TYP   $B3                  ; S16 file
            DSK   YoshiGTEDemo
            XPL

; Segment #1: Main
            ASM   App.Main.s
            SNA   Main

; Segment #2: Tileset

            ASM   gen/LanceVillagePCE2.TileSet.s
            SNA   TSET