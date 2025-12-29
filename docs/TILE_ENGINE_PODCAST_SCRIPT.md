# Generic Tile Engine - Technical Deep Dive Podcast Script

**Episode:** Understanding the Apple IIgs Generic Tile Engine
**Format:** Two-host technical discussion
**Duration:** ~45-60 minutes
**Hosts:** Alex (A) and Jordan (J)

---

## INTRODUCTION [0:00 - 2:30]

**[INTRO MUSIC FADES IN AND OUT]**

**A:** Welcome back to Retro Code Deep Dives! I'm Alex.

**J:** And I'm Jordan. Today we're doing something really special - we're taking a deep dive into one of the most sophisticated 2D game engines written for the Apple IIgs.

**A:** That's right! We're talking about the Generic Tile Engine, or GTE. And I have to say, when I first started looking at this codebase, I was absolutely blown away by how clever it is.

**J:** Same here! This isn't just some simple tile mapper. This is nearly 8,000 lines of hand-optimized 65816 assembly that does things I've never seen in other retro game engines.

**A:** Before we dive in, let's set some context. The Apple IIgs came out in 1986 - it had a 2.8 MHz 65816 processor, which is a 16-bit extension of the classic 6502. It could do 320x200 resolution with 16 colors on screen.

**J:** And that's the hardware we're working with. No GPU, no hardware sprites, no tile layers. Everything has to be done in software on that 2.8 MHz CPU.

**A:** Which makes what this engine accomplishes even more impressive. Smooth scrolling, up to 16 sprites with transparency and depth sorting, parallax backgrounds, and it runs at 60 frames per second.

**J:** So let's break down how it works, starting with probably the most unique and brilliant part of the whole system...

---

## SEGMENT 1: THE CODE FIELD ARCHITECTURE [2:30 - 8:00]

**A:** Okay, so the first thing you need to understand about the Generic Tile Engine is that it doesn't use a frame buffer.

**J:** Wait, what? No frame buffer? How do you render graphics without a frame buffer?

**A:** Exactly! That was my reaction too. Most game engines work like this: you have a chunk of memory that represents the screen, you draw into it, and then you copy that memory to video RAM. Two steps.

**J:** Right, render to buffer, then blit to screen.

**A:** But GTE does something completely different. It renders directly to what they call a "code field" - and this is actual executable 65816 machine code.

**J:** Okay, you need to explain that because it sounds wild.

**A:** So picture this: instead of having pixel data, you have 6 banks of 64K each - that's 384K total - filled with assembly opcodes. These opcodes, when executed, produce the graphics on screen.

**J:** So the "rendering" process is... executing code?

**A:** Exactly! The engine builds up sequences of instructions like PEA - Push Effective Address - that push pixel data directly to the screen. When you want to render a tile, you're actually modifying the executable code that will run to display that tile.

**J:** That's insane. But also brilliant because...

**A:** Because you eliminate the entire frame buffer copy step! Traditional engines do twice the work - write to buffer, copy to screen. GTE writes once, executes the code, and boom - pixels on screen.

**J:** What's the performance gain from that?

**A:** They estimate about a 50% reduction in rendering overhead. You're literally cutting the work in half.

**J:** And I imagine this makes things like transparency and sprite compositing more complex, because you can't just blend into a buffer...

**A:** Absolutely, and we'll get to that. But first, let's talk about what happens when you actually start up this engine.

---

## SEGMENT 2: INITIALIZATION AND SETUP [8:00 - 14:30]

**J:** So you're making a game with GTE. You call GTEStartUp. What happens?

**A:** There's a very specific 7-step initialization sequence. First is IntStartUp - that enables the VBL interrupt, the vertical blank. This is crucial because the engine synchronizes all its timing to the screen refresh.

**J:** 60 Hz on NTSC, 50 Hz on PAL.

**A:** Right. Next is InitMemory - this allocates all the memory banks the engine needs. Remember, we need those 6 code field banks, plus banks for sprite data, sprite masks, tile data...

