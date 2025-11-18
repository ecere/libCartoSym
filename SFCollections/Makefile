ifneq ($(V),1)
.SILENT:
endif

.PHONY: all objdir cleantarget clean realclean distclean

# CORE VARIABLES

MODULE := SFCollections
VERSION := 0.0.1
CONFIG := release
ifndef COMPILER
COMPILER := default
endif

TARGET_TYPE = sharedlib

# FLAGS

ECFLAGS =
ifndef DEBIAN_PACKAGE
CFLAGS =
LDFLAGS =
endif
PRJ_CFLAGS =
CECFLAGS =
OFLAGS =
LIBS =

ifdef DEBUG
NOSTRIP := y
endif

CONSOLE = -mwindows

# INCLUDES

SFCOLLECTIONS_ABSPATH := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

CARTOSYM_ABSPATH := $(realpath $(dir $(SFCOLLECTIONS_ABSPATH))../)

ifndef EC_SDK_SRC
EC_SDK_SRC := $(realpath $(dir $(CARTOSYM_ABSPATH)/)../eC)
endif

_CF_DIR = $(EC_SDK_SRC)/

include $(_CF_DIR)crossplatform.mk
include $(_CF_DIR)default.cf

ifndef WINDOWS_HOST
ifdef OSX_HOST
export DYLD_LIBRARY_PATH := $(DYLD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
export EC_LIB_PATH := $(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)lib
else
export LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
endif
else
export PATH := $(PATH);$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
endif

# POST-INCLUDES VARIABLES

OBJ = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/

RES =

TARGET_NAME := SFCollections

# PLATFORM-SPECIFIC OPTIONS

ifdef WINDOWS_TARGET

OFLAGS += -static-libgcc

else

ifdef OSX_TARGET
OFLAGS += $(if $(ENABLE_PYTHON_RPATHS),-Wl$(comma)-rpath$(comma)'@loader_path/../../ecrt/lib',)
else
OFLAGS += $(if $(ENABLE_PYTHON_RPATHS),-Wl$(comma)-rpath='$$ORIGIN/../../ecrt/lib',)
endif

endif

TARGET = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/$(LP)$(TARGET_NAME)$(OUT)

_ECSOURCES = \
	$(EC_SDK_SRC)/extras/iso8601.ec \
	deps/MinimalProjection.ec \
	deps/TimeIntervals.ec \
	FeatureCollection.ec \
	geoJSON.ec \
	VectorFeatures.ec \
	wkbc.ec

ECSOURCES = $(call shwspace,$(_ECSOURCES))

_COBJECTS = $(addprefix $(OBJ),$(patsubst %.ec,%$(C),$(notdir $(_ECSOURCES))))

_SYMBOLS = $(addprefix $(OBJ),$(patsubst %.ec,%$(S),$(notdir $(_ECSOURCES))))

_IMPORTS = $(addprefix $(OBJ),$(patsubst %.ec,%$(I),$(notdir $(_ECSOURCES))))

_ECOBJECTS = $(addprefix $(OBJ),$(patsubst %.ec,%$(O),$(notdir $(_ECSOURCES))))

_BOWLS = $(addprefix $(OBJ),$(patsubst %.ec,%$(B),$(notdir $(_ECSOURCES))))

COBJECTS = $(call shwspace,$(_COBJECTS))

SYMBOLS = $(call shwspace,$(_SYMBOLS))

IMPORTS = $(call shwspace,$(_IMPORTS))

ECOBJECTS = $(call shwspace,$(_ECOBJECTS))

BOWLS = $(call shwspace,$(_BOWLS))

OBJECTS = $(ECOBJECTS) $(OBJ)$(MODULE).main$(O)

SOURCES = $(ECSOURCES)

RESOURCES =

ifdef USE_RESOURCES_EAR
RESOURCES_EAR =
else
RESOURCES_EAR = $(RESOURCES)
endif

LIBS += $(SHAREDLIB) $(EXECUTABLE) $(LINKOPT)

ifndef STATIC_LIBRARY_TARGET
OFLAGS += -L$(EC_SDK_SRC)/$(SODESTDIR)
LIBS += \
	$(call _L,ecrt)
endif

PRJ_CFLAGS += \
	 $(if $(DEBUG), -g, -O2 -ffast-math) $(FPIC) -Wall -DREPOSITORY_VERSION="\"$(REPOSITORY_VER)\"" \
			 -DIMPORT_STATIC=\"\"

ECFLAGS += -module $(MODULE)
CECFLAGS += -cpp $(_CPP)

# TARGETS

all: objdir $(TARGET)

objdir:
	$(if $(wildcard $(OBJ)),,$(call mkdir,$(OBJ)))
	$(if $(ECERE_SDK_SRC),$(if $(wildcard $(call escspace,$(ECERE_SDK_SRC)/crossplatform.mk)),,@$(call echo,Ecere SDK Source Warning: The value of ECERE_SDK_SRC is pointing to an incorrect ($(ECERE_SDK_SRC)) location.)),)
	$(if $(ECERE_SDK_SRC),,$(if $(ECP_DEBUG)$(ECC_DEBUG)$(ECS_DEBUG),@$(call echo,ECC Debug Warning: Please define ECERE_SDK_SRC before using ECP_DEBUG, ECC_DEBUG or ECS_DEBUG),))

$(OBJ)$(MODULE).main.ec: $(SYMBOLS) $(COBJECTS)
	@$(call rm,$(OBJ)symbols.lst)
	@$(call touch,$(OBJ)symbols.lst)
	$(call addtolistfile,$(SYMBOLS),$(OBJ)symbols.lst)
	$(call addtolistfile,$(IMPORTS),$(OBJ)symbols.lst)
	$(ECS) $(ARCH_FLAGS) $(ECSLIBOPT) @$(OBJ)symbols.lst -symbols obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX) -o $(call quote_path,$@)

