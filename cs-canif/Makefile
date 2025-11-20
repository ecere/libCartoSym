ifneq ($(V),1)
.SILENT:
endif

.PHONY: all objdir cleantarget clean realclean distclean

# CORE VARIABLES

MODULE := cs-canif
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

CSCANIF_ABSPATH := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

CARTOSYM_ABSPATH := $(realpath $(dir $(CSCANIF_ABSPATH))../)

ifndef EC_SDK_SRC
EC_SDK_SRC := $(realpath $(dir $(CARTOSYM_ABSPATH)/)../eC)
endif

_CF_DIR = $(EC_SDK_SRC)/

include $(_CF_DIR)crossplatform.mk
include $(_CF_DIR)default.cf

RUNNER =

ifndef WINDOWS_HOST
ifdef OSX_HOST
export DYLD_LIBRARY_PATH := $(DYLD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)
export EC_LIB_PATH := $(CARTOSYM_ABSPATH)/$(HOST_SODESTDIR)lib
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

BINDIR := obj/$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/bin/

# POST-INCLUDES VARIABLES

OBJ = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/

RES =

TARGET_NAME := cs-canif

TARGET = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/$(TARGET_NAME)$(OUT)

_ECSOURCES = \
	commands/convertStyle.ec \
	commands/convertGeometry.ec \
	commands/convertFeatures.ec \
	commands/convertExpression.ec \
	commands/de9imRelations.ec \
	commands/evalExpression.ec \
	commands/evalStyle.ec \
	../MapboxStyles/gggLevels.ec \
	../MapboxStyles/mbglParser.ec \
	../MapboxStyles/mbglWriter.ec \
	$(EC_SDK_SRC)/extras/XMLParser.ec \
	../SLDSE/sldParser.ec \
	../SLDSE/sldWriter.ec \
	cs-canif.ec

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

OFLAGS += -L$(EC_SDK_SRC)/$(SODESTDIR)
OFLAGS += -L$(CARTOSYM_ABSPATH)/$(SODESTDIR)

LIBS += \
	$(call _L,ecrt) \
	$(call _L,CartoSym) \
	$(call _L,CQL2) \
	$(call _L,DE9IM) \
	$(call _L,SFCollections) \
	$(call _L,SFGeometry) \
	$(call _L,GeoExtents)

ifdef OSX_TARGET
OFLAGS += $(if $(ENABLE_PYTHON_RPATHS),-Wl$(comma)-rpath$(comma)'@executable_path/../lib' -Wl$(comma)-rpath$(comma)'@executable_path/../../ecrt/lib' -Wl$(comma)-rpath$(comma)'@executable_path/../../cscql2/lib',)
else
OFLAGS += $(if $(ENABLE_PYTHON_RPATHS),-Wl$(comma)-rpath='$$ORIGIN/../lib:$$ORIGIN/../../ecrt/lib:$$ORIGIN/../../cscql2/lib',)
endif

PRJ_CFLAGS += \
	 $(if $(DEBUG), -g, -O2 -ffast-math) $(FPIC) -Wall -DREPOSITORY_VERSION="\"$(REPOSITORY_VER)\"" \
			 -DIMPORT_STATIC=\"\"

ECFLAGS += -module $(MODULE)

# PLATFORM-SPECIFIC OPTIONS

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
	$(LD) $(OFLAGS) @$(OBJ)objects.lst $(LIBS) -o $(TARGET) $(INSTALLNAME) $(SONAME)
ifndef NOSTRIP
	$(STRIP) $(STRIPOPT) $(TARGET)
endif
	$(call mkdir,$(CARTOSYM_ABSPATH)/$(BINDIR))
	$(call cp,$(TARGET),$(CARTOSYM_ABSPATH)/$(BINDIR))
			
# SYMBOL RULES

$(OBJ)convertStyle.sym: commands/convertStyle.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/convertStyle.ec) -o $(call quote_path,$@)

$(OBJ)convertGeometry.sym: commands/convertGeometry.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/convertGeometry.ec) -o $(call quote_path,$@)

$(OBJ)convertFeatures.sym: commands/convertFeatures.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/convertFeatures.ec) -o $(call quote_path,$@)

$(OBJ)convertExpression.sym: commands/convertExpression.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/convertExpression.ec) -o $(call quote_path,$@)

$(OBJ)de9imRelations.sym: commands/de9imRelations.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/de9imRelations.ec) -o $(call quote_path,$@)

$(OBJ)evalExpression.sym: commands/evalExpression.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/evalExpression.ec) -o $(call quote_path,$@)

$(OBJ)evalStyle.sym: commands/evalStyle.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,commands/evalStyle.ec) -o $(call quote_path,$@)

$(OBJ)gggLevels.sym: ../MapboxStyles/gggLevels.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../MapboxStyles/gggLevels.ec) -o $(call quote_path,$@)