**J:** How much memory are we talking total?

**A:** For a full setup, you're looking at around 600K of memory. The Apple IIgs could have up to 8 megabytes, but in practice, most had 1-2 megs, so this is a significant chunk.

**A:** Step three is EngineReset - clears all state variables, resets scroll positions to zero, clears sprite records.

**J:** So this is when the engine goes from "allocated" to "clean slate ready to render."

**A:** Exactly. Then step four is InitGraphics, and this is where things get interesting. It calls a series of functions with names like _ShadowOn, _GrafOn, _SetSCBs...

**J:** SCBs being Scanline Control Bytes?

**A:** Yep! The IIgs has this cool feature where you can set different palettes for different scanlines. So you could have a status bar at the top with one palette, and the game area with another. The engine sets all this up.

**J:** And _ShadowOn - that's the double buffering?

**A:** Right! The IIgs has hardware support for page flipping. You can render to one page while the other is being displayed, then flip them. This eliminates flicker and tearing.

**J:** Classic technique, but really important for smooth rendering.

**A:** Then step five is InitSprites - clears the sprite data and mask banks, initializes all 16 sprite record slots.

**J:** We'll come back to sprites in detail, but quick question - why 16 sprites max?

**A:** It's a practical limit based on performance. Each sprite can overlap up to 9 tiles - that's a 3x3 region for a 16x16 pixel sprite. With 16 sprites, you're potentially affecting 144 tiles per frame. The engine can handle that at 60 FPS.

**J:** Got it. So what's step six?

**A:** InitTiles - this initializes what they call the Tile Store. This is one of the most important data structures in the engine.

**J:** We definitely need to talk about that.

**A:** We will! And finally, step seven is InitTimers. The engine includes a timer system - you can set up 4 independent timers with callbacks.

**J:** For things like enemy AI updates, animation frames, that kind of thing?

**A:** Exactly. They're frame-rate independent, so even if rendering slows down, your game logic stays consistent.

**J:** Okay, so the engine is initialized. Now let's talk about these data structures, because I know the Tile Store is where a lot of the magic happens.

---

## SEGMENT 3: THE TILE STORE AND DATA STRUCTURES [14:30 - 22:00]

**A:** Alright, the Tile Store. This is a beautiful example of data-oriented design optimized for the 65816 architecture.

**J:** So what is it?

**A:** It's a grid that represents the screen - 41 columns by 26 rows. That's 1,066 tile positions. Each position is 8x8 pixels.

**J:** Wait, the screen is only 40x25 tiles visible, right? 320 pixels wide divided by 8 is 40...

**A:** Good catch! They have one extra column and row as a border. This handles edge cases when sprites scroll partially off screen.

**J:** Smart. So 1,066 tile positions. What data does each position store?

**A:** Here's where it gets interesting. It's not a structure with 9 fields. It's 9 parallel arrays with 1,066 entries each.

**J:** Oh, like a structure-of-arrays layout instead of array-of-structures!

**A:** Exactly! And this is crucial for performance on the 65816. When you're iterating through tiles doing the same operation, you get better cache locality...

**J:** Well, not cache in the modern sense, but memory access patterns.

**A:** Right. The 65816 has very efficient indexed addressing modes. You can do `LDA TileStore,X` where X is your tile index, and it's fast.

**J:** So what are the 9 arrays?

**A:** Array 0 is TS_TILE_ID - the actual tile descriptor. This is a 16-bit value that packs the tile ID and all its flags.

**J:** What flags?

**A:** Bit 15 is priority - does this tile render over or under sprites? Bit 12 is the mask bit for transparency. Bits 10 and 9 are vertical and horizontal flip. And the lower bits are the actual tile ID, 0 through 511.

**J:** So you can have up to 512 different tiles in memory?

