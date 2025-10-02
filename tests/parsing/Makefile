ifneq ($(V),1)
.SILENT:
endif

.PHONY: all objdir cleantarget clean realclean distclean

# CORE VARIABLES

MODULE := CartoSymParsing
VERSION := 0.0.1
CONFIG := release
ifndef COMPILER
COMPILER := default
endif

TARGET_TYPE = executable

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

CONSOLE = -mconsole

# INCLUDES

PARSING_ABSPATH := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

CARTOSYM_ABSPATH := $(PARSING_ABSPATH)../../

ifndef EC_SDK_SRC
EC_SDK_SRC := $(CARTOSYM_ABSPATH)../eC
endif

_CF_DIR = $(EC_SDK_SRC)/

include $(_CF_DIR)crossplatform.mk
include $(_CF_DIR)default.cf

RUNNER =

ifndef WINDOWS_HOST
ifdef OSX_HOST
export DYLD_LIBRARY_PATH := $(DYLD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
else
export LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
endif
ifdef WINDOWS_TARGET
export WINEPATH := $(WINEPATH);$(CARTOSYM_ABSPATH)/$(SODESTDIR);$(EC_SDK_SRC)/$(SODESTDIR)
RUNNER = wine
endif
else
export PATH := $(PATH);$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
endif

# POST-INCLUDES VARIABLES

OBJ = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/

RES =

TARGET_NAME := CartoSymParsing

TARGET = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/$(TARGET_NAME)$(OUT)

_ECSOURCES = \
	$(EC_SDK_SRC)/extras/testing/testingFramework.ec \
	$(EC_SDK_SRC)/extras/XMLParser.ec \
	CartoSymParsing.ec \
	../../SLDSE/sldWriter.ec \
	../../SLDSE/sldParser.ec \
	../../MapboxStyles/mbglParser.ec \
	../../MapboxStyles/gggLevels.ec \
	../../MapboxStyles/mbglWriter.ec

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

# PLATFORM-SPECIFIC OPTIONS

ifdef WINDOWS_TARGET

OFLAGS += -static-libgcc

endif

ifdef LINUX_TARGET

ifndef STATIC_LIBRARY_TARGET
LIBS += \
	$(call _L,m)
endif

endif

CECFLAGS += -cpp $(_CPP)

# TARGETS

all: objdir $(TARGET)

test: $(TARGET)
	$(RUNNER) $(TARGET)

objdir:
	$(if $(wildcard $(OBJ)),,$(call mkdir,$(OBJ)))
	$(if $(ECERE_SDK_SRC),$(if $(wildcard $(call escspace,$(ECERE_SDK_SRC)/crossplatform.mk)),,@$(call echo,Ecere SDK Source Warning: The value of ECERE_SDK_SRC is pointing to an incorrect ($(ECERE_SDK_SRC)) location.)),)
	$(if $(ECERE_SDK_SRC),,$(if $(ECP_DEBUG)$(ECC_DEBUG)$(ECS_DEBUG),@$(call echo,ECC Debug Warning: Please define ECERE_SDK_SRC before using ECP_DEBUG, ECC_DEBUG or ECS_DEBUG),))

$(OBJ)$(MODULE).main.ec: $(SYMBOLS) $(COBJECTS)
	@$(call rm,$(OBJ)symbols.lst)
	@$(call touch,$(OBJ)symbols.lst)
	$(call addtolistfile,$(SYMBOLS),$(OBJ)symbols.lst)
	$(call addtolistfile,$(IMPORTS),$(OBJ)symbols.lst)
	$(ECS) -console $(ARCH_FLAGS) $(ECSLIBOPT) @$(OBJ)symbols.lst -symbols obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX) -o $(call quote_path,$@)

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
	$(if $(basename $(VER)),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(OBJ)$(LP)$(MODULE)$(SO)$(basename $(VER)),)
	$(if $(VER),ln -sf $(LP)$(MODULE)$(SO)$(VER) $(OBJ)$(LP)$(MODULE)$(SO),)
