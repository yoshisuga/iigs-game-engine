# Multi-Level RPG Architecture Plan

## User Request
Design a multi-level RPG system where:
- **NPC.s** = Engine (operations: move, interact, fight)
- **App.Main.s** = Level loader (data: NPCs, tilesets, maps)
- Support multiple levels with different tilesets/maps
- Maintain same core operations across levels

---

## Current Architecture Assessment

### What's Hardcoded (Must Change)
- Tileset: `LanceVillageTiles` (App.Main.s:174)
- Palette: `LanceVillagePalette` (App.Main.s:180)
- Map: `Tile_Layer_1` with dimensions 130×45 (BG0SetUp)
- **NPCs**: 3 hardcoded spawn functions with positions, sprites, behaviors all hardcoded
  - SpawnEnemy: Position (80,60), Tile 139, Patrol 100-350
  - SpawnNPC1: Position (80,80), Tile 333, Patrol 40-120
  - SpawnNPC2: Position (100,120), Reuses NPC 0 sprites

### What's Already Data-Driven (Keep)
- Tilemap data: Generated from Tiled JSON
- Dialog text: Separate data arrays with lookup table
- Collision detection: Generic tile checking

### What Stays in NPC.s (Engine)
- NPC arrays (position, animation, sprites)
- Collision detection (`CheckAllNPCCollisions`)
- AI updates (`UpdateNPCPatrol`, `UpdateNPCChase`)
- Animation system (`UpdateNPCAnimation`, `UpdateNPCSprites`)
- Sprite compilation (`InitNPC0Sprites`, etc.)
- Dialog queue management

---

## Proposed Architecture

### File Structure
```
App.Main.s          - Main entry, level loading
NPC.s               - NPC engine (operations only)
LevelData.s         - Level definitions (NEW)
NPCData.s           - NPC spawn data tables (NEW)
DialogData.s        - Dialog text (extracted from NPC.s)
Player.s            - Player system (existing)
Dialog.s            - Dialog engine (existing)
```

### Data Flow
```
App.Main.s
  ↓
  LoadLevel(levelID)
    ↓
    1. Load tileset from LevelData
    2. Load palette from LevelData
    3. Set up map from LevelData
    4. Call InitNPCsFromTable(levelNPCTable)
      ↓
      NPC.s: Loop through table, spawn each NPC
        ↓
        Use SpawnNPCFromData(npcDef) - generic spawner
```

---

## Implementation Plan

### Phase 1: Create Data Structures

#### 1.1 Create LevelData.s

**File:** `/Users/yoshi/Code/personal/6502-dev/iigs-gte/demos/yoshi/LevelData.s`

```assembly
; Level Definition Structure (14 bytes)
; +0:  Tileset pointer (long, 4 bytes)
; +4:  Palette pointer (long, 4 bytes)
; +8:  Tilemap pointer (long, 4 bytes)
; +12: Map width (word, 2 bytes)
; +14: Map height (word, 2 bytes)
; +16: NPC table pointer (long, 4 bytes)
; +20: Total size = 20 bytes

LevelTable
            dw   Level0Data         ; Level 0: Lance Village
            dw   Level1Data         ; Level 1: Next level
            ; Add more levels here

Level0Data
            ; Tileset (4 bytes - bank + address)
            dw   ^LanceVillageTiles
            dw   #LanceVillageTiles
            ; Palette (4 bytes)
            dw   ^LanceVillagePalette
            dw   #LanceVillagePalette
            ; Tilemap (4 bytes)
            dw   ^Tile_Layer_1
            dw   #Tile_Layer_1
            ; Map dimensions (4 bytes)
            dw   130                ; Width
            dw   45                 ; Height
            ; NPC spawn table (4 bytes)
            dw   ^Level0NPCTable
            dw   #Level0NPCTable

Level1Data
            ; ... same structure for next level
```

#### 1.2 Create NPCData.s

**File:** `/Users/yoshi/Code/personal/6502-dev/iigs-gte/demos/yoshi/NPCData.s`

