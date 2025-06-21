ifneq ($(V),1)
.SILENT:
endif

.PHONY: all objdir cleantarget clean realclean distclean

# CORE VARIABLES

MODULE := SFGeometry
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

SFGEOMETRY_ABSPATH := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
CARTOSYM_ABSPATH := $(SFGEOMETRY_ABSPATH)../

ifndef EC_SDK_SRC
EC_SDK_SRC := $(CARTOSYM_ABSPATH)../eC
endif

_CF_DIR = $(EC_SDK_SRC)/

include $(_CF_DIR)crossplatform.mk
include $(_CF_DIR)default.cf

ifndef WINDOWS_HOST
ifdef OSX_HOST
export DYLD_LIBRARY_PATH := $(DYLD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(SODESTDIR)
else
export LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(CARTOSYM_ABSPATH)/$(SODESTDIR)
endif
else
export PATH := $(PATH);$(CARTOSYM_ABSPATH)/$(SODESTDIR)
endif

# POST-INCLUDES VARIABLES

OBJ = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/

RES =

TARGET_NAME := SFGeometry

TARGET = obj/$(CONFIG).$(PLATFORM)$(COMPILER_SUFFIX)$(DEBUG_SUFFIX)/$(LP)$(TARGET_NAME)$(OUT)

_ECSOURCES = \
	Geometry.ec \
	WKT.ec \
	WKB.ec

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

$(OBJ)Geometry.sym: Geometry.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,Geometry.ec) -o $(call quote_path,$@)

$(OBJ)WKT.sym: WKT.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,WKT.ec) -o $(call quote_path,$@)

$(OBJ)WKB.sym: WKB.ec
	$(ECP) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) -c $(call quote_path,WKB.ec) -o $(call quote_path,$@)

# C OBJECT RULES

$(OBJ)Geometry.c: Geometry.ec $(OBJ)Geometry.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,Geometry.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)WKT.c: WKT.ec $(OBJ)WKT.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,WKT.ec) -o $(call quote_path,$@) -symbols $(OBJ)

$(OBJ)WKB.c: WKB.ec $(OBJ)WKB.sym | $(SYMBOLS)
	$(ECC) $(CFLAGS) $(CECFLAGS) $(ECFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,WKB.ec) -o $(call quote_path,$@) -symbols $(OBJ)

# OBJECT RULES

$(OBJ)Geometry$(O): $(OBJ)Geometry.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)Geometry.c) -o $(call quote_path,$@)

$(OBJ)WKT$(O): $(OBJ)WKT.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)WKT.c) -o $(call quote_path,$@)

$(OBJ)WKB$(O): $(OBJ)WKB.c
	$(CC) $(CFLAGS) $(PRJ_CFLAGS) $(FVISIBILITY) -c $(call quote_path,$(OBJ)WKB.c) -o $(call quote_path,$@)

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
