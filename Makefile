#!/bin/make

#######################################################
#                                                     #
#  Makefile for i.MX HAB authenticated (signed) boot  #
#                                                     #
#######################################################

# required: bc, objcopy (any arch), sed, cst

# Usage:
#
# Copy u-boot.imx to this directory
#
# $ make
#
# Place u-boot-signed.imx on the boot medium 
#


# Configuration
RSA_LENGTH?=4096
LOAD_ADDR?=0x87800000
#

MACHINE_BITS != getconf LONG_BIT
CST=../linux$(MACHINE_BITS)/cst

# keyfile dependency - remember to update also u-boot-sign.csf.in when changing filenames
KEYS=../crts/SRK_1_2_3_4_table.bin ../crts/CSF1_1_sha256_$(RSA_LENGTH)_65537_v3_usr_crt.pem ../crts/IMG1_1_sha256_$(RSA_LENGTH)_65537_v3_usr_crt.pem

# u-boot.imx size (hex)
UBOOT_SIZE != echo 0x`stat -c "obase=16; %s" u-boot.imx | bc`

# ivt address in DRAM (hex)
IVT_ADDR != echo 0x`echo "obase=16;ibase=16; $(LOAD_ADDR) - 0xC00" | sed -e "s/0x//g" | bc`

.PHONY: all
all: u-boot-signed.imx

u-boot-sign.csf: u-boot-sign.csf.in u-boot.imx
	cat u-boot-sign.csf.in | sed \
		-e "s/%%RSA_LENGTH%%/$(RSA_LENGTH)/" \
		-e "s/%%IVT_ADDR%%/$(IVT_ADDR)/" \
		-e "s/%%UBOOT_SIZE%%/$(UBOOT_SIZE)/" \
		> u-boot-sign.csf

u-boot-hab.bin: u-boot-sign.csf u-boot.imx $(KEYS)
	$(CST) -i u-boot-sign.csf -o u-boot-hab.bin

u-boot-hab_padded.bin: u-boot-hab.bin
	$(OBJCOPY) objcopy -I binary -O binary --pad-to 0x2000 --gap-fill 0xff u-boot-hab.bin u-boot-hab_padded.bin

u-boot-signed.imx: u-boot.imx u-boot-hab_padded.bin
	cat u-boot.imx u-boot-hab_padded.bin > u-boot-signed.imx

.PHONY: clean
clean:
	rm -rf u-boot-sign.csf u-boot-hab.bin u-boot-hab_padded.bin u-boot-signed.imx

