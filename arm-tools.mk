arm_tools_mkfile_path:=$(abspath $(lastword $(MAKEFILE_LIST)))
arm_tools_current_path := $(patsubst %/,%,$(dir $(arm_tools_mkfile_path)))

include $(arm_tools_current_path)/mc/makecommon.mk

arm_tools_current_path_windows_slashes:=$(subst /,\,$(arm_tools_current_path))

# Required System Environment Variables
export PATH:=$(arm_tools_current_path)/arm-gnu-toolchain/bin;$(PATH)

# Commonly Used Variables
export ASSEMBLER:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-as
export COMPILER:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-gcc
export LINKER:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-gcc
export ARCHIVER:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-ar
export OBJCOPY:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-objcopy
export SIZE:=$(arm_tools_current_path)/arm-gnu-toolchain/bin/arm-none-eabi-size

ZIP_TOOL:=$(arm_tools_current_path)\zip\7zip.exe
LUA_SREC_TO_IHEX:=$(arm_tools_current_path)/lstih/lua-srec-to-intel-hex.lua

# Now set up the include directories
INCLUDE += $(foreach dir,$(SRC_DIRS),-I$(dir))
INCLUDE += $(foreach dir,$(LIB_DIRS),-I$(dir))
INCLUDE += $(foreach dir,$(INC_DIRS),-I$(dir))

ASOPTS += -mcpu=$(CPU_CORE) -mthumb -g
CCOPTS += -x c
CCOPTS += -funsigned-char -funsigned-bitfields
CCOPTS += -mthumb
CCOPTS += -D$(MICRO_INC) -DDONT_USE_CMSIS_INIT
CCOPTS += $(addprefix -D,$(GIT_HASH_DEFINES_RX))

CCENDOPTS += $(OPTIMIZE)
CCENDOPTS += -ffunction-sections -fdata-sections
CCENDOPTS += -mno-long-calls
CCENDOPTS += -g3 -Wall -c -std=gnu99
CCENDOPTS += -mcpu=$(CPU_CORE)

LINKOPTS  = -mthumb
LINKOPTS += -Wl,--start-group $(MICRO_LIB) -Wl,--end-group -L"src"
LINKOPTS += -Wl,--gc-sections -mcpu=cortex-m0plus
LINKOPTS += -Wl,--script=$(MICRO_LD)
LINKOPTS += -Wl,-Map=$(OUTPUT_DIR)/$(TARGET).map

empty=
space=$(empty) $(empty)

# Takes the list of files and creates a zip, and moves them to the articats folder
# $1 Space delimited list of files to zip
# $2 Name of zip file to be created without the extension
define bundle_artifacts
	@echo Bundling Artifacts $(NEWLINE) \
	@$(call zip_files,$1,$2.zip, artifacts)
	@echo Bundling Complete
endef

# Creates a .srec from a .elf file
# $1 Input <directory>/<name>.elf
# $2 Output <directory>/<name>.srec
define create_srec_from_elf
	@echo Invoking: S-Record generation $(NEWLINE) \
	@$(OBJCOPY) -O srec -R .eeprom -R .fuse -R .lock -R .signature $1 $2 $(NEWLINE) \
	@echo -Finished S-Record generation
endef

# Links
# $1 Target Name
# $2 The output directory
# $3 The libraries to include in a list that is space seperated
# $4 Any arguments for the linker. If including a file that has them place `-subcommand` in front.
#    Example: -subcommand=target.linkcmd
# $5 .objs to be linked
define linker_arm
	@echo Invoking Linker for $1 $(NEWLINE) \
	$(file >$2/link$1cmds.txt,) $(NEWLINE) \
	@echo Expanding object files into $2/link$1cmds.txt $(NEWLINE) \
	$(foreach objfile,$5,$(file >>$2/link$1cmds.txt,input=$(objfile)$(NEWLINE))) $(NEWLINE) \
	@$(LINKER) $4 -subcommand=$(OUTPUT_DIR)/link$1cmds.txt $(addprefix -library=,$3) -list=$2/$1.map -output=$2/$1.abs $(NEWLINE) \
	@echo -Finished Linking $1
endef

# Creates a library
# $1 The library name
# $2 The Output Directory
# $3 The .objs to go into the lib
define create_library_arm
	$(file >$2/link$1cmds.txt,)  \
	$(foreach objfile,$4,$(file >>$2/link$1cmds.txt,$(objfile))) \
	@echo Invoking Linker for $1 library $(NEWLINE) \
	$(ARCHIVER) -r -o $(LIBS) $(space) @$2/link$1cmds.txt $(NEWLINE) \
	@echo Finished building $1 library
endef

# Compiles .c files into .o files
# $1 The variables to include
# $2 warnings to ignore
# $3 Optimize options
define compile_c_files_arm
	@echo compiling $(notdir $<) $(NEWLINE) \
	-@if NOT EXIST $(dir $@) mkdir $(subst /,\,$(dir $@)) $(NEWLINE) \
	@$(COMPILER) -MD -MP -MF "$(@:%.obj=%.d)" -MT "$(@)" -E -quiet "$<" @$(OUTPUT_DIR)/scandep_includes $(addprefix -D,$1) $(NEWLINE) \
	@$(foreach num,1 2 3 4 5,$(CC) -subcommand=$(OUTPUT_DIR)/compiler_includes -include=$(INC_RX) $(addprefix -define=,$1) -lang=c99 -change_message=error -change_message=information=$2 $3 -auto_enum -nologo -debug $< -output=obj=$(@:%.d=%.obj) || ping 127.0.0.1 -n 2 > nul &&) exit 1
endef

# $1 Directory and file name combined
# $2 What directories to include
# $3 What prefix to use
define create_include_file
	$(file >$1,) $(NEWLINE) \
	$(foreach directory,$2,$(file >>$1,$3$(directory)$(NEWLINE)))
endef
