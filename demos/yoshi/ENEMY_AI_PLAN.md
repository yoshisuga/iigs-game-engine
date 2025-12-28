# Implementation Plan: Enemy Sprite with Patrol and Chase AI

## Overview
Add a single enemy sprite to the yoshi demo with two AI states:
- **PATROL**: Enemy moves back-and-forth horizontally between two points
- **CHASE**: Enemy detects player within range and moves toward them (4-directional)

When player collides with enemy, display "HIT:1" in debug text (no damage system yet).

## User Requirements
- 1 enemy sprite (keeping it simple)
- Back-and-forth patrol movement
- Chase when player within detection range, return to patrol when escaped
- Debug message only for collision (no health/damage)

## Critical File
`/Users/yoshi/Code/personal/6502-dev/iigs-gte/demos/yoshi/App.Main.s` - All changes go here

## Implementation Steps

### Step 1: Add Direct Page Variables (After line 31)

Add enemy state variables to Direct Page for fast access:

```assembly
; Enemy Direct Page Variables (insert after line 31: PlayerScreenY equ 26)
EnemyGlobalX    equ 28    ; Enemy world X position
EnemyGlobalY    equ 30    ; Enemy world Y position
EnemyScreenX    equ 32    ; Enemy screen X position
EnemyScreenY    equ 34    ; Enemy screen Y position
EnemyState      equ 36    ; 0=PATROL, 1=CHASE
EnemySpeed      equ 38    ; Movement speed (1 for patrol, 3 for chase)
EnemyPatrolMin  equ 40    ; Minimum patrol X position
EnemyPatrolMax  equ 42    ; Maximum patrol X position
EnemyDirection  equ 44    ; 0=moving left, 1=moving right
```

**Total**: 9 new Direct Page words (18 bytes)

### Step 2: Add Constants (After line 44)

Define enemy configuration:

```assembly
; Enemy Constants (insert after line 44: PLAYER_VBUFF equ ...)
ENEMY_SLOT         equ 1                                      ; Sprite slot 1
ENEMY_SPRITE_ID    equ {SPRITE_16X16+155}                     ; Different from player
ENEMY_VBUFF        equ VBUFF_SPRITE_START+1*VBUFF_SPRITE_STEP ; VBUFF allocation

; AI States
STATE_PATROL       equ 0
STATE_CHASE        equ 1

; AI Behavior
ENEMY_SPEED_PATROL equ 1    ; Slower than player during patrol
ENEMY_SPEED_CHASE  equ 3    ; Faster than player during chase
DETECTION_RANGE    equ 64   ; Chase if player within 64 pixels
ESCAPE_RANGE       equ 96   ; Return to patrol if player > 96 pixels
```

**Note**: If sprite tile 155 doesn't exist in tileset, temporarily use 151 (same as player) for testing.

### Step 3: Create InitEnemy Function (After line 817)

Insert new enemy initialization function:

```assembly
; ========================================
; ENEMY AI FUNCTIONS
; ========================================

InitEnemy
; Create enemy sprite stamp
            pea   ENEMY_SPRITE_ID
            pea   ENEMY_VBUFF
            _GTECreateSpriteStamp

; Compile enemy sprite for performance
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            pha                          ; Space for result
            pea   SPRITE_16X16
            pea   ENEMY_VBUFF
            _GTECompileSpriteStamp
            pla
            sta   Tmp0                   ; Store compiled sprite address

; Initialize enemy position and AI state
            lda   #200
            sta   EnemyGlobalX           ; Start at world X=200
            lda   #150
            sta   EnemyGlobalY           ; Start at world Y=150

            lda   #150
            sta   EnemyPatrolMin         ; Patrol from X=150
            lda   #350
            sta   EnemyPatrolMax         ; to X=350 (200 pixel range)

            stz   EnemyDirection         ; Start moving left
            stz   EnemyState             ; Start in PATROL state

            lda   #ENEMY_SPEED_PATROL
            sta   EnemySpeed

; Calculate initial screen position
            lda   EnemyGlobalX
            sec
            sbc   ScreenX
            sta   EnemyScreenX

            lda   EnemyGlobalY
            sec
            sbc   ScreenY
            sta   EnemyScreenY

; Add enemy sprite to screen
            pea   ENEMY_SLOT
            lda   #SPRITE_16X16+SPRITE_COMPILED
            pha
            pei   Tmp0                   ; Compiled sprite address
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEAddSprite

            rts
```

### Step 4: Create UpdateEnemy Function

Main AI controller with state machine:

