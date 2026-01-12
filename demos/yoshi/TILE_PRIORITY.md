# Tile Priority in GTE

## Overview

Tile priority allows specific tiles to render **in front of sprites**, enabling effects like sprites walking behind tree tops, building roofs, etc.

## How Priority Works

**Priority Bit:** `TILE_PRIORITY_BIT = 0x4000` (defined in `src/Defs.s:217`)

When set on a tile, that tile renders in front of sprites instead of behind them.

## Important: Priority Requires Two-Layer Mode

**Priority ONLY works when `ENGINE_MODE_TWO_LAYER` is enabled.**

### Evidence from Source Code

From `src/Tiles.s:256-261`:
```assembly
lda  EngineMode
bit  #ENGINE_MODE_DYN_TILES+ENGINE_MODE_TWO_LAYER
beq  :setTileFast              ; Neither DYN nor TWO_LAYER -> Fast mode
bit  #ENGINE_MODE_TWO_LAYER
beq  :setTileDyn               ; DYN but not TWO_LAYER -> Dyn mode
                               ; Otherwise -> TwoLayer mode
```

The engine has 3 rendering modes:
1. **Fast** - Single layer, no priority support
2. **Dyn** - Dynamic tiles, single layer, no priority support
3. **TwoLayer** - BG0 + BG1, **priority supported**

From `src/Tiles.s:485-490`, tile proc table structure:
```
[MODE]         ENGINE_MODE: Fast, Dyn, TwoLayer
[Over | Under] Priority?  : Yes, No
```

Only the TwoLayer mode has "Over/Under" tile rendering procs that respect the priority bit.

## Two-Layer System

**BG1 (Background Layer):**
- Always renders behind sprites
- Typically used for floor, ground, base terrain

**BG0 (Foreground Layer):**
- Can have tiles with or without priority bit
- Tiles **without** priority: Render behind sprites
- Tiles **with** priority: Render in front of sprites

**Sprites:**
- Render between the layers based on tile priority

## Setting Up Priority in Tiled

### 1. Create Two Tile Layers in Tiled

**Layer 1** (created first, lower ID):
- Becomes **BG0** (Foreground)
- Contains trees, buildings, objects with priority

**Layer 2** (created second, higher ID):
- Becomes **BG1** (Background)
- Contains floors, ground, base terrain

### 2. Create an Object Layer

Add a layer of type "Object Group" in Tiled.

### 3. Mark Priority Regions

For each area where sprites should go behind tiles:

1. Draw a **rectangle object** over the region (e.g., tree tops)
2. Add a custom property to the rectangle:
   - **Name:** `Priority`
   - **Type:** `bool`
   - **Value:** `true`

### 4. Export with tiled2iigs.js

The tool automatically:
- Detects rectangles with `Priority = true` property
- Sets `TILE_PRIORITY_BIT` on all tiles within those rectangles
- Generates both BG0 and BG1 layer data

From `tools/tiled2iigs.js:382-399`:
```javascript
function applyObjectLayerToBG0(objectLayer, bg0data) {
    const priorityObjects = objectLayer.objects.filter(o => isPriorityObject(o));

    for (const region of priorityObjects) {
        const [x, y, w, h] = [region.x, region.y, region.width, region.height].map(x => Math.floor(x / 8));

        // Mark each tile as priority
        for (let j = y; j < (y + h); j += 1) {
            for (let i = x; i < (x + w); i += 1) {
                bg0data[j][i] |= GTE_PRIORITY_BIT;
            }
        }
    }
}
```

## Enabling Two-Layer Mode in Code

In your initialization code:

```assembly
; Enable two-layer mode for priority support
lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER
jsr   GTEStartUp
```

If you also need dynamic tiles:
```assembly
lda   #ENGINE_MODE_USER_TOOL+ENGINE_MODE_TWO_LAYER+ENGINE_MODE_DYN_TILES
jsr   GTEStartUp
```

## Layer Loading

Both layers must be loaded and initialized:

```assembly
; Load BG0 (foreground with priority tiles)
jsr   BG0SetUp

; Load BG1 (background)
jsr   BG1SetUp
```

The `tiled2iigs.js` tool generates both `BG0SetUp` and `BG1SetUp` functions when two layers are present.

## Example Use Case: Tree

**Setup in Tiled:**
- **BG1 Layer:** Grass/floor tiles
- **BG0 Layer:** Tree trunk (bottom) + tree top

**Priority Object:**
- Draw rectangle over tree top area only
- Set `Priority = true`

**Result:**
- Sprite walks in front of grass (BG1 always behind)
- Sprite walks in front of tree trunk (no priority bit)
- Sprite walks **behind** tree top (priority bit set)
- Grass shows through transparent parts of tree top (masking)

## Masking with Priority

When using two layers, tiles on BG0 automatically get the `MASK_BIT` if they're not solid. This allows BG1 to show through transparent pixels.

From `tools/tiled2iigs.js:508`:
```javascript
const mask_bit = (!tileset[tileIndex - 1].isSolid || ...)
                 && ((GLOBALS.tileLayers.length !== 1) || GLOBALS.forceMasked);
```

## Common Issues

### Priority Not Working

**Symptom:** Tiles with priority bit still render behind sprites

**Cause:** Engine not in two-layer mode

**Solution:**
1. Enable `ENGINE_MODE_TWO_LAYER` in startup
2. Ensure both BG0 and BG1 layers exist in Tiled export
3. Call both `BG0SetUp` and `BG1SetUp` in initialization

### Only One Layer Exported

**Symptom:** tiled2iigs.js only generates BG0 data

**Cause:** Only one tile layer in Tiled map

**Solution:** Create second tile layer in Tiled before export

## References

- `src/Defs.s:217` - TILE_PRIORITY_BIT definition
- `src/Tiles.s:256-261` - Engine mode selection
- `src/Tiles.s:485-540` - Tile proc tables (Fast/Dyn/TwoLayer)
- `tools/tiled2iigs.js:378-399` - Priority object detection
- `tools/tiled2iigs.js:13` - GTE_PRIORITY_BIT constant (0x4000)