$(OBJ)mbglParser.sym: ../MapboxStyles/mbglParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../MapboxStyles/mbglParser.ec) -o $(call quote_path,$@)

$(OBJ)mbglWriter.sym: ../MapboxStyles/mbglWriter.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../MapboxStyles/mbglWriter.ec) -o $(call quote_path,$@)

$(OBJ)XMLParser.sym: $(EC_SDK_SRC)/extras/XMLParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,$(EC_SDK_SRC)/extras/XMLParser.ec) -o $(call quote_path,$@)

$(OBJ)sldParser.sym: ../SLDSE/sldParser.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../SLDSE/sldParser.ec) -o $(call quote_path,$@)

$(OBJ)sldWriter.sym: ../SLDSE/sldWriter.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,../SLDSE/sldWriter.ec) -o $(call quote_path,$@)

$(OBJ)cs-canif.sym: cs-canif.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,cs-canif.ec) -o $(call quote_path,$@)

# C OBJECT RULES

$(OBJ)convertStyle.c: commands/convertStyle.ec $(OBJ)convertStyle.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/convertStyle.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)convertGeometry.c: commands/convertGeometry.ec $(OBJ)convertGeometry.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/convertGeometry.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)convertFeatures.c: commands/convertFeatures.ec $(OBJ)convertFeatures.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/convertFeatures.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)convertExpression.c: commands/convertExpression.ec $(OBJ)convertExpression.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/convertExpression.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)de9imRelations.c: commands/de9imRelations.ec $(OBJ)de9imRelations.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/de9imRelations.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)evalExpression.c: commands/evalExpression.ec $(OBJ)evalExpression.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/evalExpression.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)evalStyle.c: commands/evalStyle.ec $(OBJ)evalStyle.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,commands/evalStyle.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)gggLevels.c: ../MapboxStyles/gggLevels.ec $(OBJ)gggLevels.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../MapboxStyles/gggLevels.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)mbglParser.c: ../MapboxStyles/mbglParser.ec $(OBJ)mbglParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../MapboxStyles/mbglParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)mbglWriter.c: ../MapboxStyles/mbglWriter.ec $(OBJ)mbglWriter.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../MapboxStyles/mbglWriter.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)XMLParser.c: $(EC_SDK_SRC)/extras/XMLParser.ec $(OBJ)XMLParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(EC_SDK_SRC)/extras/XMLParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)sldParser.c: ../SLDSE/sldParser.ec $(OBJ)sldParser.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../SLDSE/sldParser.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)sldWriter.c: ../SLDSE/sldWriter.ec $(OBJ)sldWriter.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,../SLDSE/sldWriter.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)cs-canif.c: cs-canif.ec $(OBJ)cs-canif.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,cs-canif.ec) -o $(call quote_path,$@) -symbols $(OBJ)

# OBJECT RULES

$(OBJ)convertStyle$(O): $(OBJ)convertStyle.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)convertStyle.c) -o $(call quote_path,$@)

$(OBJ)convertGeometry$(O): $(OBJ)convertGeometry.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)convertGeometry.c) -o $(call quote_path,$@)

$(OBJ)convertFeatures$(O): $(OBJ)convertFeatures.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)convertFeatures.c) -o $(call quote_path,$@)

$(OBJ)convertExpression$(O): $(OBJ)convertExpression.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)convertExpression.c) -o $(call quote_path,$@)

$(OBJ)de9imRelations$(O): $(OBJ)de9imRelations.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)de9imRelations.c) -o $(call quote_path,$@)

$(OBJ)evalExpression$(O): $(OBJ)evalExpression.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)evalExpression.c) -o $(call quote_path,$@)

$(OBJ)evalStyle$(O): $(OBJ)evalStyle.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)evalStyle.c) -o $(call quote_path,$@)

$(OBJ)gggLevels$(O): $(OBJ)gggLevels.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)gggLevels.c) -o $(call quote_path,$@)

$(OBJ)mbglParser$(O): $(OBJ)mbglParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)mbglParser.c) -o $(call quote_path,$@)

$(OBJ)mbglWriter$(O): $(OBJ)mbglWriter.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)mbglWriter.c) -o $(call quote_path,$@)

$(OBJ)XMLParser$(O): $(OBJ)XMLParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)XMLParser.c) -o $(call quote_path,$@)

$(OBJ)sldParser$(O): $(OBJ)sldParser.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)sldParser.c) -o $(call quote_path,$@)

$(OBJ)sldWriter$(O): $(OBJ)sldWriter.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)sldWriter.c) -o $(call quote_path,$@)

$(OBJ)cs-canif$(O): $(OBJ)cs-canif.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)cs-canif.c) -o $(call quote_path,$@)

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
