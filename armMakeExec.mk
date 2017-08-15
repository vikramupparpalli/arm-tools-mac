###############################################################################
# Makefile execution
###############################################################################

all: $(OUTPUT_FOLDER)/$(BULD_TARGET).bin \
     $(OUTPUT_FOLDER)/$(BULD_TARGET).srec \
     $(OUTPUT_FOLDER)/$(BULD_TARGET).hex \
     size

clean:
	@echo "Removing Binaries . . ."
	@rm -f $(OUTPUT_FOLDER)/$(BULD_TARGET).bin
	@rm -f $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@rm -f $(OUTPUT_FOLDER)/$(BULD_TARGET).srec
	@echo "Removing Map file . . ."
	@rm -f $(OUTPUT_FOLDER)/$(BULD_TARGET).map
	@echo "Removing Object files . . ."
	@rm -f $(PROJECT_OBJECTS)

$(OUTPUT_FOLDER)/%.o: %.s
	@if [ ! -d "$(dir $@)" ]; then $(MKDIR_P) $(dir $@); fi
	@echo "Compiling: $<"
	@$(AS) $(MCU_CC_FLAGS) -o $@ $<

$(OUTPUT_FOLDER)/%.o: %.c
	@if [ ! -d "$(dir $@)" ]; then $(MKDIR_P) $(dir $@); fi
	@echo "Compiling: $<"
	@$(CC)  $(CC_FLAGS) $(CC_SYMBOLS) -std=gnu99   $(INCLUDE_PATHS) -o $@ $<

$(OUTPUT_FOLDER)/$(BULD_TARGET).elf: $(PROJECT_OBJECTS)
	@echo Linking Started. . .
	@mkdir -p $(OUTPUT_FOLDER)
	@$(LD) $(LD_FLAGS) -T$(LINKER_SCRIPT) -o $@ $^
	@echo Linking Done !

$(OUTPUT_FOLDER)/$(BULD_TARGET).bin: $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@echo Bin File Generation . . .
	@$(OBJCOPY) -O binary $< $@
	@echo

$(OUTPUT_FOLDER)/$(BULD_TARGET).hex: $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@$(OBJCOPY) -O ihex $< $@

$(OUTPUT_FOLDER)/$(BULD_TARGET).srec: $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@echo S-Record Generation . . .
	@$(OBJCOPY) -O srec -R .eeprom -R .fuse -R .lock -R .signature $^ $@
	@echo

size: $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@echo Size :
	@$(SIZE) -t $(OUTPUT_FOLDER)/$(BULD_TARGET).elf
	@echo
