SOURCE=src
TARGET=tero_puf_driver
OUTPUT=build
BUILDSYSTEM_DIR:=/lib/modules/$(shell uname -r)/build

SOURCES=$(wildcard $(SOURCE)/*.c)
HEADERS=$(wildcard $(SOURCE)/*.h)

prepare:
	mkdir -p $(OUTPUT)

# Depends on bin/include bin/*.c and bin/Makefile
all: prepare $(subst $(SOURCE),$(OUTPUT),$(HEADERS)) $(subst $(SOURCE),$(OUTPUT),$(SOURCES)) $(OUTPUT)/Makefile
	$(MAKE) -C $(BUILDSYSTEM_DIR) M=$(PWD)/$(OUTPUT) modules

# Create a symlink from src to bin
$(OUTPUT)/%: $(HEADER)/%
	ln -s ../$< $@

$(OUTPUT)/%: $(SOURCE)/%
	ln -s ../$< $@

# Generate a Makefile with the needed obj-m and mymodule-objs set
$(OUTPUT)/Makefile:
	echo "obj-m += $(TARGET).o\n$(TARGET)-objs := $(subst $(TARGET).o,, $(subst .c,.o,$(subst $(SOURCE)/,,$(SOURCES))))" > $@

clean:
	$(MAKE) -C $(BUILDSYSTEM_DIR) M=$(PWD)/$(OUTPUT) clean
	rm -rf $(OUTPUT)
	
load:
	insmod $(PWD)/$(OUTPUT)/$(TARGET).ko

unload:
	rmmod $(PWD)/$(OUTPUT)/$(TARGET).ko