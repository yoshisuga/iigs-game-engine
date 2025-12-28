# Yoshi Demo - Development Documentation

This document describes the development process and technical implementation of the Yoshi demo for the Apple IIGS Generic Tile Engine (GTE).

## Project Overview

The Yoshi demo is a tile-based game implementation featuring:
- Scrolling tile map background (240×80 tiles)
- Player sprite with 4-directional movement
- Dead zone camera system for smooth scrolling
- Tile-based collision detection
- Debug text overlay for development
- 144×128 pixel display mode

## File Structure

```
demos/yoshi/
├── App.Main.s           # Main game code
├── font.s               # Font data for debug text
├── DEVELOPMENT.md       # This file
└── assets/
    └── (Tiled map files, exported data)
```

## Asset Creation Pipeline

### 1. Creating Tilesets and Tilemaps with Tiled

The project uses the **Tiled Map Editor** to design levels, which are then converted to GTE format.

**Workflow:**
1. Create tileset in Tiled with 8×8 pixel tiles
2. Design the level map
3. Set tile properties for collision:
   - Mark tiles as `isSolid` for collision
   - Set `Priority` for rendering order
4. Export the map
5. Convert using `tiled2iigs.js` tool

**Example conversion command:**
```bash
node ../../tools/tiled2iigs.js map.tmx --output-dir ../sprites/gen
```

This generates:
- `App.TileSet.s` - Tile graphics data
- `App.TileMapBG0.s` - Background layer tile map
- `App.TileSetAnim.s` - Tile animation data (if any)

### 2. Understanding tiled2iigs.js

The conversion tool (`/Users/yoshi/Code/personal/6502-dev/iigs-gte/tools/tiled2iigs.js`) processes Tiled maps:

- **Tile Properties**: Reads `isSolid` and `Priority` properties (lines 508+)
- **Collision Data**: Sets mask bit for solid tiles
- **Object Layers**: Supports priority regions (not used for collision)
- **Output Format**: Generates 65816 assembly source files

**Note:** The tool's `isSolid` implementation is incomplete, so collision is currently handled manually in code.

## Main Game Implementation (App.Main.s)

### Memory Map and Variables

```assembly
; Direct Page Variables (lines 16-31)
ScreenX       equ 0      ; World scroll position (X-units)
ScreenY       equ 2      ; World scroll position (pixels)
Tmp0          equ 4      ; Temporary storage
Tmp1          equ 6
PlayerGlobalX equ 20     ; Player world position (X-units)
PlayerGlobalY equ 22     ; Player world position (pixels)
PlayerScreenX equ 24     ; Player screen position (X-units)
PlayerScreenY equ 26     ; Player screen position (pixels)
```

### Constants

```assembly
; Screen Configuration (144×128 mode)
DEADZONE_LEFT  equ 54    ; Camera deadzone (X-units)
DEADZONE_RIGHT equ 90
DEADZONE_TOP   equ 50    ; Camera deadzone (pixels)
DEADZONE_BOT   equ 78

; World Boundaries
MAX_SCROLL_X   equ 888   ; 960 - 72 (world - screen width in X-units)
MAX_SCROLL_Y   equ 512   ; 640 - 128 (world - screen height in pixels)

; Sprite Configuration
MAX_SPRITES    equ 16
PLAYER_SLOT    equ 0
PLAYER_SPRITE_ID equ {SPRITE_16X16+151}
```

### Initialization Sequence

```assembly
; 1. Start up tool sets
_TLStartUp / _MTStartUp

; 2. Initialize GTE
lda   #ENGINE_MODE_USER_TOOL
jsr   GTEStartUp

; 3. Set screen mode to 144×128
pea   #144
pea   #128
_GTESetScreenMode

; 4. Load tileset
pea   0
pea   489
pea   #^LanceVillageTiles
pea   #LanceVillageTiles
_GTELoadTileSet

; 5. Set palette
pea   $0000
pea   #^LanceVillagePalette
pea   #LanceVillagePalette
_GTESetPalette

; 6. Set up tile map
jsr   BG0SetUp

; 7. Initialize player
lda   #2
sta   PlayerSpeed
lda   #40          ; Starting position
sta   PlayerGlobalX
lda   #40
sta   PlayerGlobalY

; 8. Create and add player sprite
jsr   InitSprites
```

