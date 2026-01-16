; ========================================
; SPRITE OVERLAY SYSTEM
; ========================================
;
; Provides tile priority effect for compiled sprites by dynamically
; adding/removing overlay sprites when the player collides with priority tiles.
;
; Logic:
;   - Player is 16×24 pixels, can overlap max 6 tiles (2 wide × 3 tall)
;   - Check only tiles player is COLLIDING with
;   - Tiles with TILE_PRIORITY_BIT → look up sprite in mapping table
;   - Add overlay sprite at tile position
;   - Remove sprite when no longer colliding
;
; Usage:
;   1. Create a tile mapping table (see TileOverlayMap structure below)
;   2. Call InitSpriteOverlay with pointer to mapping table
;   3. Call UpdateSpriteOverlays each frame after moving player

; ========================================
; CONFIGURATION
; ========================================

MAX_OVERLAY_SLOTS    equ 6      ; Player is 2×3 tiles max
OVERLAY_SLOT_BASE    equ 10     ; Sprite slots 10-15
OVERLAY_VBUFF_BASE   equ 0      ; VBUFF slots 0-5 (unused)

; ========================================
; DATA STRUCTURES
; ========================================

; Tile Overlay Mapping Entry (6 bytes)
; Format:
;   +0: Background tile ID (word) - tile ID without priority bit
;   +2: Sprite tile ID (word) - corresponding sprite tile
;   +4: Sprite size (word) - SPRITE_16X16, SPRITE_16X8, or SPRITE_8X8
;
; Table must end with $FFFF sentinel
;
; Example:
; TileOverlayMap
;     dw  104, 104, SPRITE_16X16   ; Tile 104 → Sprite 104 (16x16)
;     dw  105, 105, SPRITE_16X16   ; Tile 105 → Sprite 105 (16x16)
;     dw  $FFFF                    ; End marker

; Internal state
OverlayActive       ds  MAX_OVERLAY_SLOTS*2    ; 0=inactive, 1=active
OverlayTileX        ds  MAX_OVERLAY_SLOTS*2    ; Tile X coordinate
OverlayTileY        ds  MAX_OVERLAY_SLOTS*2    ; Tile Y coordinate

; Configuration
OverlayMapPtr       ds  4       ; Pointer to tile mapping table

; Compiled sprite addresses (one per mapping entry)
; Limited by available VBUFF slots (MAX_OVERLAY_SLOTS = 6)
OverlayCompiledAddrs ds MAX_OVERLAY_SLOTS*2  ; 6 entries × 2 bytes = 12 bytes

; Temp variables
OverlayTmp0         ds  2
OverlayTmp1         ds  2
OverlayTmp2         ds  2
OverlayTmp3         ds  2

; ========================================
; INITIALIZATION
; ========================================

InitSpriteOverlay
; Initialize the sprite overlay system
; Input: A = low word of mapping table pointer
;        X = high word of mapping table pointer

    ; Save mapping table pointer
    sta   OverlayMapPtr
    stx   OverlayMapPtr+2

    ; Clear overlay state
    ldx   #MAX_OVERLAY_SLOTS*2-2
:clear_loop
    stz   OverlayActive,x
    stz   OverlayTileX,x
    stz   OverlayTileY,x
    dex
    dex
    bpl   :clear_loop

    ; Create and compile all sprite stamps from mapping table
    jsr   _CreateOverlayStamps

    rts

_CreateOverlayStamps
; Create compiled sprite stamps for all tiles in mapping table
; Fills OverlayCompiledAddrs array

    ldy   #0                ; Byte offset in mapping table
    ldx   #0                ; Entry index

