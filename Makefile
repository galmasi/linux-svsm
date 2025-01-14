# SPDX-License-Identifier: MIT

GCC		= gcc

SHELL		:= /bin/bash

A_FLAGS		:= -D__ASSEMBLY__

C_FLAGS		:= -g -O2
C_FLAGS		+= -m64 -march=x86-64 -mno-sse2
C_FLAGS		+= -fno-stack-protector
C_FLAGS		+= -ffreestanding
C_FLAGS		+= -Wall -Wstrict-prototypes -Wno-address-of-packed-member

LD_FLAGS	:= -m64
LD_FLAGS	+= -nostdlib
LD_FLAGS	+= -Wl,-Tsrc/start/svsm.lds -Wl,--build-id=none

TARGET_JSON	:= x86_64-unknown-none
TARGET_DIR	:= target
TARGET		:= $(TARGET_DIR)/$(TARGET_JSON)/debug

OBJS		:= src/start/start.o
OBJS		+= $(TARGET)/liblinux_svsm.a

FEATURES	:= ""

## Memory layout

SVSM_GPA	:= 0x8000000000
SVSM_MEM	:= 0x10000000
LDS_FLAGS	:= -DSVSM_GPA_LDS="$(SVSM_GPA)"
LDS_FLAGS	+= -DSVSM_GPA="$(SVSM_GPA)ULL"
LDS_FLAGS	+= -DSVSM_MEM="$(SVSM_MEM)ULL"

.PHONY: all doc prereq clean superclean

STATIC_LIBS	+= ./external/build/lib/libtpm.a
STATIC_LIBS	+= ./external/build/lib/libplatform.a
STATIC_LIBS	+= ./external/build/lib/libwolfssl.a
STATIC_LIBS	+= ./external/build/lib/libcrt.a
STATIC_LIBS	+= ./external/build/lib/libm.a

all: .prereq svsm.bin

doc: .prereq
	cargo doc --open

svsm.bin: svsm.bin.elf
	objcopy -g -O binary $< $@

svsm.bin.elf: $(OBJS) src/start/svsm.lds
	@xargo build --features $(FEATURES)
	$(GCC) $(LD_FLAGS) -o $@ $(OBJS) -Wl,--start-group $(STATIC_LIBS) -Wl,--end-group

%.a: src/*.rs src/cpu/*.rs src/mem/*.rs src/util/*.rs src/vtpm/*.rs
	@xargo build --features $(FEATURES)

%.o: %.S src/start/svsm.h
	$(GCC) $(C_FLAGS) $(LDS_FLAGS) $(A_FLAGS) -c -o $@ $<

%.lds: %.lds.S src/start/svsm.h
	$(GCC) $(A_FLAGS) $(LDS_FLAGS) -E -P -o $@ $<

prereq: .prereq

.prereq:
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	source $(HOME)/.cargo/env
	echo "source $(HOME)/.cargo/env" >> ~/.bashrc
	rustup +nightly target add x86_64-unknown-none
	rustup component add rust-src
	rustup component add llvm-tools-preview
	rustup override set nightly
	cargo install xargo
	cargo install bootimage
	touch .prereq

clean:
	@xargo clean 
	rm -f svsm.bin svsm.bin.elf $(OBJS) $(STATIC_LIBS)
	rm -rf $(TARGET_DIR)
	rm -f src/start/svsm.lds

superclean: clean
	rm -f .prereq