$(OBJ)$(MODULE).main.c: $(OBJ)$(MODULE).main.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(OBJ)$(MODULE).main.ec -o $(OBJ)$(MODULE).main.sym -symbols $(OBJ)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(OBJ)$(MODULE).main.ec -o $(call quote_path,$@) -symbols $(OBJ)

$(SYMBOLS): | objdir
$(OBJECTS): | objdir
$(TARGET): $(SOURCES) $(RESOURCES_EAR) $(SYMBOLS) $(OBJECTS) | objdir
	@$(call rm,$(OBJ)objects.lst)
	@$(call touch,$(OBJ)objects.lst)
	$(call addtolistfile,$(OBJ)$(MODULE).main$(O),$(OBJ)objects.lst)
	$(call addtolistfile,$(ECOBJECTS),$(OBJ)objects.lst)
ifndef STATIC_LIBRARY_TARGET
	$(LD) $(OFLAGS) @$(OBJ)objects.lst $(LIBS) -o $(TARGET) $(INSTALLNAME) $(SONAME)
ifdef OSX_TARGET
	install_name_tool -id @rpath/lib$(MODULE).dylib $(TARGET)
endif
ifndef NOSTRIP
	$(STRIP) $(STRIPOPT) $(TARGET)
endif
else
ifdef WINDOWS_HOST
	$(AR) rcs $(TARGET) @$(OBJ)objects.lst $(LIBS)
else
	$(AR) rcs $(TARGET) $(OBJECTS) $(LIBS)
endif
endif
ifdef SHARED_LIBRARY_TARGET
ifdef LINUX_TARGET
ifdef LINUX_HOST
	$(if $(basename $(basename $(VER))),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(OBJ)$(LP)$(MODULE)$(SO)$(basename $(basename $(VER))),)
	$(if $(basename $(VER)),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(OBJ)$(LP)$(MODULE)$(SO)$(basename $(VER)),)
	$(if $(VER),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(OBJ)$(LP)$(MODULE)$(SO),)
endif
endif
endif
	$(call mkdir,$(CARTOSYM_ABSPATH)/$(SODESTDIR))
	$(call cp,$(TARGET),$(CARTOSYM_ABSPATH)/$(SODESTDIR))
ifdef LINUX_TARGET
	$(if $(basename $(basename $(VER))),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(CARTOSYM_ABSPATH)/$(SODESTDIR)$(LP)$(MODULE)$(SO)$(basename $(basename $(VER))),)
	$(if $(basename $(VER)),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(CARTOSYM_ABSPATH)/$(SODESTDIR)$(LP)$(MODULE)$(SO)$(basename $(VER)),)
	$(if $(VER),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(CARTOSYM_ABSPATH)/$(SODESTDIR)$(LP)$(MODULE)$(SO),)
endif

# SYMBOL RULES

$(OBJ)iso8601.sym: $(EC_SDK_SRC)/extras/iso8601.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,$(EC_SDK_SRC)/extras/iso8601.ec) -o $(call quote_path,$@)

