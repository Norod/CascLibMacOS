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
git checkout 1.11
CMAKE_C_COMPILER=$(xcrun -find cc)
CMAKE_CXX_COMPILER=$(xcrun -find c++)
#cmake -G 'Unix Makefiles' -DCMAKE_C_COMPILER=$CMAKE_C_COMPILER -DCMAKE_CXX_COMPILER=$CMAKE_CXX_COMPILER -DCMAKE_BUILD_TYPE=Release ./
cmake -G 'Unix Makefiles' -DCMAKE_C_COMPILER=$CMAKE_C_COMPILER -DCMAKE_CXX_COMPILER=$CMAKE_CXX_COMPILER -DCMAKE_BUILD_TYPE=Debug ./
make

mv ./casc.framework ../CascLibMacOS/CascLib/lib/casc.framework

cp -Rp ./listfile ../CascLibMacOS/CascLib/listfile
cp -Rp ./src/ ../CascLibMacOS/CascLib/include

make clean
rm -rf ./CMakeFiles

cd ../CascLibMacOS/cascLibTest
open ./cascLibTest.xcodeproj