**A:** Yep! Each tile is 8x8 pixels, 2 bits per pixel for 4 colors. That's 128 bytes per tile including the horizontally flipped version. 512 tiles times 128 bytes is 64K - exactly one bank.

**J:** Clever. What's array 1?

**A:** TS_DIRTY - the dirty flag. This is just a word that's either 0 for clean or non-zero for dirty.

**J:** And this is key to the dirty tile system - you only re-render tiles that have changed.

**A:** Exactly. We'll talk more about that when we get to rendering. Array 2 is TS_SPRITE_FLAG - this is a bitfield where each bit represents one of the 16 sprite slots.

**J:** So if bit 3 is set, sprite 3 is overlapping this tile?

**A:** Precisely. This lets the renderer know if it needs to composite sprites when drawing this tile.

**A:** Array 3 is TS_TILE_ADDR - a cached address of where the tile graphics live in the tile data bank. This is pre-calculated so rendering is faster.

**J:** Makes sense - calculate once, use many times.

**A:** Arrays 4 and 5 are TS_CODE_ADDR_LOW and TS_CODE_ADDR_HIGH - these point to where in the code field this tile's rendering code is located.

**J:** Because remember, we're not rendering to pixels, we're modifying executable code.

**A:** Right! Array 6 is TS_WORD_OFFSET for addressing math. Array 7 is TS_JMP_ADDR for dynamic tiles...

**J:** Wait, dynamic tiles?

**A:** Oh yeah, you can have tiles that call custom rendering code! Great for special effects, animated tiles, parallax. Each dynamic tile gets 32 bytes of "snippet space" to do whatever it wants.

**J:** That's really flexible.

**A:** And finally, array 8 is TS_SCREEN_ADDR - the cached screen location for dirty rendering mode.

**J:** Okay, so that's the Tile Store - 9 parallel arrays, 1,066 entries each. What about sprite data?

---

## SEGMENT 4: THE SPRITE SYSTEM [22:00 - 30:30]

**A:** Sprites are fascinating in this engine because of how they solve the smooth scrolling problem.

**J:** What's the smooth scrolling problem?

**A:** Well, remember that everything is aligned to an 8x8 tile grid. But you want sprites to move one pixel at a time, not in 8-pixel jumps.

**J:** Right, smooth movement.

**A:** So the engine pre-renders each sprite in 4 different variations.

**J:** Four?

**A:** Think about it - if you're moving in single-pixel increments, but your grid is 8 pixels, you need different clip masks depending on where in that 8x8 region the sprite starts.

**J:** Oh! So variation 0 is aligned to the grid, variation 1 is offset by 4 pixels horizontally...

**A:** Exactly. You have offsets at (0,0), (4,0), (0,4), and (4,4). This gives you smooth movement in any direction.

**J:** But that means you're storing 4 copies of each sprite?

**A:** Yes. Each sprite is 16x16 pixels. With 4 variations, plus masks for transparency, you're using quite a bit of memory. This is stored in two 64K banks - spritedata and spritemask.

**J:** And the masks are for compositing - blending the sprite with the background tiles?

**A:** Right. When a sprite overlaps a tile, the renderer needs to know which pixels are transparent. The mask provides that information.

**A:** Now, each sprite also has a record - 42 bytes of data. This includes the sprite's position, its status flags, which tile store entries it overlaps...

**J:** How does the engine figure out which tiles a sprite overlaps?

**A:** Great question! There's another data structure called TileStoreLookup. It's a double-resolution table - 82 columns by 52 rows.

**J:** Double the tile grid.

**A:** Yep. Given a sprite's X and Y position, you divide by 4 to get an index into this lookup table, and it tells you which tile store entry that position maps to.

**J:** So it's like a spatial hash for quick intersection tests.

**A:** Exactly! O(1) lookup to find which tiles any sprite position overlaps. The engine uses this when you move a sprite - it marks the old tiles dirty, calculates the new tiles the sprite covers, and marks those dirty too.

**J:** And sprites also have a priority system, right?

