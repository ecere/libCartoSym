@echo off
echo This script attempts to fetch and build libCartoSym and its dependency libraries.
echo Please make sure you have git installed to fetch the source code from the eC and libCartoSym repositories.
echo Please make sure you have GCC (MinGW-w64) or Clang, and GNU Make (mingw32-make) installed.
echo Please make sure you have zlib (header files and library) installed.
echo:
echo Building in 'csbuild' directory...

mkdir csbuild
cd csbuild

echo Fetching eC core development environment...
git clone -b main --single-branch https://github.com/ecere/eC.git

echo Fetching libCartoSym...
git clone -b main --single-branch https://github.com/ecere/libCartoSym.git

echo Building eC development environment...
cd eC
mingw32-make -j4

echo Building libCartoSym...
cd ..\libCartoSym\
mingw32-make -j4 test

echo:
echo All done! Thank you for trying out and using libCartoSym.