### Main Game Loop Structure

```assembly
:eventloop
    ; 1. Read keyboard/controller input
    _GTEReadControl

    ; 2. Handle movement input
    bit   #PAD_KEY_DOWN     ; Check arrow keys
    beq   :not_down
    jsr   HandleDownMovement
:not_down
    ; ... (repeat for other directions)

    ; 3. Update camera position
    jsr   UpdateCamera

    ; 4. Update screen scroll
    pea   0
    lda   ScreenY
    pha
    pea   0
    lda   ScreenX
    pha
    _GTESetBG0Origin

    ; 5. Update player sprite
    pea   PLAYER_SLOT
    lda   PlayerScreenY
    pha
    lda   PlayerScreenX
    pha
    _GTEMoveSprite

    ; 6. Render frame
    _GTERender

    ; 7. Draw debug text
    jsr   BuildDebugStr
    lda   #DebugStr
    ldx   #144*118        ; Screen position
    ldy   #$FFFF
    jsr   DrawString

    brl   :eventloop
```

## Core Systems

### 1. Movement System with Collision

Each direction uses a three-step process:
1. Check tile collision at sprite edge
2. If passable, update position
3. Clamp to world boundaries

**Example: Moving Right**
```assembly
; Check collision at RIGHT EDGE of sprite
lda   PlayerScreenX
clc
adc   #8              ; Add sprite width (8 X-units = 16 pixels)
adc   PlayerSpeed
tax                   ; X = test position
lda   PlayerScreenY
clc
adc   #8              ; Check middle of sprite height
tay                   ; Y = test position
jsr   CheckTileCollision
bcs   :not_right      ; Collision detected, skip movement

; No collision - update position
lda   PlayerGlobalX
clc
adc   PlayerSpeed
cmp   #960            ; World width in X-units
bcc   :set_right
lda   #959            ; Clamp to max
:set_right
sta   PlayerGlobalX
```

### 2. Tile Collision Detection

The `CheckTileCollision` function determines if a tile is passable:

```assembly
CheckTileCollision
; Input: X = screen X position, Y = screen Y position
; Output: Carry set if solid, clear if passable

    pha               ; Space for result
    phx               ; Push X
    phy               ; Push Y
    _GTEGetTileAt     ; Returns tile data on stack
    pla               ; Get tile data
    and   #TILE_ID_MASK  ; Extract tile ID ($01FF mask)

    ; Check if tile is passable
    ; Passable tiles: 1, 2, 33, 34
    ; All others: solid

    cmp   #0
    beq   :solid
    cmp   #3
    bcc   :passable   ; ID 1-2 passable
    cmp   #33
    bcc   :solid      ; ID 3-32 solid
    cmp   #35
    bcc   :passable   ; ID 33-34 passable

:solid
    sec               ; Set carry = solid
    rts
:passable
    clc               ; Clear carry = passable
    rts
```

### 3. Dead Zone Camera System

The camera only scrolls when the player moves outside a defined rectangular "dead zone":

```assembly
UpdateCamera
; Check X axis - Right edge
    lda   PlayerScreenX
    cmp   #DEADZONE_RIGHT
    bcc   :check_left

    ; Past right edge - scroll right
    sec
    sbc   #DEADZONE_RIGHT
    clc
    adc   ScreenX
    cmp   #MAX_SCROLL_X+1
    bcc   :set_scroll_x
    lda   #MAX_SCROLL_X
:set_scroll_x
    sta   ScreenX

    ; Update player screen position
    lda   PlayerGlobalX
    sec
    sbc   ScreenX
    sta   PlayerScreenX
    bra   :check_y

:check_left
    lda   PlayerScreenX
    cmp   #DEADZONE_LEFT
    bcs   :check_y

    ; Past left edge - scroll left
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

:check_y
    ; ... (similar logic for Y axis)
```

**How it works:**
- Player can move freely within the dead zone
- When player crosses dead zone boundary, camera scrolls to keep player at boundary
- Prevents jittery camera movement from small player movements

### 4. Debug Text System

The debug overlay uses a custom font renderer to display game state:

```assembly
BuildDebugStr
; Build string: "X:#### Y:#### T:#### U:### L:### R:### D:###"

    sep   #$20        ; 8-bit accumulator
    lda   #'X'
    sta   DebugStr+0
    lda   #':'
    sta   DebugStr+1

    rep   #$20        ; 16-bit accumulator
    lda   PlayerGlobalX
    jsr   Num2Str4    ; Convert to 4-digit string
    ; ... (repeat for Y, tile ID, directional tiles)

    rts

; Number to string conversion (4 digits)
Num2Str4
    ; Converts A register to 4 ASCII digits
    ; Stores in DebugStr at current position
    ; (Implementation details...)
```

## GTE Coordinate System

### The Mixed Coordinate System

**Critical Understanding**: GTE uses different units for X and Y coordinates.

- **X Coordinates**: Measured in **WORD units** (1 unit = 2 pixels)
  - Screen width 144 pixels = 72 X-units
  - Tile width 8 pixels = 4 X-units
  - 16-pixel sprite width = 8 X-units

- **Y Coordinates**: Measured in **PIXEL units** (1 unit = 1 pixel)
  - Screen height 128 pixels = 128 Y-units
  - Tile height 8 pixels = 8 Y-units
  - 16-pixel sprite height = 16 Y-units

**Example World Dimensions:**
```
World: 240 tiles × 80 tiles
     = 240×8 pixels × 80×8 pixels
     = 1920 pixels × 640 pixels
     = 960 X-units × 640 Y-units
```

### Coordinate Conversions

```assembly
; Convert pixels to X-units
PixelsToXUnits MACRO
    lsr               ; Divide by 2
    ENDM

; Convert X-units to pixels
XUnitsToPixels MACRO
    asl               ; Multiply by 2
    ENDM
```

### Screen vs World Coordinates

- **World Coordinates** (`PlayerGlobalX/Y`): Position in the entire world
- **Screen Coordinates** (`PlayerScreenX/Y`): Position on the visible screen

```assembly
; Conversion
PlayerScreenX = PlayerGlobalX - ScreenX
PlayerScreenY = PlayerGlobalY - ScreenY
```

**Important**: `_GTEGetTileAt` expects **screen-relative** coordinates, not world coordinates!

## Screen Modes

GTE supports 12 different screen sizes (from `TileStore.s:434-436`):

| Mode | Width | Height | Aspect |
|------|-------|--------|--------|
| 0    | 160   | 200    | Standard |
| 1    | 136   | 192    | |
| 2    | 128   | 200    | |
| 3    | 128   | 176    | |
| 4    | 140   | 160    | |
| 5    | 128   | 160    | |
| 6    | 120   | 160    | |
| 7    | 144   | 128    | Wide (Used) |
| 8    | 80    | 144    | Narrow |
| 9    | 144   | 192    | |
| 10   | 80    | 102    | Small |
| 11   | 160   | 1      | Debug |

**Setting Screen Mode:**
```assembly
pea   #144        ; Width
pea   #128        ; Height
_GTESetScreenMode
```

**Important Considerations:**
- Changing screen mode requires updating deadzones
- Must recalculate `MAX_SCROLL_X` and `MAX_SCROLL_Y`
- Debug text positions need adjustment
- Smaller screens may reveal out-of-bounds issues

## GTE Tile Data Format

Tiles are stored as 16-bit words with the following bit layout:

```
Bit 15: Reserved
Bit 14: TILE_PRIORITY_BIT ($4000) - Render above sprites
Bit 13: TILE_USER_BIT ($2000) - User-defined tile callback
Bit 12: TILE_SOLID_BIT ($1000) - Hint for optimization
Bit 11: TILE_DYN_BIT ($0800) - Dynamic tile
Bit 10: TILE_VFLIP_BIT ($0400) - Vertical flip
Bit 9:  TILE_HFLIP_BIT ($0200) - Horizontal flip
Bits 0-8: Tile ID (0-511)
```

**Extracting Tile ID:**
```assembly
_GTEGetTileAt
pla                    ; Get tile data
and   #TILE_ID_MASK    ; Mask = $01FF
; A now contains just the tile ID
```

## Common Patterns and Best Practices

### 1. Checking Tiles Before Movement

Always check collision at the **edge** of the sprite in the direction of movement:

```assembly
; Moving LEFT - check LEFT EDGE
lda   PlayerScreenX
sec
sbc   PlayerSpeed
tax

; Moving RIGHT - check RIGHT EDGE
lda   PlayerScreenX
clc
adc   #8              ; Sprite width in X-units
adc   PlayerSpeed
tax

; Moving UP - check TOP EDGE
lda   PlayerScreenY
sec
sbc   PlayerSpeed
tay

; Moving DOWN - check BOTTOM EDGE
lda   PlayerScreenY
clc
adc   #16             ; Sprite height in pixels
adc   PlayerSpeed
tay
```

### 2. Parallel Tool Calls for Performance

When calling multiple independent GTE functions, use parallel calls in a single message for better performance.

### 3. Sprite Management

```assembly
; Initialize sprite stamp
pea   PLAYER_SLOT
pea   PLAYER_SPRITE_ID
pea   PLAYER_VBUFF
_GTECreateSpriteStamp

; Add sprite to engine
pea   PLAYER_SLOT
lda   PlayerScreenY
pha
lda   PlayerScreenX
pha
pea   #0              ; Flags
pea   PLAYER_VBUFF
_GTEAddSprite

; Update sprite position each frame
pea   PLAYER_SLOT
lda   PlayerScreenY
pha
lda   PlayerScreenX
pha
_GTEMoveSprite
```

### 4. Error Handling

The code includes safety checks:
- Boundary clamping for world limits
- Collision detection before movement
- Screen scroll limit enforcement

## Debug Features

### Runtime Inspection

The debug text displays:
- Player X/Y global positions
- Current tile ID under player
- Tile IDs in all 4 directions (U/L/R/D)

This helps verify:
- Collision detection is checking correct tiles
- Position tracking is accurate
- Coordinate conversions are working

### Typical Debug Output

```
X:0120 Y:0080 T:0001 U:032 L:000 R:001 D:033
```

Interpretation:
- Player at (120 X-units, 80 pixels)
- Standing on tile ID 1
- Tile above: 32, Left: 0, Right: 1, Down: 33

## Known Issues and Solutions

### Issue: Collision Not Working for Horizontal Movement

**Symptoms**: Player can move vertically but not horizontally

**Causes**:
1. Using `PlayerGlobalX/Y` instead of `PlayerScreenX/Y` for `_GTEGetTileAt`
2. Checking sprite center instead of edges
3. Wrong offset for sprite width (using pixels instead of X-units)

**Solution**:
- Use `PlayerScreenX/Y` for screen-relative collision checks
- Check edges: left edge, right edge + 8 X-units, top edge, bottom edge + 16 pixels
- Remember X coordinates are in word units!

### Issue: Screen Mode Change Causes Corruption

**Symptoms**: Pressing key '8' makes screen "wig out"

**Cause**: Mode 7 (144×128) is smaller than previous settings, making scroll positions/player positions out of bounds

**Solution**:
- Update `MAX_SCROLL_X` and `MAX_SCROLL_Y`
- Adjust deadzones proportionally
- Update debug text positions
- Set as default mode in initialization

### Issue: Wrong World Boundaries

**Symptoms**: Player can move beyond visible world

**Cause**: Using pixel values instead of X-units for horizontal boundaries

**Solution**:
```assembly
; WRONG
cmp   #1920         ; Pixel value

; CORRECT
cmp   #960          ; X-unit value (1920 pixels / 2)
```

## Future Enhancements

Potential additions to the demo:
- [ ] Sprite-to-sprite collision detection
- [ ] Multiple enemy sprites
- [ ] Animated tiles
- [ ] Sound effects
- [ ] Multiple scrolling layers (BG1)
- [ ] Palette animation
- [ ] Save/load game state

## References

- **GTE Macros**: `/Users/yoshi/Code/personal/6502-dev/iigs-gte/macros/GTE.Macs.s`
- **TileStore**: `/Users/yoshi/Code/personal/6502-dev/iigs-gte/src/static/TileStore.s`
- **Example Demos**: `/Users/yoshi/Code/personal/6502-dev/iigs-gte/demos/sprites/`
- **Conversion Tool**: `/Users/yoshi/Code/personal/6502-dev/iigs-gte/tools/tiled2iigs.js`

## Conclusion

This demo demonstrates a complete tile-based game framework including:
- Asset pipeline from Tiled to GTE
- Player movement with collision detection
- Smooth scrolling camera system
- Debug visualization

The mixed coordinate system (X in word units, Y in pixels) is the most important concept to understand when working with GTE. Always be mindful of which unit system you're working in!