**A:** Yes! Sprites are kept in a linked list sorted by their Y coordinate. This gives you automatic depth ordering - sprites with higher Y values are "closer to the camera" and render on top.

**J:** Classic painter's algorithm.

**A:** Right. The sprite record includes SORTED_PREV and SORTED_NEXT pointers to maintain this list. When you move a sprite vertically, the engine re-sorts it in the list.

**J:** Okay, so we've got tiles in the tile store, sprites in their records and data banks. Now how does this actually render to the screen?

---

## SEGMENT 5: THE RENDERING PIPELINE [30:30 - 40:00]

**A:** Alright, this is where it all comes together. You call GTERender once per frame, and it executes a 12-step pipeline.

**J:** Twelve steps! Let's walk through them.

**A:** Step 1: _DoTimers. Remember those 4 timer slots? The engine checks if any have expired and calls their callbacks.

**J:** So game logic can run before rendering.

**A:** Yep. Step 2: _ApplyBG0YPos. This sets up the vertical scroll position. Remember the screen is 200 pixels tall, but your tilemap can be much larger.

**J:** Right, so this is figuring out which rows of tiles are visible.

**A:** Exactly. And it's setting up these lookup tables called BTableLow and BTableHigh that map virtual scanlines to physical screen addresses.

**J:** Because scrolling is just changing which part of the tilemap you're looking at.

**A:** Right. Steps 3, 4, and 5 are similar - ApplyBG1YPos and the X position setups for both background layers. The engine supports two independent scrolling layers for parallax effects.

**J:** Classic parallax - you move the foreground faster than the background to create depth.

**A:** Step 6 is where sprites come in: _RenderSprites. This processes all the sprite changes from the frame.

**J:** What kind of changes?

**A:** If a sprite moved, the engine marks both the old and new tile positions dirty. If a sprite was added or removed, same thing. It also calculates which tiles each sprite now overlaps and updates those TS_SPRITE_FLAG bitfields we talked about.

**J:** So by the end of this step, the tile store knows exactly which tiles have sprites on them.

**A:** Correct. Step 7: _UpdateBG0TileMap. This is the scrolling detection.

**J:** How does that work?

**A:** The engine calculates the current visible tile region based on the scroll position. Then it compares that to the previous frame's visible region.

**J:** And if you scrolled, there's a new strip of tiles that just came into view...

**A:** Exactly! If you scrolled right, there's a new column of tiles on the right edge. If you scrolled down, a new row at the bottom. The engine copies those tile descriptors from the tilemap into the tile store and marks them dirty.

**J:** That's the "lazy copy-on-scroll" optimization?

**A:** Yes! You only copy and render the tiles that actually became visible. If you're scrolling right at normal speed, that's maybe 26 tiles per frame, not the full 1,066.

**J:** Huge savings.

**A:** Step 8 is the big one: _ApplyTiles. This is where actual rendering happens.

**J:** Finally!

**A:** The engine has a dirty tile queue - a circular buffer that contains the indices of all dirty tiles. _ApplyTiles pops tiles from this queue one by one and renders them.

**J:** How does rendering work for a single tile?

**A:** It depends on whether there are sprites on that tile. If TS_SPRITE_FLAG is zero - no sprites - the engine calls what's called K_TS_BASE_TILE_DISP. This is the fast path.

**J:** And this is where you're modifying the code field?

**A:** Right. The tile renderer takes the tile graphics from the tile data bank and writes the appropriate opcodes into the code field at the address stored in TS_CODE_ADDR.

**J:** What if there ARE sprites on the tile?

**A:** Then it gets more complex. The engine checks how many sprites - 1, 2, 3, or 4 - and dispatches to specialized compositor functions.

**J:** Why specialize for the number of sprites?

**A:** Performance! Compositing one sprite with a tile is much simpler than blending four sprites with depth ordering and transparency. The engine has optimized code paths for each case.

