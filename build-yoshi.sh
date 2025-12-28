!#/bin/sh

cd demos/yoshi
../../Merlin32-1.1 -V ../../macros App.s
cd ../..
./cadius deletefile ~/Code/personal/mame/software/ss.2mg /s/YoshiGTEDemo
./cadius addfile ~/Code/personal/mame/software/ss.2mg /s demos/yoshi/YoshiGTEDemo