endif
endif
endif

# SYMBOL RULES

$(OBJ)testingFramework.sym: $(EC_SDK_SRC)/extras/testing/testingFramework.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,$(EC_SDK_SRC)/extras/testing/testingFramework.ec) -o $(call quote_path,$@)

$(OBJ)CartoSymParsing.sym: CartoSymParsing.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,CartoSymParsing.ec) -o $(call quote_path,$@)

$(OBJ)sldWriter.sym: ../../SLDSE/sldWriter.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../../SLDSE/sldWriter.ec) -o $(call quote_path,$@)

$(OBJ)sldParser.sym: ../../SLDSE/sldParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../../SLDSE/sldParser.ec) -o $(call quote_path,$@)

$(OBJ)XMLParser.sym: $(EC_SDK_SRC)/extras/XMLParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,$(EC_SDK_SRC)/extras/XMLParser.ec) -o $(call quote_path,$@)

$(OBJ)mbglParser.sym: ../../MapboxStyles/mbglParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../../MapboxStyles/mbglParser.ec) -o $(call quote_path,$@)

$(OBJ)gggLevels.sym: ../../MapboxStyles/gggLevels.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../../MapboxStyles/gggLevels.ec) -o $(call quote_path,$@)

$(OBJ)mbglWriter.sym: ../../MapboxStyles/mbglWriter.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../../MapboxStyles/mbglWriter.ec) -o $(call quote_path,$@)

# C OBJECT RULES

$(OBJ)testingFramework.c: $(EC_SDK_SRC)/extras/testing/testingFramework.ec $(OBJ)testingFramework.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(EC_SDK_SRC)/extras/testing/testingFramework.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)CartoSymParsing.c: CartoSymParsing.ec $(OBJ)CartoSymParsing.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,CartoSymParsing.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)sldWriter.c: ../../SLDSE/sldWriter.ec $(OBJ)sldWriter.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../../SLDSE/sldWriter.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)sldParser.c: ../../SLDSE/sldParser.ec $(OBJ)sldParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../../SLDSE/sldParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)XMLParser.c: $(EC_SDK_SRC)/extras/XMLParser.ec $(OBJ)XMLParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(EC_SDK_SRC)/extras/XMLParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)mbglParser.c: ../../MapboxStyles/mbglParser.ec $(OBJ)mbglParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../../MapboxStyles/mbglParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)gggLevels.c: ../../MapboxStyles/gggLevels.ec $(OBJ)gggLevels.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../../MapboxStyles/gggLevels.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)mbglWriter.c: ../../MapboxStyles/mbglWriter.ec $(OBJ)mbglWriter.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../../MapboxStyles/mbglWriter.ec) -o $(call quote_path,$@) -symbols $(OBJ)

# OBJECT RULES

$(OBJ)testingFramework$(O): $(OBJ)testingFramework.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)testingFramework.c) -o $(call quote_path,$@)

$(OBJ)CartoSymParsing$(O): $(OBJ)CartoSymParsing.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)CartoSymParsing.c) -o $(call quote_path,$@)

$(OBJ)sldWriter$(O): $(OBJ)sldWriter.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)sldWriter.c) -o $(call quote_path,$@)

$(OBJ)sldParser$(O): $(OBJ)sldParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)sldParser.c) -o $(call quote_path,$@)

$(OBJ)XMLParser$(O): $(OBJ)XMLParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)XMLParser.c) -o $(call quote_path,$@)

$(OBJ)mbglParser$(O): $(OBJ)mbglParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)mbglParser.c) -o $(call quote_path,$@)

$(OBJ)gggLevels$(O): $(OBJ)gggLevels.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)gggLevels.c) -o $(call quote_path,$@)

$(OBJ)mbglWriter$(O): $(OBJ)mbglWriter.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)mbglWriter.c) -o $(call quote_path,$@)

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