**A:** There's even a super-optimized path called K_TS_ONE_SPRITE that handles the single-sprite case with variants for different flip combinations.

**J:** And these compositors are blending the sprite pixel data with the tile data using the masks?

**A:** Exactly. For each pixel, it checks the mask. If the sprite is transparent there, use the tile pixel. Otherwise, use the sprite pixel. And it respects the TILE_PRIORITY_BIT - tiles can be in front of or behind sprites.

**J:** That's how you do things like platforms that sprites walk behind.

**A:** Right! Steps 9 and 10 are _ApplyBG0XPos and _ApplyBG1XPos - these patch the code field with the horizontal scroll offsets. Step 11 is the overlay system for things like HUDs.

**J:** And step 12?

**A:** _BltRange - the blitter. This is where the code field actually executes and produces pixels on the screen.

**J:** So THAT'S when the actual rendering happens - everything before was building up the code that will render.

**A:** Exactly. The blitter copies the code field to video memory, and because of the shadowing system we mentioned earlier, this happens during vertical blank for flicker-free display.

**J:** And then the frame is done!

**A:** Yep. On to the next frame. And here's the beautiful part - if nothing changes between frames, the dirty queue is empty, and _ApplyTiles does almost nothing.

**J:** So a static screen is essentially free?

**A:** Basically! You're only paying for the blitter operation. All the tile rendering is skipped.

---

## SEGMENT 6: RENDERING MODES AND OPTIMIZATIONS [40:00 - 47:00]

**J:** You mentioned earlier that there are different rendering modes. What's that about?

**A:** The engine has 5 pluggable rendering modes, and you choose based on what your game needs.

**J:** Give me the rundown.

**A:** Fast Mode assumes all your tiles are the same type - no transparency, no dynamic tiles. It uses PEA opcodes throughout, which are very fast on the 65816.

**J:** Fastest rendering, but least flexible.

**A:** Right. Slow Mode handles mixed tile types - some with transparency, some without. It has to do dynamic dispatch per tile, so it's slower but more flexible.

**J:** What about Dynamic Mode?

**A:** Dynamic Mode is for when you want custom rendering per tile. Remember those dynamic tiles with snippet space? This mode calls user-provided callbacks for each tile.

**J:** Slowest but most flexible.

**A:** Exactly. Dirty Mode is interesting - it's optimized for mostly static screens. Instead of rendering to the code field, it renders directly to the screen for dirty tiles only.

**J:** So you skip the whole code field step for static scenes?

**A:** Yep! Great for puzzle games or strategy games where most of the screen doesn't change.

**A:** And finally, Two-Layer Mode handles both BG0 and BG1 with different rendering modes for each layer.

**J:** For parallax backgrounds?

**A:** Right. You might have a fast-mode background layer that rarely changes, and a slow-mode foreground layer with all the gameplay.

**J:** And these are all pluggable - you can switch between them?

**A:** You set them up when you configure the engine. There are 5 function pointers per mode that handle different aspects of rendering.

**J:** Like a rendering API.

**A:** Exactly. K_TS_BASE_TILE_DISP for clean tiles, K_TS_SPRITE_TILE_DISP for tiles with sprites, K_TS_ONE_SPRITE for the optimized single-sprite path...

**J:** This is really well architected.

**A:** It is! And it gives game developers a lot of control over the performance/features tradeoff.

---

## SEGMENT 7: ASSET PIPELINE AND TOOLING [47:00 - 52:00]

**J:** So let's say I'm making a game with this engine. I've got my art in PNG files, my level designed in Tiled. How do I get that into the engine?

**A:** The engine includes a suite of JavaScript tools for asset conversion.

**J:** JavaScript? I thought this was all 65816 assembly?

**A:** The engine is! But the conversion tools run on your modern development machine. They're Node.js scripts.

**J:** Got it. What's available?

**A:** png2iigs.js converts PNG images to the IIgs 4-color format. You feed it a PNG, it extracts or generates a 4-color palette, converts pixels to 2 bits per pixel, and outputs a binary file you can include in your assembly.