```assembly
; NPC Definition Structure (28 bytes)
; +0:  GlobalX (word, 2 bytes)
; +2:  GlobalY (word, 2 bytes)
; +4:  Sprite Tile ID (word, 2 bytes)
; +6:  Behavior (byte, 1 byte)          ; NPC_FRIENDLY=0, NPC_HOSTILE=1
; +7:  AI Type (byte, 1 byte)           ; AI_PATROL=1, AI_CHASE=2
; +8:  Speed (word, 2 bytes)
; +10: Patrol Min X (word, 2 bytes)
; +12: Patrol Max X (word, 2 bytes)
; +14: Character ID (word, 2 bytes)     ; For dialog
; +16: Health (word, 2 bytes)
; +18: Max Health (word, 2 bytes)
; +20: Damage (word, 2 bytes)
; +22: Sprite Reuse NPC Index (word, 2 bytes)  ; 0xFFFF = compile own sprites
; +24: Reserved (4 bytes)               ; Future expansion
; Total: 28 bytes

; Level 0 NPC Table
Level0NPCTable
            dw   3                  ; NPC count

            ; NPC 0 Definition (Guardian)
            dd   NPC0_Level0
            ; NPC 1 Definition (Man)
            dd   NPC1_Level0
            ; NPC 2 Definition (Merchant)
            dd   NPC2_Level0

NPC0_Level0
            dw   80                 ; GlobalX
            dw   60                 ; GlobalY
            dw   139                ; Sprite tile ID
            db   NPC_FRIENDLY       ; Behavior
            db   AI_PATROL          ; AI type
            dw   1                  ; Speed
            dw   100                ; Patrol min X
            dw   350                ; Patrol max X
            dw   1                  ; Character ID (Guardian)
            dw   20                 ; Health
            dw   20                 ; Max health
            dw   5                  ; Damage
            dw   $FFFF              ; Compile own sprites
            dd   $00000000          ; Reserved

NPC1_Level0
            dw   80                 ; GlobalX
            dw   80                 ; GlobalY
            dw   333                ; Sprite tile ID
            db   NPC_FRIENDLY       ; Behavior
            db   AI_PATROL          ; AI type
            dw   1                  ; Speed
            dw   40                 ; Patrol min X
            dw   120                ; Patrol max X
            dw   3                  ; Character ID (Child)
            dw   10                 ; Health
            dw   10                 ; Max health
            dw   3                  ; Damage
            dw   $FFFF              ; Compile own sprites
            dd   $00000000          ; Reserved

NPC2_Level0
            dw   100                ; GlobalX
            dw   120                ; GlobalY
            dw   0                  ; Sprite tile ID (not used)
            db   NPC_FRIENDLY       ; Behavior
            db   AI_PATROL          ; AI type
            dw   1                  ; Speed
            dw   60                 ; Patrol min X
            dw   140                ; Patrol max X
            dw   2                  ; Character ID (Merchant)
            dw   10                 ; Health
            dw   10                 ; Max health
            dw   3                  ; Damage
            dw   0                  ; Reuse NPC 0's sprites
            dd   $00000000          ; Reserved
```

#### 1.3 Extract Dialog Data

**File:** `/Users/yoshi/Code/personal/6502-dev/iigs-gte/demos/yoshi/DialogData.s`

Move all dialog definitions from NPC.s (lines 1608-1736) to this new file:
- `CharacterDialogTable`
- All `Character0DialogInfo`, `Character1DialogInfo`, etc.
- All dialog line arrays and text

### Phase 2: Refactor NPC.s (Engine Only)

#### 2.1 Remove Hardcoded Spawn Functions

**Delete** from NPC.s:
- `SpawnEnemy` (lines 570-660)
- `SpawnNPC1` (lines 663-765)
- `SpawnNPC2` (lines 767-892)

#### 2.2 Create Generic Spawner

**Add to NPC.s** (replace InitNPCs):