```assembly
UpdateEnemy
; Update screen position from global position and scroll
            lda   EnemyGlobalX
            sec
            sbc   ScreenX
            sta   EnemyScreenX

            lda   EnemyGlobalY
            sec
            sbc   ScreenY
            sta   EnemyScreenY

; Check current state and dispatch
            lda   EnemyState
            beq   :in_patrol

:in_chase
            jsr   UpdateChase

; Check if should return to patrol (distance > ESCAPE_RANGE)
            jsr   CalculateDistance      ; Returns distance in A
            cmp   #ESCAPE_RANGE
            bcc   :stay_chase

; Return to patrol state
            stz   EnemyState
            lda   #ENEMY_SPEED_PATROL
            sta   EnemySpeed
            bra   :move_sprite

:stay_chase
            bra   :move_sprite

:in_patrol
            jsr   UpdatePatrol

; Check if should enter chase (distance < DETECTION_RANGE)
            jsr   CalculateDistance
            cmp   #DETECTION_RANGE
            bcs   :stay_patrol

; Enter chase mode
            lda   #STATE_CHASE
            sta   EnemyState
            lda   #ENEMY_SPEED_CHASE
            sta   EnemySpeed

:stay_patrol

:move_sprite
; Update enemy sprite position on screen
            pea   ENEMY_SLOT
            pei   EnemyScreenX
            pei   EnemyScreenY
            _GTEMoveSprite

            rts
```

### Step 5: Create UpdatePatrol Function

Horizontal back-and-forth movement:

```assembly
UpdatePatrol
; Check current direction
            lda   EnemyDirection
            bne   :moving_right

:moving_left
            lda   EnemyGlobalX
            sec
            sbc   EnemySpeed
            cmp   EnemyPatrolMin
            bcs   :set_left_pos

; Hit minimum, reverse direction
            lda   EnemyPatrolMin
            sta   EnemyGlobalX
            lda   #1
            sta   EnemyDirection
            rts

:set_left_pos
            sta   EnemyGlobalX
            rts

:moving_right
            lda   EnemyGlobalX
            clc
            adc   EnemySpeed
            cmp   EnemyPatrolMax
            bcc   :set_right_pos
            beq   :set_right_pos

; Hit maximum, reverse direction
            lda   EnemyPatrolMax
            sta   EnemyGlobalX
            stz   EnemyDirection
            rts

:set_right_pos
            sta   EnemyGlobalX
            rts
```

### Step 6: Create UpdateChase Function

4-directional movement toward player (moves in axis with larger delta):

```assembly
UpdateChase
; Calculate absolute deltas for both axes
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            bpl   :pos_dx
            eor   #$FFFF
            inc
:pos_dx
            sta   Tmp0                  ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            sta   Tmp1                  ; abs(deltaY)

; Compare: move in axis with larger distance
            lda   Tmp0
            cmp   Tmp1
            bcs   :move_x               ; abs(deltaX) >= abs(deltaY), move in X

:move_y
; Move in Y direction
            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            beq   :done                 ; Already aligned
            bmi   :chase_up

:chase_down
            lda   EnemyGlobalY
            clc
            adc   EnemySpeed
            cmp   #640                  ; World boundary
            bcc   :set_y
            lda   #639
:set_y
            sta   EnemyGlobalY
            bra   :done

:chase_up
            lda   EnemyGlobalY
            sec
            sbc   EnemySpeed
            bpl   :set_y
            lda   #0
            sta   EnemyGlobalY
            bra   :done

:move_x
; Move in X direction
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            beq   :done                 ; Already aligned
            bmi   :chase_left

:chase_right
            lda   EnemyGlobalX
            clc
            adc   EnemySpeed
            cmp   #960                  ; World boundary
            bcc   :set_x
            lda   #959
:set_x
            sta   EnemyGlobalX
            bra   :done

:chase_left
            lda   EnemyGlobalX
            sec
            sbc   EnemySpeed
            bpl   :set_x
            lda   #0
            sta   EnemyGlobalX

:done
            rts
```

### Step 7: Create CalculateDistance Function

Helper for detection/escape range checks (Manhattan distance):

```assembly
CalculateDistance
; Returns Manhattan distance in A: |PlayerX - EnemyX| + |PlayerY - EnemyY|
            lda   PlayerGlobalX
            sec
            sbc   EnemyGlobalX
            bpl   :pos_dx
            eor   #$FFFF                ; Two's complement
            inc
:pos_dx
            sta   Tmp0                  ; abs(deltaX)

            lda   PlayerGlobalY
            sec
            sbc   EnemyGlobalY
            bpl   :pos_dy
            eor   #$FFFF
            inc
:pos_dy
            clc
            adc   Tmp0                  ; abs(deltaY) + abs(deltaX)
            rts
```

### Step 8: Create CheckEnemyCollision Function

Sprite-to-sprite collision detection:

```assembly
CheckEnemyCollision
; Returns A=1 if collision, A=0 if no collision
            jsr   CalculateDistance
            cmp   #16                   ; Collision threshold (sprites overlap)
            bcs   :no_collision

            lda   #1                    ; Collision detected
            rts

:no_collision
            lda   #0
            rts
```

