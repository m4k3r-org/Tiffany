testbench: flash.c main.c vm.c vmConsole.c vmUser.c
	gcc -std=c99 -o bench $^ 

vm.c: main.f
	(echo bye | ../../bin/tiff -f main.f) || true

.PHONY: clean
clean:
	rm -f testbench 