:entry_loop
    ; Check if we've reached the VBUFF slot limit
    cpx   #MAX_OVERLAY_SLOTS
    bcs   :done             ; Can't create more than MAX_OVERLAY_SLOTS types

    ; Check for sentinel ($FFFF)
    lda   [OverlayMapPtr],y
    cmp   #$FFFF
    beq   :done

    ; Get sprite tile ID (offset +2)
    phy
    iny
    iny
    lda   [OverlayMapPtr],y
    sta   OverlayTmp0       ; Sprite tile ID
    iny
    iny

    ; Get sprite size (offset +4)
    lda   [OverlayMapPtr],y
    sta   OverlayTmp1       ; Sprite size
    ply

    ; Calculate VBUFF address for this entry
    ; VBUFF_SPRITE_START + (OVERLAY_VBUFF_BASE + entry_index) * VBUFF_SPRITE_STEP
    ; VBUFF_SPRITE_STEP = 2048 = $0800
    phx
    txa
    clc
    adc   #OVERLAY_VBUFF_BASE
    asl                     ; × 2
    asl                     ; × 4
    asl                     ; × 8
    asl                     ; × 16
    asl                     ; × 32
    asl                     ; × 64
    asl                     ; × 128
    asl                     ; × 256
    asl                     ; × 512
    asl                     ; × 1024
    asl                     ; × 2048
    clc
    adc   #VBUFF_SPRITE_START
    sta   OverlayTmp2       ; VBUFF address

    ; Create stamp
    lda   OverlayTmp1       ; Size
    ora   OverlayTmp0       ; OR with tile ID
    pha
    lda   OverlayTmp2       ; VBUFF address
    pha
    _GTECreateSpriteStamp

    ; Compile stamp
    lda   OverlayTmp1       ; Size only
    pha
    lda   OverlayTmp2       ; VBUFF address
    pha
    _GTECompileSpriteStamp

    ; Store compiled address
    plx
    txa
    asl                     ; × 2 for word offset
    tax
    pla                     ; Compiled address from stack
    sta   OverlayCompiledAddrs,x

    ; Next entry (6 bytes per entry)
    tya
    clc
    adc   #6
    tay

    txa
    lsr                     ; Back to entry index
    tax
    inx                     ; Next entry
    bra   :entry_loop

:done
    rts

; ========================================
; UPDATE (call each frame)
; ========================================

UpdateSpriteOverlays
; Check tiles player is colliding with and add/remove overlays
; Call after moving player each frame

    ; Clear all overlays first (simpler than tracking)
    jsr   _ClearAllOverlays

    ; Get player's top-left tile position
    lda   PlayerGlobalX
    lsr
    lsr
    lsr                     ; / 8
    sta   OverlayTmp0       ; Player tile X (left edge)

    lda   PlayerGlobalY
    lsr
    lsr
    lsr                     ; / 8
    sta   OverlayTmp1       ; Player tile Y (top edge)

    ; Player is 16×24 pixels = 2×3 tiles
    ; Check all 6 tiles player overlaps
    ldx   #0                ; Overlay slot index

    ; Row 0 (top)
    lda   OverlayTmp0       ; X (left)
    sta   OverlayTmp2
    lda   OverlayTmp1       ; Y (top)
    sta   OverlayTmp3
    jsr   _CheckAndAddOverlay

    inc   OverlayTmp2       ; X + 1 (right)
    jsr   _CheckAndAddOverlay

    ; Row 1 (middle)
    lda   OverlayTmp0       ; X (left)
    sta   OverlayTmp2
    inc   OverlayTmp3       ; Y + 1
    jsr   _CheckAndAddOverlay

    inc   OverlayTmp2       ; X + 1 (right)
    jsr   _CheckAndAddOverlay

    ; Row 2 (bottom)
    lda   OverlayTmp0       ; X (left)
    sta   OverlayTmp2
    inc   OverlayTmp3       ; Y + 2
    jsr   _CheckAndAddOverlay

    inc   OverlayTmp2       ; X + 1 (right)
    jsr   _CheckAndAddOverlay

    rts

