################################################################################
#
# Include this makefile at the end of your makefile to build using Atmel tools
#
# makefile written for GNU make version 3.82 or later
#
################################################################################
#
# Inputs to this are as follows:
#
# TARGET         - Define the target we want to build
# SRC_FILES      - Specific files to include if you don't want the entire directory including
# SRC_DIRS       - Directories to include ALL the source files
# INC_DIRS       - Define additional include directories
# OUTPUT_DIR     - Set up the directory below which machine generated files live
# CCOPTS         - Command line options for compiler
# LINKOPTS       - Command line options for linker
################################################################################

arm_makefile_worker_mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
arm_makefile_worker_current_path := $(patsubst %/,%,$(dir $(arm_makefile_worker_mkfile_path)))

# Helper Functions - these build on gmake's built in functions wildcard, foreach subst and addprefix
SOURCE_EXTENSIONS:=.s .src .cpp .c

include $(arm_makefile_worker_current_path)/arm-tools.mk
include $(arm_makefile_worker_current_path)/mc/targetcommon.mk

# Main-build Target
.PHONY: target
target: $(OUTPUT_DIR)/$(TARGET).elf size $(OUTPUT_DIR)/$(TARGET).srec $(OUTPUT_DIR)/$(TARGET).apl $(OUTPUT_DIR)/$(TARGET).hex
	@echo Build complete.

# Intermediate build targets
$(OUTPUT_DIR)/$(TARGET).elf: $(OBJ) $(LIBS)
	@echo Linking
	@$(LINKER) -o $@ $(OBJ) $(LIBS) $(LINKOPTS)
	@echo.

size: $(OUTPUT_DIR)/$(TARGET).elf
	@echo Size:
	@$(SIZE) -t $^
	@echo.

$(OUTPUT_DIR)/$(TARGET).srec: $(OUTPUT_DIR)/$(TARGET).elf
	@echo S-Record generation
	@$(OBJCOPY) -O srec -R .eeprom -R .fuse -R .lock -R .signature $^ $@
	@echo.

$(OUTPUT_DIR)/$(TARGET).apl: $(OUTPUT_DIR)/$(TARGET).srec
	@echo APL Generation
	@$(LUA53) $(LUA_MOT_TO_APL) --endianness little --header_address $(ROM_START_ADDRESS) --srec $(OUTPUT_DIR)/$(TARGET).srec --output $(OUTPUT_DIR)/$(TARGET).apl
	@echo.

$(OUTPUT_DIR)/$(TARGET).hex: $(OUTPUT_DIR)/$(TARGET).apl
	@echo Calculating Image CRC:
	@$(LUA53) $(LUA_SREC_TO_IHEX) --input $(OUTPUT_DIR)/$(TARGET).apl --output $(OUTPUT_DIR)/$(TARGET).hex
	@echo.

$(OUTPUT_DIR):
	@echo Creating target directory
	@$(call make_directory,$(OUTPUT_DIR))
	
artifacts:
	@mkdir artifacts

$(LIBS): $(COMMON_LIB_OBJ)
	@echo Building library
	@$(call create_library_arm,$(PROJECT),$(OUTPUT_DIR), $(LIBS), $(COMMON_LIB_OBJ))
	@echo Finished building library

# Other Targets
.PHONY: clean
target_clean:
	@rm -rf $(OUTPUT_DIR)
	@echo Clean complete.

# This is the rule that turns a .c file into a .o - Note that it creates the output directory if it doesn't exist and
# makes the dependency file (a mini makefile with a .d extension)
$(OUTPUT_DIR)/%.o: %.c
	@echo compiling $(notdir $<)
	-@if NOT EXIST $(dir $@) mkdir $(subst /,\,$(dir $@))
	@$(COMPILER) $(CCOPTS) $(addprefix -D,$(DEFINE_LIST)) $(addprefix -I,$(C_FILE_LOCATIONS)) $(CCENDOPTS) -MD -MP -MF "$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -MT"$(@:%.o=%.o)" -o"$@" "$<"

# This is the rule that turns a .c file into a .o - Note that it creates the output directory if it doesn't exist and
# makes the dependency file (a mini makefile with a .d extension)
$(OUTPUT_DIR)/%.o: %.s
	@echo compiling $(notdir $<)
	-@if NOT EXIST $(dir $@) mkdir $(subst /,\,$(dir $@))
	@$(ASSEMBLER) $(ASOPTS) $*.s -o $@

# This brings in the .d dependency files that expand out to show header dependencies
-include $(DEPS)
