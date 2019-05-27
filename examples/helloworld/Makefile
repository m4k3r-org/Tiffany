hello: flash.c main.c vm.c vmConsole.c vmUser.c
	gcc -std=c99 -o hello $^ 

vm.c: main.f
	(echo bye | ../../bin/tiff -r 0x100 -f main.f) || true

.PHONY: clean
clean:
	rm -f hello