**J:** And it handles transparency?

**A:** Yep! PNG transparency becomes mask data.

**A:** Then there's tiled2iigs.js. Tiled is a popular tile map editor. This script imports the JSON export from Tiled and generates Merlin32 assembly source with your tilemap data.

**J:** Merlin32 being an assembler?

**A:** Right, a modern assembler for 65816 code. The script outputs a file with all your tile IDs as `dw` directives - define word.

**J:** And it preserves flip flags and tile IDs?

**A:** Exactly. If you flipped a tile in Tiled, that TILE_HFLIP_BIT gets set in the output.

**A:** mksprite.js creates sprite stamps. You give it a 16x16 PNG, and it generates the 4 variations we talked about, plus all the mask data.

**J:** So you get that whole data/mask interleaved format ready to load?

**A:** Yep. There are also tools for rotation tables, scaling tables... anything you need to pre-calculate for effects.

**J:** This makes the workflow pretty smooth - design in modern tools, convert to IIgs format, build with Merlin32.

**A:** That's the idea. You're not hand-editing hex dumps or anything crazy.

---

## SEGMENT 8: PERFORMANCE CHARACTERISTICS [52:00 - 56:30]

**J:** Let's talk numbers. What kind of performance does this engine achieve?

**A:** In the best case - Fast Mode, no sprites, static screen - you can push around 60,000 tiles per second at 60 FPS.

**J:** That's... 1,000 tiles per frame?

**A:** Yep. Basically the entire screen plus some.

**J:** What about typical case?

**A:** Typical game scenario - Slow Mode, 8 sprites moving around, scrolling - you're doing about 3,000 tiles per second. That's around 50 dirty tiles per frame at 60 FPS.

**J:** Which is way less than the full screen.

**A:** Right! That's the dirty tile system at work. You're only rendering what changed.

**J:** Worst case?

**A:** Dynamic Mode, 16 sprites, full screen dirty - you're looking at 30 to 60 FPS depending on how complex your dynamic tile callbacks are.

**J:** Still playable!

**A:** Yeah, and you rarely have the full screen dirty. Even with lots of sprites, the dirty tile system keeps things manageable.

**J:** What are the hard limits?

**A:** 512 tiles maximum in memory - that's the 64K tile data bank limit. 16 active sprites. 1,066 tile store entries. 4 timers. You can have up to 3 overlays for HUDs and effects.

**J:** And scrolling limits are based on your tilemap size?

**A:** Right. If you have a 64-tile wide tilemap, that's 512 pixels. Minus the 320-pixel screen width, you can scroll 192 pixels horizontally.

**J:** So you'd design your tilemap based on how much scrolling area you need.

**A:** Exactly.

---

## SEGMENT 9: REAL-WORLD USAGE AND EXAMPLES [56:30 - 60:30]

**J:** Are there actual games built with this engine?

**A:** The repository includes several demo projects. There's a Yoshi demo, a Pacman demo, a Zelda-style demo...

**J:** So different game genres to show off the engine's flexibility?

**A:** Exactly. The Yoshi demo shows smooth scrolling and sprite animation. The Zelda demo shows how to do a top-down adventure game with multiple screens.

**J:** And these are all running on real Apple IIgs hardware?

**A:** Yep! You can run them in an emulator too, but they're designed for the actual hardware.

**J:** What's the development process like?

**A:** You write your game logic in 65816 assembly, use the GTE toolbox API we talked about, run the asset conversion tools, build with Merlin32, and you get a disk image you can boot on a IIgs.

**J:** And the engine handles all the low-level graphics work?

**A:** Exactly. You just call GTESetBG0Origin to scroll, GTEAddSprite to add sprites, GTERender each frame, and the engine does the rest.

**J:** That's the power of a good engine - it abstracts away the complexity.

**A:** Right. You don't need to know about code fields or dirty tile queues or sprite compositing. You just use the API.

