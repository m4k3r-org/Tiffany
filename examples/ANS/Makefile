FORTH_DIR ?= ../../forth
FORTH_SRCS := $(shell find $(FORTH_DIR) -name "*.f")

ans: flash.c main.c vm.c vmConsole.c vmUser.c
	gcc -std=c99 -o ans $^

vm.c: main.f $(FORTH_SRCS)
	(echo bye | ../../bin/tiff -s 128 -h 0x4000 -f main.f) || true

.PHONY: clean
clean: 
	rm -f ans