_CheckAndAddOverlay
; Check tile at (OverlayTmp2, OverlayTmp3) and add overlay if priority
; Input: OverlayTmp2 = tile X, OverlayTmp3 = tile Y
;        X = overlay slot index
; Output: X incremented if overlay added

    ; Check if we have slots available
    cpx   #MAX_OVERLAY_SLOTS*2
    bcs   :no_slots

    ; Calculate tile offset: Y * 130 + X
    ; 130 = 128 + 2 = (Y << 7) + (Y << 1)
    lda   OverlayTmp3
    asl                     ; × 2
    sta   Tmp0              ; Y × 2

    lda   OverlayTmp3
    asl                     ; × 2
    asl                     ; × 4
    asl                     ; × 8
    asl                     ; × 16
    asl                     ; × 32
    asl                     ; × 64
    asl                     ; × 128
    clc
    adc   Tmp0              ; Y × 130
    clc
    adc   OverlayTmp2       ; + X
    asl                     ; × 2 for word offset
    tay

    ; Get tile from map
    lda   Tile_Layer_1,y

    ; Check for priority bit
    bit   #TILE_PRIORITY_BIT
    beq   :no_priority

    ; Has priority - strip bit to get base tile ID
    and   #TILE_ID_MASK
    sta   Tmp1              ; Base tile ID

    ; Look up sprite in mapping table
    jsr   _FindSpriteForTile
    bcc   :no_mapping       ; Not found

    ; Found - A contains compiled sprite address
    ; Add overlay sprite
    jsr   _AddOverlaySprite
    inx
    inx                     ; Move to next slot

:no_mapping
:no_priority
:no_slots
    rts

_FindSpriteForTile
; Find sprite mapping for tile ID
; Input: Tmp1 = tile ID to find
; Output: Carry set if found, A = compiled sprite address
;         Carry clear if not found

    ldy   #0                ; Byte offset in table
    ldx   #0                ; Entry index

:loop
    lda   [OverlayMapPtr],y
    cmp   #$FFFF
    beq   :not_found

    cmp   Tmp1
    beq   :found

    ; Next entry (6 bytes)
    iny
    iny
    iny
    iny
    iny
    iny
    inx
    bra   :loop

:found
    ; Get compiled address from array
    txa
    asl                     ; × 2 for word offset
    tax
    lda   OverlayCompiledAddrs,x
    sec                     ; Set carry = found
    rts

:not_found
    clc                     ; Clear carry = not found
    rts

_AddOverlaySprite
; Add overlay sprite at tile position
; Input: X = overlay slot index (word offset)
;        A = compiled sprite address
;        OverlayTmp2 = tile X
;        OverlayTmp3 = tile Y

    ; Save compiled address
    phx
    tax
    pla
    sta   OverlayTmp1       ; Compiled address

    ; Mark active
    lda   #1
    sta   OverlayActive,x

    ; Save tile position
    lda   OverlayTmp2
    sta   OverlayTileX,x
    lda   OverlayTmp3
    sta   OverlayTileY,x

    ; Calculate screen position from tile position
    lda   OverlayTmp2
    asl
    asl
    asl                     ; × 8 for pixel coords
    sec
    sbc   ScreenX
    sta   Tmp0              ; Screen X

    lda   OverlayTmp3
    asl
    asl
    asl                     ; × 8 for pixel coords
    sec
    sbc   ScreenY
    sta   Tmp2              ; Screen Y

    ; Calculate sprite slot number
    txa
    lsr                     ; Word offset to index
    clc
    adc   #OVERLAY_SLOT_BASE
    pha                     ; Sprite slot

    ; Add sprite
    pea   SPRITE_16X16+SPRITE_COMPILED
    lda   OverlayTmp1       ; Compiled address
    pha
    pei   Tmp0              ; Screen X
    pei   Tmp2              ; Screen Y
    _GTEAddSprite

    rts

_ClearAllOverlays
; Remove all active overlay sprites

    ldx   #0
:loop
    lda   OverlayActive,x
    beq   :next

    ; Remove sprite
    phx
    txa
    lsr                     ; Word offset to index
    clc
    adc   #OVERLAY_SLOT_BASE
    pha
    _GTERemoveSprite
    plx

    ; Mark inactive
    stz   OverlayActive,x

:next
    inx
    inx
    cpx   #MAX_OVERLAY_SLOTS*2
    bcc   :loop

    rts
