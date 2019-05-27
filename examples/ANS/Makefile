ans: flash.c main.c vm.c vmConsole.c vmUser.c
	gcc -std=c99 -o ans $^

vm.c: main.f
	(echo bye | ../../bin/tiff -s 128 -h 0x4000 -f main.f) || true

.PHONY: clean
clean: 
	rm -f ans