```assembly
InitNPCsFromTable
; Initialize NPCs from level data table
; Input: A = NPC table pointer (low word)
;        X = NPC table pointer (high word)
            sta   Tmp0              ; Save table pointer low
            stx   Tmp0+2            ; Save table pointer high

            ; Clear all NPC arrays (existing code from InitNPCs lines 114-149)
            ldx   #0
:clear      ; ... existing clear loop ...

            ; Get NPC count from table
            lda   [Tmp0]            ; First word = NPC count
            sta   Tmp1              ; Save count
            beq   :done             ; No NPCs to spawn

            ; Advance pointer past count
            lda   Tmp0
            clc
            adc   #2
            sta   Tmp0
            bcc   :no_carry
            inc   Tmp0+2
:no_carry

            ; Loop through NPCs
            stz   CurrentNPCIndex
:spawn_loop
            ; Get NPC definition pointer (4 bytes)
            ldy   #0
            lda   [Tmp0],y          ; Low word
            sta   Tmp2
            iny
            iny
            lda   [Tmp0],y          ; High word
            sta   Tmp2+2

            ; Advance table pointer by 4
            lda   Tmp0
            clc
            adc   #4
            sta   Tmp0
            bcc   :no_carry2
            inc   Tmp0+2
:no_carry2

            ; Spawn this NPC
            jsr   SpawnNPCFromData

            ; Next NPC
            lda   CurrentNPCIndex
            clc
            adc   #2
            sta   CurrentNPCIndex
            cmp   Tmp1
            cmp   Tmp1
            bcc   :spawn_loop

:done       rts
```

#### 2.3 Create SpawnNPCFromData

```assembly
SpawnNPCFromData
; Spawn one NPC from definition structure
; Input: Tmp2 = pointer to NPCDefinition structure
;        CurrentNPCIndex = NPC index to spawn

            ldx   CurrentNPCIndex

            ; Mark active
            lda   #1
            sta   NPCActive,x

            ; Read position (offset +0, +2)
            ldy   #0
            lda   [Tmp2],y
            sta   NPCGlobalX,x
            ldy   #2
            lda   [Tmp2],y
            sta   NPCGlobalY,x

            ; Read sprite tile ID (offset +4)
            ldy   #4
            lda   [Tmp2],y
            sta   NPCTmp0           ; Save for sprite init

            ; Read behavior (offset +6, byte)
            ldy   #6
            lda   [Tmp2],y
            and   #$00FF            ; Mask to byte
            sta   NPCBehavior,x

            ; Read AI type (offset +7, byte)
            ldy   #7
            lda   [Tmp2],y
            and   #$00FF
            sta   NPCAIType,x

            ; Read speed (offset +8)
            ldy   #8
            lda   [Tmp2],y
            sta   NPCSpeed,x

            ; Read patrol range (offset +10, +12)
            ldy   #10
            lda   [Tmp2],y
            sta   NPCPatrolMin,x
            ldy   #12
            lda   [Tmp2],y
            sta   NPCPatrolMax,x

            ; Read character ID (offset +14)
            ldy   #14
            lda   [Tmp2],y
            sta   NPCCharacterID,x

            ; Read health/damage (offset +16, +18, +20)
            ldy   #16
            lda   [Tmp2],y
            sta   NPCHealth,x
            ldy   #18
            lda   [Tmp2],y
            sta   NPCMaxHealth,x
            ldy   #20
            lda   [Tmp2],y
            sta   NPCDamage,x

            ; Initialize animation
            lda   #DIR_DOWN
            sta   NPCDirection,x
            stz   NPCFrame,x
            stz   NPCAnimTimer,x
            stz   NPCPatrolDir,x
            stz   NPCState,x

            ; Check sprite reuse (offset +22)
            ldy   #22
            lda   [Tmp2],y
            cmp   #$FFFF
            beq   :compile_own_sprites

            ; Reuse sprites from another NPC
            jsr   CopySpritesFromNPC
            bra   :add_sprites

:compile_own_sprites
            ; Determine which init function to call based on index
            lda   CurrentNPCIndex
            beq   :init_npc0
            cmp   #2
            beq   :init_npc1
            cmp   #4
            beq   :init_npc2
            bra   :add_sprites      ; No more sprite slots

:init_npc0
            lda   NPCTmp0
            jsr   InitNPC0Sprites
            bra   :add_sprites
:init_npc1
            lda   NPCTmp0
            jsr   InitNPC1Sprites
            bra   :add_sprites
:init_npc2
            lda   NPCTmp0
            jsr   InitNPC2Sprites

:add_sprites
            ; Set sprite flags
            ldx   CurrentNPCIndex
            lda   #SPRITE_16X16+SPRITE_COMPILED
            sta   NPCTopFlags,x
            lda   #SPRITE_16X8+SPRITE_COMPILED
            sta   NPCBotFlags,x

            ; Set initial sprite addresses
            lda   NPCDownTopCompiled0,x
            sta   NPCTopAddr,x
            lda   NPCDownBotCompiled0,x
            sta   NPCBotAddr,x

            ; Calculate screen position
            lda   NPCGlobalX,x
            sec
            sbc   ScreenX
            sta   NPCScreenX,x
            lda   NPCGlobalY,x
            sec
            sbc   ScreenY
            sta   NPCScreenY,x

            ; Add sprites (slot = NPC_SLOT_BASE + CurrentNPCIndex)
            lda   CurrentNPCIndex
            clc
            adc   #NPC_SLOT_BASE
            pha
            lda   NPCTopFlags,x
            pha
            lda   NPCTopAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            pha
            _GTEAddSprite

            ldx   CurrentNPCIndex
            txa
            clc
            adc   #NPC_SLOT_BASE+1
            pha
            lda   NPCBotFlags,x
            pha
            lda   NPCBotAddr,x
            pha
            lda   NPCScreenX,x
            pha
            lda   NPCScreenY,x
            clc
            adc   #15
            pha
            _GTEAddSprite

            rts

CopySpritesFromNPC
; Copy sprite addresses from another NPC
; Input: A = source NPC index, X = destination NPC index
            ; ... implementation similar to SpawnNPC2 lines 814-840 ...
            rts
```

