.PHONY: all clean realclean distclean test CartoSym CQL2 DE9IM SFCollections SFGeometry GeoExtents

CARTOSYM_ABSPATH := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

ifndef EC_SDK_SRC
EC_SDK_SRC := $(CARTOSYM_ABSPATH)../eC
endif

_CF_DIR = $(EC_SDK_SRC)/
include $(_CF_DIR)crossplatform.mk

# TARGETS

all: CartoSym

CartoSym: CQL2
	+cd CartoSym && $(_MAKE)

CQL2: DE9IM SFCollections
	+cd CQL2 && $(_MAKE)

DE9IM: SFGeometry
	+cd DE9IM && $(_MAKE)

SFCollections: SFGeometry
	+cd SFCollections && $(_MAKE)

SFGeometry: GeoExtents
	+cd SFGeometry && $(_MAKE)

GeoExtents:
	+cd GeoExtents && $(_MAKE)

test: all
	+cd tests/parsing && $(_MAKE) test

clean:
	+cd CartoSym && $(_MAKE) clean
	+cd CQL2 && $(_MAKE) clean
	+cd DE9IM && $(_MAKE) clean
	+cd SFCollections && $(_MAKE) clean
	+cd SFGeometry && $(_MAKE) clean
	+cd GeoExtents && $(_MAKE) clean
	+cd tests/parsing && $(_MAKE) clean
	
realclean:
	+cd CartoSym && $(_MAKE) realclean
	+cd CQL2 && $(_MAKE) realclean
	+cd DE9IM && $(_MAKE) realclean
	+cd SFCollections && $(_MAKE) realclean
	+cd SFGeometry && $(_MAKE) realclean
	+cd GeoExtents && $(_MAKE) realclean
	+cd tests/parsing && $(_MAKE) realclean
	
distclean:
	+cd CartoSym && $(_MAKE) distclean
	+cd CQL2 && $(_MAKE) distclean
	+cd DE9IM && $(_MAKE) distclean
	+cd SFCollections && $(_MAKE) distclean
	+cd SFGeometry && $(_MAKE) distclean
	+cd GeoExtents && $(_MAKE) distclean
	+cd tests/parsing && $(_MAKE) distclean
