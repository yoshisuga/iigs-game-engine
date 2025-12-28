# Exploring GTE 

Using a tileset for Ys 2, as I wanted to see the sequel on the IIGS.

Used the Sharp X1 tileset here:
https://www.spriters-resource.com/sharp_x1/ysthefinalchapter/

Compacted the tile set manually and asked Claude to use a 16-color palette for the IIGS. 

## Environment

- macOS 26.1
- `nvm` for node environment
- Use node version `v18.20.4` for compatibility for the tools


## Commands to build

 cd demos/yoshi 
 ../../Merlin32-1.1 -V ../../macros App.s 

 # disk image
 cd ../..
 ./cadius deletefile ~/Code/personal/mame/software/ss.2mg /s/YoshiGTEDemo
 ./cadius addfile ~/Code/personal/mame/software/ss.2mg /s demos/yoshi/YoshiGTEDemo
 ./cadius catalog ~/Code/personal/mame/software/ss.2mg

## Tile sets build
node ../../tools/png2iigs.js assets/00lanceVillage.png --max-tiles 488 --as-tile-data > gen/LanceVillage.TileSet.s

## Tile map build
node ../../tools/tiled2iigs.js ./assets/Ys2LanceVillageGS.json --no-gen-tiles --output-dir ./gen

Edit the script for the tile count