#### 2.4 Update NPC.s Includes

Add at top of NPC.s:
```assembly
            PUT   DialogData.s      ; Dialog definitions
            PUT   NPCData.s         ; NPC spawn data
```

### Phase 3: Refactor App.Main.s (Level Loader)

#### 3.1 Add Current Level Variable

**Add to App.Main.s** after line 28:

```assembly
CurrentLevel    equ 70      ; Current level ID (DP variable)
```

#### 3.2 Create LoadLevel Function

**Add to App.Main.s** after SetLimits (around line 254):

```assembly
LoadLevel
; Load a level by ID
; Input: A = level ID (0-based)
            sta   CurrentLevel

            ; Get level data pointer from table
            asl   a                 ; × 2 for word offset
            tax
            lda   LevelTable,x
            sta   Tmp0              ; Tmp0 = pointer to level data

            ; Load tileset (offset +0, 4 bytes)
            ldy   #2
            lda   [Tmp0],y          ; Get address
            pha
            ldy   #0
            lda   [Tmp0],y          ; Get bank
            pha
            pea   0                 ; Start tile
            pea   511               ; End tile
            _GTELoadTileSet

            ; Load palette (offset +4, 4 bytes)
            ldy   #6
            lda   [Tmp0],y          ; Get address
            pha
            ldy   #4
            lda   [Tmp0],y          ; Get bank
            pha
            pea   $0000             ; Palette 0
            _GTESetPalette

            ; Get tilemap pointer (offset +8, 4 bytes)
            ldy   #10
            lda   [Tmp0],y          ; Get address
            sta   Tmp1
            ldy   #8
            lda   [Tmp0],y          ; Get bank
            sta   Tmp1+2

            ; Get map dimensions (offset +12, +14)
            ldy   #12
            lda   [Tmp0],y          ; Width
            pha
            ldy   #14
            lda   [Tmp0],y          ; Height
            pha

            ; Set tilemap
            lda   Tmp1+2            ; Bank
            pha
            lda   Tmp1              ; Address
            pha
            _GTESetBG0TileMapInfo

            ; Get NPC table pointer (offset +16, 4 bytes)
            ldy   #18
            lda   [Tmp0],y          ; Address
            tax                     ; X = high word
            ldy   #16
            lda   [Tmp0],y          ; Address
            ; A = low word, X = high word

            ; Initialize NPCs from table
            jsr   InitNPCsFromTable

            rts
```