**J:** Though understanding how it works helps you optimize your game.

**A:** Absolutely. If you know that dynamic tiles are expensive, you might limit how many you use. If you know sprites mark tiles dirty, you might batch sprite movements.

**J:** Knowing the implementation details makes you a better user of the API.

---

## CONCLUSION [60:30 - 63:00]

**A:** Alright, let's wrap this up. We've covered a lot of ground today.

**J:** We really have! From the code field architecture to the initialization sequence, the data structures, the rendering pipeline...

**A:** The sprite system, the dirty tile optimization, rendering modes, asset tools...

**J:** What's your big takeaway from studying this engine?

**A:** I think it's a masterclass in optimization for constrained hardware. Every design decision is deliberate. The code field eliminates frame buffer overhead. Parallel arrays optimize for 65816 addressing modes. The dirty tile system minimizes redundant work.

**J:** And it's all done in assembly - hand-optimized for performance.

**A:** Right. This isn't C code compiled for the 65816. This is hand-crafted assembly where every instruction counts.

**J:** It's also really well architected. The pluggable rendering modes, the clean API, the separation between engine and game logic.

**A:** You could absolutely build a commercial-quality game with this. The demos prove it works.

**J:** If you're interested in retro game development, or if you want to understand how tile engines work at a fundamental level, this is an amazing resource.

**A:** The code is all open source. You can read through it, build the demos, even contribute if you want.

**J:** We'll put links in the show notes to the repository and the technical documentation.

**A:** And if you want to see more deep dives like this - other retro systems, modern engines, whatever - let us know!

**J:** Thanks for listening to Retro Code Deep Dives. I'm Jordan.

**A:** And I'm Alex. Until next time, happy coding!

**[OUTRO MUSIC FADES IN]**

---

## SHOW NOTES AND REFERENCES

### Key Topics Covered:
- Code field architecture vs. traditional frame buffers
- 7-step engine initialization sequence
- Tile Store: 9 parallel arrays for cache efficiency
- Sprite system: 4 variations for smooth pixel movement
- 12-step rendering pipeline
- Dirty tile queue optimization
- 5 rendering modes: Fast, Slow, Dynamic, Dirty, Two-Layer
- Asset conversion pipeline (PNG, Tiled, sprites)
- Performance characteristics and limits

### Technical Specifications:
- Display: 320×200 pixels, 4 colors (2 bits per pixel)
- Tiles: 8×8 pixels, 512 maximum in memory
- Sprites: 16×16 pixels, 16 active maximum
- Code Field: 6 banks × 64KB = 384KB
- Tile Store: 1,066 entries (41×26 grid)
- Performance: 30-60 FPS depending on complexity

### Repository Links:
- Main repository: [Include actual GitHub URL]
- Technical documentation: TILE_ENGINE_TECHNICAL_OVERVIEW.md
- Demo projects: /demos/ directory
- Asset tools: /tools/ directory

### Recommended Reading:
- 65816 Programming Manual
- Apple IIgs Hardware Reference
- Super High Resolution Graphics Guide
- Tiled Map Editor documentation

### Timestamps:
- [0:00] Introduction
- [2:30] Code Field Architecture
- [8:00] Initialization and Setup
- [14:30] Tile Store and Data Structures
- [22:00] Sprite System
- [30:30] Rendering Pipeline
- [40:00] Rendering Modes and Optimizations
- [47:00] Asset Pipeline and Tooling
- [52:00] Performance Characteristics
- [56:30] Real-World Usage and Examples
- [60:30] Conclusion

---

**Production Notes:**
- Estimated duration: 60-63 minutes
- Format: Conversational two-host discussion
- Target audience: Intermediate to advanced programmers interested in game engines and retro development
- Technical level: Deep but accessible - explains concepts without assuming prior Apple IIgs knowledge
- Suggested music: Retro chip tune intro/outro, minimal background during discussion
