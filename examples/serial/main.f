﻿\ Serial Port example

defer coldboot
defer safemode
defer errorISR

1 equ options                           \ use HW mul/div
include ../../forth/core.f
: pause ;  \ include ../../forth/tasker.f \ no multitasker
include ../../forth/timing.f
include ../../forth/numio.f             \ numeric I/O

	: throw  \ n --  				    \ for testing, remove later
	?dup if  port drop  			    \ save n in dbg register, like error interrupt
		8 >r						    \ fake an error interrupt
	then
	; call-only

	\ The error ISR has the last known good PC on the return stack and the ior in port.
	\ Usually, you would just throw an error.
	\ Since the Mforth interpreter is being used, use a test THROW.

	:noname
	cr ." Error " dup port . ." at PC=" r> .
	." Line# " w_linenum w@ .	cr
	-1 @  								\ produce an error to quit
	; is errorISR

include ../../forth/comma.f             \ smart comma

: hi
	." Hello World!" cr
	10 0 do i . loop cr
;

\ Serial port uses host functions (see vmHost.c)

: open  ( port baud -- ior )  0 host ;  \ format is N,8,2 with no flow control
: close  ( -- )       1 host ;
: cemit  ( c -- )     2 host ;
: ckey?  ( -- flag )  3 host ;
: ckey   ( c -- )     4 host ;
: testout   ( addr len -- )  5 host ;

1 constant R/O  \ 11.6.1.2054 ( -- fam )
2 constant W/O  \ 11.6.1.2425 ( -- fam )
3 constant R/W  \ 11.6.1.2056 ( -- fam )

: CLOSE-FILE  ( fileid -- ior )  6 host ;
: CREATE-FILE ( c-addr u fam -- fileid ior )  7 host ;
: OPEN-FILE   ( c-addr u fam -- fileid ior )  8 host ;
: READ-FILE   ( c-addr u1 fileid -- u2 ior )  9 host ;
: READ-LINE   ( c-addr u1 fileid -- u2 flag ior )  10 host ;
: FILE-POSITION   ( fileid -- ud ior )  11 host ;
: REPOSITION-FILE ( ud fileid -- ior )  12 host ;
: WRITE-FILE      ( c-addr u fileid -- ior )  13 host ;
: WRITE-LINE      ( c-addr u fileid -- ior )  14 host ;
: FILE-SIZE       ( fileid -- ud ior )  15 host ;

: filename  s" test.txt" ;
variable inf
variable outf
: seefile  ( a u -- )
   r/o open-file throw  inf !
   s" created.txt" w/o create-file throw  outf !
   inf @ FILE-SIZE throw
   ." reading " d. ." bytes:" cr
   BEGIN
      pad |pad| inf @ READ-LINE THROW     	( length not-eof-flag )
   WHILE                        ( length )
      s" copy: " outf @ write-file throw
      pad over   outf @ write-line throw
      pad swap type cr
   REPEAT DROP
   outf @ close-file throw
   inf @ close-file throw
;

variable port  7 port !
variable connected
115200 constant baudrate

hex
: ping  \ -- char
   [char] / cemit ckey
;
: connect  \ --
   connected @ if
      ." Already connected. Disconnect first."
      exit
   then
   baudrate port @ open throw
   10 cemit  0F cemit  12 cemit         \ take control of flash
   1 connected !
   begin ping [char] < = until          \ wait until controller is ready
;
: disconnect  \ --
   connected @ 0= if
      ." Already disconnected. Connect first."
      exit
   then
   1B cemit  close throw
   0 connected !
;
: SPIxfer  ( in -- out )                \ same behavior as in the VM but over UART
   03FF and
   dup 5 rshift 40 + cemit              \ first 5-bit digit
   01F and 60 + cemit                   \ last 5-bit digit
   ckey  0F and  2* 2* 2* 2*            \ returned digits = byte
   ckey  0F and +
;
decimal

\ At this point I realized I need file access words.
\ These would have to be added to vmUser.c.
\ So, I'll just use a different SDK for the flash programming application.

\ theme=color  \ looks better in color, if your terminal isn't dumb.