#### 3.3 Update Main Initialization

**Replace** in App.Main.s (lines 172-198):

```assembly
; OLD (lines 172-198):
            pea   0
            pea   511
            pea   #^LanceVillageTiles
            pea   #LanceVillageTiles
            _GTELoadTileSet

            pea   $0000
            pea   #^LanceVillagePalette
            pea   #LanceVillagePalette
            _GTESetPalette

            jsr   SetLimits
            jsr   BG0SetUp

            stz   ScreenX
            stz   ScreenY

            jsr   InitPlayer
            jsr   UpdateCamera
            jsr   InitNPCs
            jsr   InitDialog

; NEW:
            jsr   SetLimits

            stz   ScreenX
            stz   ScreenY

            jsr   InitPlayer
            jsr   InitDialog

            ; Load level 0 (Lance Village)
            lda   #0
            jsr   LoadLevel

            jsr   UpdateCamera
```

#### 3.4 Add Level Data Include

**Add to App.Main.s** after line 344:

```assembly
            PUT   LevelData.s
```

### Phase 4: Support Level Transitions

#### 4.1 Add Level Transition Triggers

Create new file: **TriggerData.s**

```assembly
; Level Transition Structure (8 bytes)
; +0: Tile X position (word)
; +2: Tile Y position (word)
; +4: Target level ID (word)
; +6: Target spawn X (word)
; +8: Target spawn Y (word)

Level0Triggers
            dw   1                  ; Trigger count
            ; Trigger 0: Exit to Level 1
            dw   64                 ; X = 64 (tile position)
            dw   22                 ; Y = 22
            dw   1                  ; Target level = 1
            dw   80                 ; Spawn at X = 80
            dw   80                 ; Spawn at Y = 80
```

#### 4.2 Add Trigger Check in Main Loop

**Add to App.Main.s** in event loop (after line 227):

```assembly
:eventloop
            jsr   HandleInput
            jsr   UpdateCamera
            jsr   UpdatePlayerAnimation
            jsr   UpdateNPCAnimation
            jsr   UpdatePlayerInvincibility
            jsr   UpdateAllNPCs
            jsr   CheckAllNPCCollisions

            ; Check level triggers (NEW)
            jsr   CheckLevelTriggers

            ; ... rest of loop
```

#### 4.3 Implement CheckLevelTriggers

```assembly
CheckLevelTriggers
; Check if player is standing on a level transition trigger
            ; Get player tile position
            lda   PlayerGlobalX
            lsr   a                 ; Divide by 8 to get tile
            lsr   a
            lsr   a
            sta   Tmp0              ; Tile X

            lda   PlayerGlobalY
            lsr   a
            lsr   a
            lsr   a
            sta   Tmp1              ; Tile Y

            ; Get current level's trigger table
            ; ... lookup in level data ...
            ; For each trigger:
            ;   If Tmp0 == trigger.x AND Tmp1 == trigger.y:
            ;     Call TransitionToLevel(trigger.levelID, trigger.spawnX, trigger.spawnY)

            rts

TransitionToLevel
; Transition to a new level
; Input: A = target level ID
;        Tmp0 = spawn X
;        Tmp1 = spawn Y
            pha                     ; Save level ID

            ; Set player position to spawn point
            lda   Tmp0
            sta   PlayerGlobalX
            lda   Tmp1
            sta   PlayerGlobalY

            ; Load the new level
            pla
            jsr   LoadLevel

            ; Update camera
            jsr   UpdateCamera

            rts
```

---

## Implementation Order

### Step 1: Create New Files (No Breaking Changes)
1. Create `LevelData.s` with Level0Data for Lance Village
2. Create `NPCData.s` with Level0NPCTable
3. Create `DialogData.s` by copying dialog data from NPC.s