### Step 9: Integrate into Main Loop (After line 262)

Call UpdateEnemy every frame:

```assembly
; Insert after line 262: jsr UpdateCamera
            jsr UpdateCamera

; Update enemy AI and position
            jsr UpdateEnemy

; Move the sprite (player)
            pea   PLAYER_SLOT
```

### Step 10: Call InitEnemy from InitSprites (After line 348)

Initialize enemy sprite at startup:

```assembly
; Insert after line 348: _GTEAddSprite (end of player sprite init)
            _GTEAddSprite

; Initialize enemy sprite
            jsr   InitEnemy

            rts
```

### Step 11: Add Collision Debug Display

In BuildDebugStr function (around line 814), add collision status:

```assembly
; After updating DebugStr2 length (line 814)
            sta   DebugStr2

; Add collision indicator
            sep   #$20
            lda   #' '
            sta   DebugStr2+24
            lda   #'H'
            sta   DebugStr2+25
            lda   #'I'
            sta   DebugStr2+26
            lda   #'T'
            sta   DebugStr2+27
            lda   #':'
            sta   DebugStr2+28

            rep   #$20
            jsr   CheckEnemyCollision
            clc
            adc   #'0'                  ; Convert 0/1 to '0'/'1'
            sep   #$20
            sta   DebugStr2+29

            lda   #30
            sta   DebugStr2             ; Update length

            rep   #$20             ; Back to 16-bit A
            rts
```

## Implementation Order (Incremental Testing)

### Phase 1: Basic Enemy Sprite
1. Add Direct Page variables
2. Add constants
3. Create InitEnemy function
4. Call InitEnemy from InitSprites
5. **Test**: Enemy should appear on screen, stationary

### Phase 2: Patrol Behavior
6. Create UpdatePatrol function
7. Create basic UpdateEnemy (only calls UpdatePatrol)
8. Call UpdateEnemy from main loop
9. **Test**: Enemy should patrol back and forth

### Phase 3: Distance & Chase
10. Create CalculateDistance function
11. Create UpdateChase function
12. Expand UpdateEnemy to full state machine
13. **Test**: Enemy chases player when close, returns to patrol

### Phase 4: Collision Detection
14. Create CheckEnemyCollision function
15. Add collision debug display
16. **Test**: "HIT:1" appears when sprites overlap

## Key Technical Details

### Coordinate System
- X coordinates: Word units (1 unit = 2 pixels)
- Y coordinates: Pixel units (1 unit = 1 pixel)
- Enemy uses same GlobalX/Y and ScreenX/Y pattern as player

### AI Behavior
- **Detection Range**: 64 pixels (Manhattan distance)
- **Escape Range**: 96 pixels (hysteresis prevents flickering)
- **Patrol Speed**: 1 pixel/frame (slower than player's 2)
- **Chase Speed**: 3 pixels/frame (faster than player's 2)
- **Chase Movement**: 4-directional (moves only in axis with larger delta, no diagonal movement)

### Collision
- Manhattan distance < 16 pixels = collision
- 16 pixels = sprites touching (both are 16×16)
- Faster than Pythagorean distance, accurate enough for this use case

### Patrol Pattern
- Horizontal: X from 150 to 350 (200 pixel range)
- Start position: (200, 150)
- Reverses at endpoints
- Can be modified to vertical by changing UpdatePatrol to use Y coordinates

## Potential Issues & Solutions

**Issue**: Sprite tile 155 doesn't exist in tileset
**Solution**: Use tile 151 (same as player) temporarily for testing

**Issue**: Enemy gets stuck on walls
**Solution**: For now, place patrol route in open area. Tile collision for enemies is a future enhancement.

**Issue**: Chase speed too fast
**Solution**: Adjust ENEMY_SPEED_CHASE constant (try 2 instead of 3)

**Issue**: Enemy appears/disappears at screen edges
**Solution**: Screen position calculation in UpdateEnemy should handle this correctly (mirrors player logic)

## Testing Checklist

- [ ] Enemy sprite visible at (200, 150)
- [ ] Enemy patrols between X=150 and X=350
- [ ] Enemy reverses at patrol endpoints
- [ ] Enemy chases when player < 64 pixels away
- [ ] Enemy moves toward player in chase mode
- [ ] Enemy returns to patrol when player > 96 pixels away
- [ ] "HIT:0" shows when not touching
- [ ] "HIT:1" shows when sprites overlap
- [ ] Enemy respects world boundaries
- [ ] Enemy position updates correctly with camera scroll

## Future Enhancements (Out of Scope)

- Multiple enemies using arrays
- Tile collision detection for enemies
- Different enemy types with unique AI
- Enemy animation frames
- Health/damage system
- Pathfinding around obstacles
