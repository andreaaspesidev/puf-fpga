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
	
generate-key:
	openssl req -config $(PWD)/config/openssl_key.cnf \
        -new -x509 -newkey rsa:2048 \
        -nodes -days 36500 -outform DER \
        -keyout "$(PWD)/MOK.priv" \
        -out "$(PWD)/MOK.der"

install-key:
	sudo mokutil --import $(PWD)/MOK.der
	echo "Reboot the system before proceding"

sign:
	kmodsign sha512 $(PWD)/MOK.priv $(PWD)/MOK.der $(PWD)/$(OUTPUT)/$(TARGET).ko

load:
	sudo insmod $(PWD)/$(OUTPUT)/$(TARGET).ko

unload:
	sudo rmmod $(PWD)/$(OUTPUT)/$(TARGET).ko