$(OBJ)MinimalProjection.sym: deps/MinimalProjection.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,deps/MinimalProjection.ec) -o $(call quote_path,$@)

$(OBJ)TimeIntervals.sym: deps/TimeIntervals.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,deps/TimeIntervals.ec) -o $(call quote_path,$@)

$(OBJ)FeatureCollection.sym: FeatureCollection.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,FeatureCollection.ec) -o $(call quote_path,$@)

$(OBJ)geoJSON.sym: geoJSON.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,geoJSON.ec) -o $(call quote_path,$@)

$(OBJ)VectorFeatures.sym: VectorFeatures.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,VectorFeatures.ec) -o $(call quote_path,$@)

$(OBJ)wkbc.sym: wkbc.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,wkbc.ec) -o $(call quote_path,$@)

# C OBJECT RULES

$(OBJ)iso8601.c: $(EC_SDK_SRC)/extras/iso8601.ec $(OBJ)iso8601.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(EC_SDK_SRC)/extras/iso8601.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)MinimalProjection.c: deps/MinimalProjection.ec $(OBJ)MinimalProjection.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,deps/MinimalProjection.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)TimeIntervals.c: deps/TimeIntervals.ec $(OBJ)TimeIntervals.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,deps/TimeIntervals.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)FeatureCollection.c: FeatureCollection.ec $(OBJ)FeatureCollection.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,FeatureCollection.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)geoJSON.c: geoJSON.ec $(OBJ)geoJSON.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,geoJSON.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)VectorFeatures.c: VectorFeatures.ec $(OBJ)VectorFeatures.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,VectorFeatures.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)wkbc.c: wkbc.ec $(OBJ)wkbc.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,wkbc.ec) -o $(call quote_path,$@) -symbols $(OBJ)

# OBJECT RULES

$(OBJ)iso8601$(O): $(OBJ)iso8601.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)iso8601.c) -o $(call quote_path,$@)

$(OBJ)MinimalProjection$(O): $(OBJ)MinimalProjection.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)MinimalProjection.c) -o $(call quote_path,$@)

$(OBJ)TimeIntervals$(O): $(OBJ)TimeIntervals.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)TimeIntervals.c) -o $(call quote_path,$@)

$(OBJ)FeatureCollection$(O): $(OBJ)FeatureCollection.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)FeatureCollection.c) -o $(call quote_path,$@)

$(OBJ)geoJSON$(O): $(OBJ)geoJSON.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)geoJSON.c) -o $(call quote_path,$@)

$(OBJ)VectorFeatures$(O): $(OBJ)VectorFeatures.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)VectorFeatures.c) -o $(call quote_path,$@)

$(OBJ)wkbc$(O): $(OBJ)wkbc.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)wkbc.c) -o $(call quote_path,$@)

$(OBJ)$(MODULE).main$(O): $(OBJ)$(MODULE).main.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(OBJ)$(MODULE).main.c -o $(call quote_path,$@)

cleantarget:
	$(call rm,$(OBJ)$(MODULE).main$(O) $(OBJ)$(MODULE).main.c $(OBJ)$(MODULE).main.ec $(OBJ)$(MODULE).main$(I) $(OBJ)$(MODULE).main$(S))
	$(call rm,$(OBJ)symbols.lst)
	$(call rm,$(OBJ)objects.lst)
	$(call rm,$(TARGET))
ifdef SHARED_LIBRARY_TARGET
ifdef LINUX_TARGET
ifdef LINUX_HOST
	$(call rm,$(OBJ)$(LP)$(MODULE)$(SO)$(basename $(basename $(VER))))
	$(call rm,$(OBJ)$(LP)$(MODULE)$(SO)$(basename $(VER)))
	$(call rm,$(OBJ)$(LP)$(MODULE)$(SO))
endif
endif
endif

clean: cleantarget
	$(call rm,$(_OBJECTS))
	$(call rm,$(_ECOBJECTS))
	$(call rm,$(_COBJECTS))
	$(call rm,$(_BOWLS))
	$(call rm,$(_IMPORTS))
	$(call rm,$(_SYMBOLS))

realclean: cleantarget
	$(call rmr,$(OBJ))

distclean: cleantarget
	$(call rmr,obj/)
	$(call rmr,.configs/)
	$(call rm,*.ews)
	$(call rm,*.Makefile)