### Step 2: Refactor NPC.s (Engine)
1. Add `SpawnNPCFromData` function
2. Add `InitNPCsFromTable` function
3. Add `CopySpritesFromNPC` function (for sprite reuse)
4. **Keep** existing spawn functions temporarily (for testing)

### Step 3: Refactor App.Main.s (Loader)
1. Add `LoadLevel` function
2. Add `CurrentLevel` variable
3. Update main initialization to call `LoadLevel(0)`
4. Add includes for new data files

### Step 4: Test and Remove Old Code
1. Test Level 0 loading works correctly
2. Once verified, **delete** old spawn functions from NPC.s
3. **Delete** old hardcoded tileset/map loading from App.Main.s

### Step 5: Add Level 1 (Proof of Concept)
1. Create new tileset/map for Level 1
2. Add Level1Data to LevelData.s
3. Add Level1NPCTable to NPCData.s
4. Test switching between levels

### Step 6: Add Level Transitions
1. Create TriggerData.s
2. Add CheckLevelTriggers to main loop
3. Implement TransitionToLevel function

---

## File Modifications Summary

### New Files to Create
1. `/demos/yoshi/LevelData.s` - Level definitions
2. `/demos/yoshi/NPCData.s` - NPC spawn data
3. `/demos/yoshi/DialogData.s` - Dialog text (extracted)
4. `/demos/yoshi/TriggerData.s` - Level transition triggers (optional)

### Files to Modify
1. **NPC.s**:
   - Add `SpawnNPCFromData` function
   - Add `InitNPCsFromTable` function
   - Delete `SpawnEnemy`, `SpawnNPC1`, `SpawnNPC2` (after testing)
   - Move dialog data to DialogData.s
   - Add includes for new data files

2. **App.Main.s**:
   - Add `LoadLevel` function
   - Add `CurrentLevel` DP variable
   - Replace hardcoded init with `LoadLevel(0)` call
   - Add includes for LevelData.s
   - Add `CheckLevelTriggers` (optional)

### Files Unchanged
- Player.s - Player system works as-is
- Dialog.s - Dialog engine works as-is
- DebugPrinter.s - Debug system works as-is
- InputHandler.s - Input handling works as-is

---

## Benefits of This Architecture

### For Development
- **Add new levels**: Just edit data files, no code changes
- **Modify NPCs**: Change data tables, no recompilation
- **Test different layouts**: Swap level IDs in LoadLevel call
- **Reuse NPCs**: Same NPC across multiple levels via data

### For Performance
- **Same engine**: No code duplication across levels
- **Data-driven**: Small memory footprint per level
- **Sprite sharing**: NPCs can reuse compiled sprites

### For Scalability
- **Unlimited levels**: Just add to LevelTable
- **Unlimited NPCs per level**: Table-driven spawning
- **Easy expansion**: Add new NPC types without touching engine
- **Modular**: Each level is independent data

---

## Data Structure Reference

### LevelData Structure (20 bytes)
```
+0:  Tileset bank (word)
+2:  Tileset address (word)
+4:  Palette bank (word)
+6:  Palette address (word)
+8:  Tilemap bank (word)
+10: Tilemap address (word)
+12: Map width (word)
+14: Map height (word)
+16: NPC table bank (word)
+18: NPC table address (word)
```

### NPCDefinition Structure (28 bytes)
```
+0:  GlobalX (word)
+2:  GlobalY (word)
+4:  Sprite Tile ID (word)
+6:  Behavior (byte) - NPC_FRIENDLY/HOSTILE
+7:  AI Type (byte) - AI_PATROL/CHASE
+8:  Speed (word)
+10: Patrol Min X (word)
+12: Patrol Max X (word)
+14: Character ID (word) - For dialog lookup
+16: Health (word)
+18: Max Health (word)
+20: Damage (word)
+22: Sprite Reuse Index (word) - 0xFFFF = compile own
+24: Reserved (4 bytes)
```

### Level Transition Structure (10 bytes)
```
+0: Trigger X (word)
+2: Trigger Y (word)
+4: Target Level ID (word)
+6: Spawn X (word)
+8: Spawn Y (word)
```

