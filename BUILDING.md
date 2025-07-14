# Instructions for building libCartoSym

See also [this script](fetchAndBuild.sh) (running all of these commands), fetching and building everything, and [this batch file](fetchAndBuild.bat) (for the equivalent on Windows).

## Pre-requisites

- ensure git is installed (for fetching the source code)
- ensure zlib is installed, including the "dev" package with header files
- ensure GCC or Clang is installed with working C support
- ensure GNU Make is installed

## Fetching and building

```
mkdir csbuild
cd csbuild
git clone -b extras --single-branch https://github.com/ecere/eC.git
git clone -b main --single-branch https://github.com/ecere/libCartoSym.git
cd eC
make
cd ../libCartoSym/
make test
```
