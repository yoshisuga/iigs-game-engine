# Generic Tile Engine (GTE) - Technical Overview

## Introduction

The Generic Tile Engine (GTE) is a sophisticated 2D game engine written in 65816 assembly language for the Apple IIgs. It provides a complete framework for creating smooth-scrolling tile-based games with sprite support, multiple background layers, and hardware-accelerated rendering.

This document provides a comprehensive technical overview of the engine architecture, starting from initialization through to the rendering pipeline.

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Project Structure](#project-structure)
3. [Initialization Process](#initialization-process)
4. [Data Structures](#data-structures)
5. [Tile System](#tile-system)
6. [Sprite System](#sprite-system)
7. [Rendering Pipeline](#rendering-pipeline)
8. [Scrolling and Tilemaps](#scrolling-and-tilemaps)
9. [Asset Pipeline](#asset-pipeline)
10. [API Reference](#api-reference)
11. [Performance Features](#performance-features)

---

## Core Concepts

### What Makes GTE Unique

The Generic Tile Engine uses several innovative approaches to maximize performance on Apple IIgs hardware:

#### 1. Code Field Architecture

Unlike traditional engines that render to a frame buffer, GTE renders directly to **executable 65816 code**. This code field:
- Contains pre-calculated graphics rendering opcodes
- Executes directly to produce the video signal
- Eliminates the overhead of separate frame buffer copying
- Uses 6 banks of code in round-robin fashion for 208 lines of video output

#### 2. Dirty Tile System

Only tiles that have changed are re-rendered:
- Tracks which tiles need updating via a dirty flag
- Maintains a queue of dirty tiles for efficient processing
- Automatically marks tiles dirty based on scrolling, sprite movement, or explicit updates
- Provides near-zero overhead for static screen regions

#### 3. Parallel Array Data Structure

Core engine data is organized in parallel arrays for cache efficiency:
- Tile Store: 9 parallel arrays with 1,066 entries (41×26 tiles)
- Enables fast indexed lookups without pointer chasing
- Optimized for 65816 indexed addressing modes

---

## Project Structure

### Directory Layout

```
/src/                   - Main engine implementation (7,908 lines of 65816 assembly)
├── blitter/           - Rendering and blitting operations
├── render/            - Tile rendering modules for different modes
│   ├── Fast.s         - Fast mode (uniform tiles)
│   ├── Slow.s         - Slow mode (mixed tiles)
│   ├── Dynamic.s      - Dynamic mode (custom callbacks)
│   ├── Dirty.s        - Dirty mode (direct screen rendering)
│   └── TwoLayer.s     - Two-layer mode (BG0 + BG1)
├── tiles/             - Tile management (dirty tile queue)
├── static/            - Static data structures
└── [core modules]     - Tool.s, Render.s, Sprite.s, etc.

/tools/                - Asset conversion tools (JavaScript)
├── png2iigs.js        - Convert PNG to IIgs format
├── tiled2iigs.js      - Import Tiled maps
├── mksprite.js        - Create sprite stamps
└── [other tools]      - Rotation, scaling, etc.

/demos/                - Example projects
├── yoshi/
├── pacman/
├── zelda/
└── [other demos]
```

### Key Source Files

| File | Lines | Purpose |
|------|-------|---------|
| Tool.s | 1,019 | Toolbox wrapper and API entry points |
| Render.s | 796 | Main rendering pipeline |
| Sprite.s | 1,245 | Sprite management and subsystem |
| SpriteRender.s | 655 | Sprite rendering specializations |
| TileMap.s | 661 | Tilemap management and dirty region detection |
| Tiles.s | 776 | Core tile functions and tile store operations |
| CoreImpl.s | 370 | Engine startup/shutdown and initialization |
| Graphics.s | 331 | Screen mode setup and graphics initialization |

---

## Initialization Process

### Engine Startup Sequence

When you call `GTEStartUp(dPageAddr, capFlags, userId)`, the engine initializes in this order:

#### 1. **IntStartUp** - Interrupt Initialization
```
- Enable VBL (Vertical Blank) interrupts
- Set up interrupt handlers
- Initialize interrupt state
```

#### 2. **InitMemory** - Memory Allocation
```
- Allocate memory for sprite banks
- Allocate tile data banks (64 KB)
- Set up code field banks (6×64 KB)
- Initialize sprite data/mask banks
```

#### 3. **EngineReset** - Engine State Initialization
```
- Clear all engine state variables
- Reset scroll positions to (0, 0)
- Clear sprite records
- Initialize frame counters
```

#### 4. **InitGraphics** - Graphics Subsystem Setup
```
- _ShadowOn: Enable video shadowing (flicker-free updates)
- _GrafOn: Turn on graphics mode
- _SetSCBs: Set scanline control bytes for palette
- _SetScreenMode: Configure display dimensions (320×200)
- _InitBG0: Initialize primary background layer
- _InitBG1: Initialize secondary background (if enabled)
```

#### 5. **InitSprites** - Sprite System Initialization
```
- Clear sprite data/mask banks
- Initialize VBUFF values
- Set up sprite records (16 slots)
- Clear sprite linked list
```

#### 6. **InitTiles** - Tile Store Initialization
```
- Clear all 9 tile store arrays
- Initialize tile addresses
- Set up TileStoreLookup table (82×52 entries)
- Clear dirty flags
```

#### 7. **InitTimers** - Timer System Setup
```
- Clear 4 timer slots
- Reset tick counters
- Initialize callback pointers
```

### Setting Up a Game

After engine startup, typical game initialization:

```assembly
; 1. Set screen mode
pea 320          ; width
pea 200          ; height
_GTESetScreenMode

; 2. Load tile graphics
pea 0            ; start tile ID
pea 255          ; end tile ID
pea ^TileData    ; tile data bank
pea #TileData    ; tile data address
_GTELoadTileSet

; 3. Set up tilemap
pea 64           ; tilemap width (tiles)
pea 32           ; tilemap height (tiles)
pea ^MapData     ; map data bank
pea #MapData     ; map data address
_GTESetBG0TileMapInfo

; 4. Bind palette
pea ^PaletteData
pea #PaletteData
_GTEBindSCBArray

; 5. Add sprites
pea #SPRITE_ID_PLAYER
pea 160          ; x position
pea 100          ; y position
pea ^PlayerSprite
pea #PlayerSprite
_GTEAddSprite
```

---

## Data Structures

### Tile Store

The **Tile Store** is the heart of the engine. It's a 9-parallel-array system with 1,066 entries (41 columns × 26 rows):

```
Entry Index = (row × 41) + col

Array 0: TS_TILE_ID (word 0)
  - Tile descriptor with embedded flags
  - Bits 15:    TILE_PRIORITY_BIT (sprite over/under)
  - Bit 12:     TILE_MASK_BIT (transparency)
  - Bit 11:     TILE_DYN_BIT (dynamic tile)
  - Bit 10:     TILE_VFLIP_BIT (vertical flip)
  - Bit 9:      TILE_HFLIP_BIT (horizontal flip)
  - Bits 8-0:   TILE_ID (0-512)

Array 1: TS_DIRTY (word 1)
  - Dirty flag (0=clean, non-zero=dirty)
  - Prevents duplicate queue entries

Array 2: TS_SPRITE_FLAG (word 2)
  - Bitfield of sprites intersecting this tile
  - Bits 0-15: one bit per sprite slot
  - Used to dispatch sprite rendering

Array 3: TS_TILE_ADDR (word 3)
  - Cached address of tile data in tiledata bank
  - Pre-calculated for fast rendering

Array 4: TS_CODE_ADDR_LOW (word 4)
  - Low word of code field address
  - Where this tile renders in code field

Array 5: TS_CODE_ADDR_HIGH (word 5)
  - High byte/bank of code field address

Array 6: TS_WORD_OFFSET (word 6)
  - Word offset for indirect addressing
  - Used in rendering calculations

Array 7: TS_JMP_ADDR (word 7)
  - Address of 32-byte snippet space
  - Used for dynamic tiles with custom rendering

Array 8: TS_SCREEN_ADDR (word 8)
  - Cached on-screen location
  - For dirty rendering mode
```

**Total Size:** 41 × 26 × 9 × 2 bytes = 19,188 bytes per bank

### TileStoreLookup Table

A **double-width, double-height lookup table** (82×52 entries):

```
Purpose: Quickly find which TileStore entries a sprite overlaps
Size: 82 columns × 52 rows = 4,264 entries
Each entry: Index into TileStore (0-1065)

Lookup Index = (sprite_y/4) × 82 + (sprite_x/4)

Benefits:
- O(1) lookup of tiles covered by sprite position
- 2-tile border handles edge cases
- Enables fast sprite/tile intersection tests
```

### Sprite Record Structure

Each sprite occupies 42 bytes with the following layout:

```
SPRITE_REC_SIZE = 42 bytes
MAX_SPRITES = 16

User-Set Fields:
+00  SPRITE_STATUS (word)     - ADDED, MOVED, UPDATED, REMOVED, HIDDEN
+02  SPRITE_ID (word)         - Unique ID with flags (SPRITE_OVERLAY bit)
+04  SPRITE_X (word)          - World X coordinate
+06  SPRITE_Y (word)          - World Y coordinate
+08  VBUFF_ADDR (long)        - Address of sprite stamp (data/mask banks)

Cached/Calculated Fields:
+12  TS_LOOKUP_INDEX (word)   - Index into TileStoreLookup (top-left)
+14  TS_COVERAGE_SIZE (word)  - Number of tiles covered (NxM)
+16  SPRITE_DISP (long)       - Stamped address based on flags
+20  SPRITE_CLIP_LEFT (word)  - Clipping bounds
+22  SPRITE_CLIP_RIGHT (word)
+24  SPRITE_CLIP_TOP (word)
+26  SPRITE_CLIP_BOTTOM (word)
+28  IS_OFF_SCREEN (word)     - Visibility flag
+30  SORTED_PREV (word)       - Y-sorted linked list (depth ordering)
+32  SORTED_NEXT (word)

Additional Fields:
+34  [8 bytes reserved]       - For future use or alignment
```

### Sprite Priority Linked List

Sprites are depth-sorted using a **Y-coordinate linked list**:

```
SpriteHead -> Sprite at Y=10 -> Sprite at Y=50 -> Sprite at Y=100 -> NULL
              (SORTED_NEXT)     (SORTED_NEXT)     (SORTED_NEXT)

Benefits:
- Automatic depth ordering (sprites at higher Y draw later)
- O(n) insertion when sprite moves vertically
- O(1) traversal for rendering
```

---

## Tile System

### Tile Format

Each tile is **8×8 pixels** in super hires (320×200) mode, using 4-color (2 bits per pixel) format.

#### Tile Data Storage

```
Tile Data Bank: 64 KB
Tiles: 512 maximum
Size per tile: 128 bytes

Layout:
- 8 rows × 16 bytes per row
- Two 8-pixel words per row (left and right half)
- Bytes 0-63: Normal orientation
- Bytes 64-127: Horizontally flipped version

Memory efficient:
- Pre-calculated flips avoid runtime computation
- Compact storage (512 tiles fit in 64 KB)
```

#### Tile Descriptor Format

The 16-bit tile descriptor encodes the tile ID and rendering flags:

```
Bit 15:    TILE_PRIORITY_BIT (0x8000)
           0 = Tile renders under sprites
           1 = Tile renders over sprites

Bit 12:    TILE_MASK_BIT (0x1000)
           1 = Tile has transparency/masking

Bit 11:    TILE_DYN_BIT (0x0800)
           1 = Dynamic tile (uses snippet space)

Bit 10:    TILE_VFLIP_BIT (0x0400)
           1 = Vertical flip

Bit 9:     TILE_HFLIP_BIT (0x0200)
           1 = Horizontal flip

Bits 8-0:  TILE_ID (0x01FF mask)
           Tile index (0-512)

Example:
  0x0042 = Tile 42, normal
  0x0242 = Tile 42, horizontally flipped
  0x0642 = Tile 42, H+V flipped
  0x8042 = Tile 42, high priority (over sprites)
```

### Setting Tiles

#### Direct Tile Setting

```assembly
; Set tile at column 10, row 5 to tile ID 42 (H-flipped)
pea 10           ; column
pea 5            ; row
pea $0242        ; tile descriptor (42 | TILE_HFLIP_BIT)
_GTESetTile
```

This:
1. Calculates TileStore index: (5 × 41) + 10 = 215
2. Updates `TS_TILE_ID[215] = $0242`
3. Calculates tile data address (with flip offset if needed)
4. Stores in `TS_TILE_ADDR[215]`
5. Marks tile dirty: `TS_DIRTY[215] = 1`
6. Pushes tile onto dirty queue

### Dynamic Tiles

Tiles with `TILE_DYN_BIT` set can use custom rendering:

```
Dynamic Tile Process:
1. Engine allocates 32 bytes of "snippet space" per dynamic tile
2. User provides custom rendering code (up to 32 bytes)
3. Code is called with:
   - A = tile data address
   - B = code field bank
   - Y = code field address
   - X = tile store offset
4. Custom code renders tile content
5. Returns to engine

Use Cases:
- Animated tiles (water, lava)
- Parallax effects
- Rotation effects
- Custom blend modes
```

---

## Sprite System

### Sprite Data Layout

Sprites are stored in paired banks:

```
spritedata bank:  64 KB - Sprite pixel data
spritemask bank:  64 KB - Sprite transparency masks

Each sprite: 16×16 pixels
4 variations per sprite: Pre-rendered at different offsets
```

#### Why 4 Variations?

For smooth pixel-perfect movement, the engine pre-renders each sprite in a 4×4 pixel grid:

```
Variation 0: Offset (0, 0)
Variation 1: Offset (4, 0)
Variation 2: Offset (0, 4)
Variation 3: Offset (4, 4)

Layout in memory:
+---+---+---+---+
| 0 | 1 | 2 | 3 |  <- 4 columns
+---+---+---+---+
| 0 | 1 | 2 | 3 |  <- 4 rows (9×9 tile regions)
+---+---+---+---+
| 0 | 1 | 2 | 3 |
+---+---+---+---+
| 0 | 1 | 2 | 3 |
+---+---+---+---+

Benefits:
- No runtime clipping calculations
- 1-pixel overlap between regions for seamless clipping
- Fast indexed lookup based on (x mod 4, y mod 4)
```

### Adding and Managing Sprites

#### Adding a Sprite

```assembly
; Add sprite with ID 1 at position (160, 100)
pea #1           ; sprite ID
pea 160          ; X position (world coordinates)
pea 100          ; Y position
pea ^SpriteStamp ; bank of sprite stamp data
pea #SpriteStamp ; address of sprite stamp
_GTEAddSprite
```

The engine:
1. Finds free sprite slot (0-15)
2. Sets `SPRITE_STATUS = SPRITE_STATUS_ADDED`
3. Stores position and VBUFF address
4. Calculates which tiles sprite overlaps via TileStoreLookup
5. Marks affected tiles dirty
6. Updates sprite linked list (sorted by Y)

#### Moving a Sprite

```assembly
pea #1           ; sprite ID
pea 165          ; new X
pea 105          ; new Y
_GTEMoveSprite
```

The engine:
1. Marks old tiles dirty (clear previous sprite position)
2. Updates sprite position
3. Recalculates tile coverage
4. Marks new tiles dirty
5. Updates linked list if Y changed

#### Updating Sprite Graphics

```assembly
pea #1           ; sprite ID
pea ^NewStamp    ; new sprite stamp
pea #NewStamp
_GTEUpdateSprite
```

Updates the sprite's graphics without changing position.

#### Removing a Sprite

```assembly
pea #1           ; sprite ID
_GTERemoveSprite
```

Marks tiles dirty and frees sprite slot.

### Sprite Rendering Process

When a tile needs rendering and has sprites on it:

```
1. Check TS_SPRITE_FLAG for tile
   - Bit 0 set = Sprite 0 present
   - Bit 1 set = Sprite 1 present
   - etc.

2. Count number of sprites (1-4 supported per tile)

3. Dispatch to appropriate compositor:
   - 1 sprite: K_TS_ONE_SPRITE (optimized fast path)
   - 2 sprites: CopyTwoSpritesDataAndMaskToDP
   - 3 sprites: CopyThreeSpritesDataAndMaskToDP
   - 4 sprites: CopyFourSpritesDataAndMaskToDP

4. Compositor blends sprites with tile:
   - Checks TILE_PRIORITY_BIT
   - Renders sprites under tile (priority=1) or over tile (priority=0)
   - Applies sprite masks for transparency
   - Writes result to code field

5. Clear TS_DIRTY flag
```

### Sprite/Tile Intersection

The **TileStoreLookup** table enables fast intersection tests:

```assembly
; Given sprite at (x, y), find top-left tile:
sprite_x = 160
sprite_y = 100

; Calculate lookup index
lookup_x = sprite_x / 4 = 40
lookup_y = sprite_y / 4 = 25
lookup_index = lookup_y × 82 + lookup_x = 2090

; Fetch tile store index
tile_store_index = TileStoreLookup[2090]

; Mark tile dirty
TS_DIRTY[tile_store_index] = 1
```

For 16×16 sprites, the engine marks a 3×3 tile region (9 tiles) as affected.

---

## Rendering Pipeline

### Frame Rendering Flow

The `GTERender()` call executes the following pipeline:

```
GTERender(renderFlags)
  |
  ├─> 1. _DoTimers()
  |     Execute timer callbacks
  |
  ├─> 2. _ApplyBG0YPos()
  |     Map virtual lines to physical screen (vertical scroll)
  |
  ├─> 3. _ApplyBG1YPos()
  |     Set BG1 vertical offset (if enabled)
  |
  ├─> 4. _ApplyBG0XPosPre()
  |     Calculate horizontal offset values
  |
  ├─> 5. _ApplyBG1XPosPre()
  |     Calculate BG1 horizontal offset
  |
  ├─> 6. _RenderSprites()
  |     Process sprite changes:
  |       - Detect moved sprites
  |       - Mark affected tiles dirty
  |       - Calculate sprite/tile intersections
  |
  ├─> 7. _UpdateBG0TileMap()
  |     Detect scrolled tiles:
  |       - Calculate visible region
  |       - Compare to previous frame
  |       - Copy new tiles from tilemap
  |       - Mark new tiles dirty
  |
  ├─> 8. _ApplyTiles()
  |     Render all dirty tiles:
  |       while (dirty queue not empty):
  |         - Pop dirty tile
  |         - Dispatch to tile renderer
  |         - Clear dirty flag
  |
  ├─> 9. _ApplyBG0XPos()
  |     Patch code field exit opcodes (horizontal scroll)
  |
  ├─> 10. _ApplyBG1XPos()
  |      Update BG1 horizontal offset
  |
  ├─> 11. Shadowing/Overlay Phase
  |      If overlays enabled:
  |        - _ShadowOff()
  |        - _BltRange(overlay regions)
  |        - _ShadowOn()
  |
  └─> 12. _BltRange(firstLine, lastLine)
        Blitter operation: Copy code field to video memory
```

### Dirty Tile Queue

The dirty tile queue ensures only changed tiles are re-rendered:

```
DirtyTileQueue: Circular buffer (1,066 entries max)
DirtyTileQueueHead: Write pointer
DirtyTileQueueTail: Read pointer

_PushDirtyTile(tileStoreOffset):
  if TS_DIRTY[offset] == 0:        # Not already queued
    DirtyTileQueue[Head] = offset
    Head = (Head + 1) mod 1066
    TS_DIRTY[offset] = 1           # Mark as queued

_PopDirtyTile():
  if Head != Tail:                 # Queue not empty
    offset = DirtyTileQueue[Tail]
    Tail = (Tail + 1) mod 1066
    TS_DIRTY[offset] = 0           # Clear dirty flag
    return offset
  else:
    return -1                      # No dirty tiles
```

### Tile Rendering Dispatch

Each rendering mode provides 5 pluggable functions:

```
1. K_TS_BASE_TILE_DISP
   Render tile without sprites (fast path)
   Input: A=tile data addr, B=code bank, Y=code addr, X=store offset

2. K_TS_SPRITE_TILE_DISP
   Dispatch sprite compositing
   Selects over/under rendering based on TILE_PRIORITY_BIT

3. K_TS_ONE_SPRITE
   Optimized single-sprite compositor
   Variants: Fast/Slow, Over/Under, Normal/Flipped

4. K_TS_COPY_TILE_DATA
   Copy tile into direct page workspace
   Prepares tile for multi-sprite blending

5. K_TS_APPLY_TILE_DATA
   Render workspace to code field
   Writes blended result to video
```

### Rendering Modes

The engine supports 5 rendering modes:

#### Fast Mode (`render/Fast.s`)

```
Assumption: All tiles are the same type
Method: Uses PEA (push effective address) opcodes
Speed: Fastest
Use Case: Solid backgrounds with no transparency
```

#### Slow Mode (`render/Slow.s`)

```
Assumption: Tiles have varying types
Method: Fills in dynamic addresses per tile
Speed: Moderate
Use Case: Mixed tile sets with some transparency
```

#### Dynamic Mode (`render/Dynamic.s`)

```
Assumption: Custom rendering per tile
Method: Calls user-provided callbacks (K_TS_USER_TILE)
Speed: Slowest
Use Case: Special effects, rotation, parallax
```

#### Dirty Mode (`render/Dirty.s`)

```
Assumption: Mostly static playfield
Method: Renders directly to screen without intermediate buffering
Speed: Fast for sparse updates
Use Case: Puzzle games, static levels with few changes
```

#### Two-Layer Mode (`render/TwoLayer.s`)

```
Assumption: Separate BG0 and BG1 layers
Method: Composite two backgrounds with different scroll rates
Speed: Moderate
Use Case: Parallax backgrounds, multi-plane scrolling
```

---

## Scrolling and Tilemaps

### Tilemap Structure

A **tilemap** is a 2D array of 16-bit tile descriptors:

```
Tilemap:
  - Width: Number of tiles horizontally (e.g., 64)
  - Height: Number of tiles vertically (e.g., 32)
  - Data: 2D array of tile descriptors

Example 64×32 tilemap:
  64 tiles × 32 tiles = 2,048 tile descriptors
  2,048 × 2 bytes = 4,096 bytes

Memory layout (row-major):
  [Row 0: Tile 0, Tile 1, ..., Tile 63]
  [Row 1: Tile 0, Tile 1, ..., Tile 63]
  ...
  [Row 31: Tile 0, Tile 1, ..., Tile 63]

Access: TileMap[row × width + col]
```

### Setting Up a Tilemap

```assembly
; Configure BG0 tilemap
pea 64           ; width in tiles
pea 32           ; height in tiles
pea ^MapData     ; bank of tilemap data
pea #MapData     ; address of tilemap data
_GTESetBG0TileMapInfo
```

### Scrolling

The engine supports smooth pixel-by-pixel scrolling:

```assembly
; Scroll to position (120, 80) in world coordinates
pea 120          ; X offset (pixels)
pea 80           ; Y offset (pixels)
_GTESetBG0Origin
```

#### Scroll Limits

```
Maximum scroll X: (TileMapWidth × 8) - 320 pixels
Maximum scroll Y: (TileMapHeight × 8) - 200 pixels

Example for 64×32 tilemap:
  Max X: (64 × 8) - 320 = 192 pixels
  Max Y: (32 × 8) - 200 = 56 pixels
```

### Lazy Copy-on-Scroll

The engine uses **dirty region detection** to minimize tile updates during scrolling:

```
_UpdateBG0TileMap() algorithm:

1. Calculate current visible tile region:
   left_tile = StartX / 8
   top_tile = StartY / 8
   right_tile = (StartX + 320) / 8
   bottom_tile = (StartY + 200) / 8

2. Compare to previous frame's visible region

3. Identify update regions:
   a. Horizontal strip (scrolled vertically):
      - If scrolled down: new bottom row of tiles
      - If scrolled up: new top row of tiles

   b. Vertical strip (scrolled horizontally):
      - If scrolled right: new right column of tiles
      - If scrolled left: new left column of tiles

4. For each new tile:
   - Read tile descriptor from tilemap
   - Copy to tile store
   - Calculate tile data address
   - Mark tile dirty

5. Push dirty tiles onto queue
```

This ensures only newly-visible tiles are copied and rendered, providing smooth scrolling performance.

### Parallax Scrolling

The engine supports independent BG0 and BG1 layers:

```assembly
; Set BG0 to scroll at normal speed
pea 100
pea 50
_GTESetBG0Origin

; Set BG1 to scroll at half speed (parallax effect)
pea 50
pea 25
_GTESetBG1Origin
```

Each layer has its own:
- Tilemap data
- Scroll position
- Rendering mode
- Update frequency

---

## Asset Pipeline

### Converting PNG to IIgs Format

The `png2iigs.js` tool converts modern PNG images to Apple IIgs 4-color format:

```bash
node tools/png2iigs.js input.png output.bin
```

**Process:**
1. Load PNG image
2. Extract or generate 4-color palette (2 bits per pixel)
3. Convert pixels to palette indices
4. Generate data buffer (pixel values)
5. Generate mask buffer (transparency)
6. Output binary file for inclusion in assembly

**Supported Features:**
- PNG transparency -> IIgs mask data
- Automatic palette extraction
- Color matching and dithering

### Importing Tiled Maps

The `tiled2iigs.js` tool converts Tiled Map Editor JSON exports:

```bash
node tools/tiled2iigs.js tilemap.json output.s
```

**Process:**
1. Parse Tiled JSON format
2. Extract tile layers
3. Map Tiled tile IDs to GTE tile IDs
4. Extract flip flags (H/V flip)
5. Generate Merlin32 assembly source
6. Include tilemap data as `dw` directives

**Example Output:**
```assembly
; Generated by tiled2iigs.js
TileMapWidth    equ 64
TileMapHeight   equ 32

TileMapData:
    dw $0042,$0043,$0044,$0045  ; Row 0
    dw $0142,$0143,$0144,$0145  ; Row 1 (H-flipped)
    ; ... (2,048 entries total)
```

**Supported Tiled Features:**
- Multiple layers (export separately)
- Horizontal/vertical flip
- Tile ID mapping
- Custom properties (with scripting)

### Creating Sprite Stamps

The `mksprite.js` tool generates optimized sprite stamps:

```bash
node tools/mksprite.js sprite.png output.bin
```

**Process:**
1. Load 16×16 sprite PNG
2. Generate 4 variations (offset by 0,0 / 4,0 / 0,4 / 4,4)
3. Calculate 1-pixel overlap regions
4. Create data buffer (pixel values)
5. Create mask buffer (transparency)
6. Output combined stamp (data + mask interleaved)

**Memory Layout:**
```
Sprite Stamp Format:
  [Variation 0 Data] [Variation 0 Mask]
  [Variation 1 Data] [Variation 1 Mask]
  [Variation 2 Data] [Variation 2 Mask]
  [Variation 3 Data] [Variation 3 Mask]
```

Use in code:
```assembly
PlayerSprite:
    incbin "player_stamp.bin"

; Later:
pea ^PlayerSprite
pea #PlayerSprite
; ... (sprite add call)
```

---

## API Reference

### Initialization and Setup

#### GTEStartUp
```assembly
GTEStartUp(dPageAddr, capFlags, userId)
  dPageAddr (long) - Direct page address for engine workspace
  capFlags (word)  - Capability flags (reserved, use 0)
  userId (word)    - User ID for memory allocation

Returns: Error code (0 = success)
```

#### GTEShutDown
```assembly
GTEShutDown()
  No parameters

Frees all allocated memory and disables engine.
```

#### GTESetScreenMode
```assembly
GTESetScreenMode(width, height)
  width (word)  - Screen width (160, 320)
  height (word) - Screen height (200)

Returns: Error code
```

### Tile Management

#### GTELoadTileSet
```assembly
GTELoadTileSet(startTile, endTile, tileDataPtr)
  startTile (word)    - First tile ID to load (0-511)
  endTile (word)      - Last tile ID to load (0-511)
  tileDataPtr (long)  - Address of tile data

Loads tile graphics into engine tile data bank.
```

#### GTESetTile
```assembly
GTESetTile(col, row, tileDescriptor)
  col (word)            - Column (0-40)
  row (word)            - Row (0-25)
  tileDescriptor (word) - Tile ID with flags

Sets a single tile in the tile store and marks it dirty.
```

#### GTEFillTileStore
```assembly
GTEFillTileStore(tileDescriptor)
  tileDescriptor (word) - Tile ID with flags

Fills entire tile store with the same tile.
```

### Tilemap Management

#### GTESetBG0TileMapInfo
```assembly
GTESetBG0TileMapInfo(width, height, tilemapPtr)
  width (word)       - Tilemap width in tiles
  height (word)      - Tilemap height in tiles
  tilemapPtr (long)  - Address of tilemap data

Configures BG0 tilemap.
```

#### GTESetBG1TileMapInfo
```assembly
GTESetBG1TileMapInfo(width, height, tilemapPtr)
  width (word)       - Tilemap width in tiles
  height (word)      - Tilemap height in tiles
  tilemapPtr (long)  - Address of tilemap data

Configures BG1 tilemap (secondary layer).
```

#### GTESetBG0Origin
```assembly
GTESetBG0Origin(x, y)
  x (word) - Horizontal scroll offset (pixels)
  y (word) - Vertical scroll offset (pixels)

Sets BG0 scroll position.
```

#### GTESetBG1Origin
```assembly
GTESetBG1Origin(x, y)
  x (word) - Horizontal scroll offset (pixels)
  y (word) - Vertical scroll offset (pixels)

Sets BG1 scroll position.
```

### Sprite Management

#### GTEAddSprite
```assembly
GTEAddSprite(spriteId, x, y, vbuffAddr)
  spriteId (word)   - Unique sprite ID
  x (word)          - World X coordinate
  y (word)          - World Y coordinate
  vbuffAddr (long)  - Address of sprite stamp data

Returns: Sprite slot (0-15) or -1 if no slots available
```

#### GTEMoveSprite
```assembly
GTEMoveSprite(spriteId, x, y)
  spriteId (word) - Sprite ID
  x (word)        - New X coordinate
  y (word)        - New Y coordinate

Moves sprite to new position.
```

#### GTEUpdateSprite
```assembly
GTEUpdateSprite(spriteId, vbuffAddr)
  spriteId (word)   - Sprite ID
  vbuffAddr (long)  - New sprite stamp address

Updates sprite graphics without changing position.
```

#### GTERemoveSprite
```assembly
GTERemoveSprite(spriteId)
  spriteId (word) - Sprite ID

Removes sprite from scene.
```

### Rendering

#### GTERender
```assembly
GTERender(renderFlags)
  renderFlags (word) - Rendering options (0 = normal)

Executes full rendering pipeline for one frame.
```

### Palette Management

#### GTEBindSCBArray
```assembly
GTEBindSCBArray(scbArrayPtr)
  scbArrayPtr (long) - Address of SCB array (palette data)

Binds palette data for rendering.
Format: 200 words (one per scanline), each with palette index.
```

### Timer System

#### GTEAddTimer
```assembly
GTEAddTimer(tickCount, resetCount, callback)
  tickCount (word)   - Initial countdown value
  resetCount (word)  - Reset value (0 = one-shot timer)
  callback (long)    - Address of callback function

Returns: Timer ID (0-3) or -1 if no timers available

Callback signature:
  Input: A = timer ID
  Output: None (preserve all registers)
```

---

## Performance Features

### 1. Code Field Architecture

**Benefit:** Eliminates frame buffer overhead
- Traditional engines: Render to buffer → Copy to screen = 2× work
- GTE: Render directly to executable code = 1× work
- **Result:** ~50% reduction in rendering overhead

### 2. Dirty Tile Culling

**Benefit:** Only re-render changed areas
- Traditional engines: Redraw entire screen every frame = 1,066 tiles
- GTE: Redraw only dirty tiles (typically 10-50 tiles)
- **Result:** ~20-100× reduction in tile rendering

### 3. Pre-calculated Addressing

**Benefit:** Fast tile lookups
- Tile Store: Parallel arrays with indexed access = O(1)
- TileStoreLookup: Pre-calculated sprite/tile mapping = O(1)
- **Result:** No pointer chasing, cache-friendly access patterns

### 4. Optimized Sprite Compositing

**Benefit:** Multi-level rendering specialization
- 1-sprite path: Dedicated fast compositor
- 2-4 sprite paths: Specialized blending
- Depth sorting: Pre-sorted linked list
- **Result:** Minimal overhead per sprite

### 5. Pluggable Rendering Modes

**Benefit:** Optimize for specific game needs
- Fast mode: Uniform tiles → PEA opcodes
- Slow mode: Mixed tiles → Dynamic dispatch
- Dirty mode: Sparse updates → Direct screen writes
- **Result:** 2-10× performance difference based on scene complexity

### 6. Lazy Scrolling

**Benefit:** Minimal work during camera movement
- Only copies newly-visible tiles from tilemap
- Horizontal scroll: ~26 tiles updated (one column)
- Vertical scroll: ~41 tiles updated (one row)
- **Result:** Smooth 60 FPS scrolling

### 7. Hardware Integration

**Benefit:** Flicker-free rendering
- Video shadowing: Double-buffered page flipping
- VBL interrupts: Synchronized frame timing
- Scanline control: Per-line palette switching
- **Result:** No tearing, no flicker

---

## Technical Specifications

### Display

```
Resolution:     320×200 pixels (super hires mode)
Color Depth:    4 colors (2 bits per pixel)
Tile Size:      8×8 pixels
Screen Tiles:   40×25 visible (41×26 with borders)
Refresh Rate:   60 Hz (NTSC) / 50 Hz (PAL)
```

### Memory Limits

```
Tile Storage:       512 tiles max (64 KB bank ÷ 128 bytes/tile)
Tile Store:         1,066 entries (41×26 grid)
Active Sprites:     16 maximum
Sprite Size:        16×16 pixels (4 variations per sprite)
Sprite Memory:      64 KB data + 64 KB mask per sprite set
Code Field:         6 banks × 64 KB = 384 KB
Overlays:           3 maximum
Timers:             4 independent timers
Rendering Lines:    208 virtual lines
```

### Performance Characteristics

```
Best Case (Fast Mode, no sprites, static screen):
  ~1,000 tiles/frame at 60 FPS = 60,000 tiles/second

Typical Case (Slow Mode, 8 sprites, scrolling):
  ~50 dirty tiles/frame at 60 FPS = 3,000 tiles/second

Worst Case (Dynamic Mode, 16 sprites, full screen dirty):
  ~1,066 tiles/frame at 30-60 FPS
```

---

## Conclusion

The Generic Tile Engine is a sophisticated, hardware-optimized 2D game engine that leverages the Apple IIgs's unique capabilities to deliver smooth scrolling, sprite compositing, and visual effects.

Key innovations:
- **Code field rendering** eliminates frame buffer overhead
- **Dirty tile system** reduces rendering to only changed areas
- **Parallel array architecture** enables cache-friendly access
- **Pluggable rendering modes** optimize for different game types
- **Pre-calculated sprites** enable pixel-perfect movement

This technical overview provides the foundation for understanding how GTE works from initialization through rendering. For implementation details, refer to the source code in `/src/` and example demos in `/demos/`.

---

**Document Version:** 1.0
**Last Updated:** 2025-12-29
**Engine Version:** GTE v2.0
