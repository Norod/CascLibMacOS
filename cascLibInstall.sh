#!/bin/bash

# This script builds the Mac CascLib framework
# It downloads the source from https://github.com/ladislav-zezula/CascLib and does cmake/make/copies

mkdir ./CascLib
mkdir ./CascLib/lib
cd ../
git clone git@github.com:ladislav-zezula/CascLib.git
cd ./CascLib
git fetch -p --tags
git pull
cmake ./
make

mv ./casc.framework ../CascLibMacOS/CascLib/lib/

cp -Rp ./listfile ../CascLibMacOS/CascLib/listfile
cp -Rp ./src/ ../CascLibMacOS/CascLib/include

make clean
rm -rf ./CMakeFiles

cd ../CascLibMacOS/cascLibTest
open ./cascLibTest.xcodeproj