---

## Example: Adding Level 1

**Step 1: Create tileset/map**
```bash
# Export from Tiled
tiled -> export as JSON -> level1.json

# Convert to assembly
node tiled2iigs.js level1.json > gen/Level1.TileMap.s
```

**Step 2: Add to LevelData.s**
```assembly
Level1Data
            dw   ^Level1Tiles
            dw   #Level1Tiles
            dw   ^Level1Palette
            dw   #Level1Palette
            dw   ^Level1_TileLayer
            dw   #Level1_TileLayer
            dw   80                 ; Width
            dw   30                 ; Height
            dw   ^Level1NPCTable
            dw   #Level1NPCTable
```

**Step 3: Add to NPCData.s**
```assembly
Level1NPCTable
            dw   2                  ; 2 NPCs in this level

            dd   NPC0_Level1
            dd   NPC1_Level1

NPC0_Level1
            dw   40, 40             ; Position
            dw   200                ; Sprite tile
            db   NPC_HOSTILE, AI_CHASE
            dw   2                  ; Speed
            dw   0, 100             ; Patrol range
            dw   0                  ; No dialog (hostile)
            dw   30, 30, 10         ; Health, Max, Damage
            dw   $FFFF              ; Compile sprites
            dd   0                  ; Reserved
```

**Step 4: Add transition from Level 0**
```assembly
; In TriggerData.s
Level0Triggers
            dw   1                  ; 1 trigger
            dw   64, 22             ; Position
            dw   1                  ; Target Level 1
            dw   40, 40             ; Spawn at (40,40)
```

**Step 5: Test**
```assembly
; In App.Main.s, change:
            lda   #0
            jsr   LoadLevel
; To:
            lda   #1
            jsr   LoadLevel
```

---

## Migration Strategy

### Phase A: Preparation (No Breaking Changes)
1. Create all new data files
2. Add new functions to NPC.s (keep old ones)
3. Add LoadLevel to App.Main.s (don't use yet)

### Phase B: Switch to Data-Driven (Breaking)
1. Change App.Main.s init to call LoadLevel(0)
2. Test thoroughly

### Phase C: Cleanup
1. Delete old spawn functions
2. Delete old hardcoded initialization

### Phase D: Expansion
1. Add Level 1
2. Add level transitions
3. Add more NPCs to Level 0

---

## Testing Checklist

After each phase:
- [ ] Level 0 loads correctly (tileset, palette, map)
- [ ] All 3 NPCs spawn at correct positions
- [ ] NPCs have correct sprites (139, 333, reused)
- [ ] NPCs patrol correctly with right ranges
- [ ] Dialog triggers correctly for each NPC
- [ ] Character IDs map to correct dialogs
- [ ] Collision detection works
- [ ] Player can move around map
- [ ] Camera follows player
- [ ] No crashes or visual glitches

After Level 1 added:
- [ ] Can load Level 1 by changing ID in LoadLevel
- [ ] Level 1 NPCs spawn correctly
- [ ] Level transition works (if implemented)
- [ ] Can switch between levels without crashes

---

## Future Enhancements

Once base system works:
- **Save/Load System**: Save current level ID and position
- **Item System**: Add item spawn tables to LevelData
- **Quest System**: Per-level quest triggers
- **Dynamic NPCs**: NPCs that move between levels
- **Multiple Backgrounds**: BG0, BG1 per level
- **Music**: Add music track pointer to LevelData
- **Enemy Respawning**: Add respawn flags to NPCDefinition
- **Boss Battles**: Special NPC types with unique behaviors

---

## Questions for User

Before implementation:
1. How many levels do you plan to have initially? (Helps size tables)
2. Do you want level transitions now or later? (Affects scope)
3. Should NPCs be able to share sprites across levels? (Affects VBUFF management)
4. Do you want to keep the 48 VBUFF limit or increase to 56? (From previous discussion)

---

This architecture provides a clean separation between engine (NPC.s) and data (Level/NPC/Dialog Data files), making it easy to add new levels and NPCs without touching core game logic.
