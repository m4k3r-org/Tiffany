\ Mforth compiler

\ Equates for terminal variables puts copies in header space. See tiff.c/tiff.h.
\ Some are omitted to save header space.

handler         equ handler
base            equ base                \ 6.1.0750
hp              equ hp
cp              equ cp
dp              equ dp
state           equ state               \ 6.1.2250
current         equ current
source-id       equ source-id           \ 6.2.2218
personality     equ personality
tibs            equ tibs
tibb            equ tibb
>in             equ >in                 \ 6.1.0560
c_wids          equ c_wids
c_casesens      equ c_casesens
\ head            equ head
context         equ context
forth-wordlist  equ forth-wordlist      \ 16.6.1.1595
hld             equ hld
blk             equ blk
tib             equ tib
\ maxtibsize    equ maxtibsize
|pad|           equ |pad|
pad             equ pad                 \ 6.2.2000
RAMsize         equ RAMsize
ROMsize         equ ROMsize
SPIflashBlocks  equ SPIflashBlocks

\ Define a compiler
\ char params:  c_colondef c_litpend c_slot c_called

defer FlushLit
defer NewGroup

: ClearIR   \ --                        \ Initialize the IR. slot=26, litpend=0
   0 iracc !  26 c_slot w!  0 c_called c!
;
: AppendIR  \ opcode imm --             \ insert opcode at slot, adding imm
   swap  c_slot c@ lshift  iracc @      \ shift it and get IR
   +  +                    iracc !      \ merge into instruction
;

: Implicit  \ opcode --                 \ add implicit opcode to group
   FlushLit
   c_slot c@ 0=  over 60 and  and if    \ doesn't fit in the last slot
      NewGroup
   then
   0 AppendIR
   c_slot c@  dup if
      6 -  dup 0< invert and            \ sequence: 26, 20, 14, 8, 2, 0
      c_slot c! exit
   then
   drop NewGroup                        \ slot 0 -> slot 26
;

: Explicit  \ imm opcode --
   swap FlushLit
   1  c_slot c@  dup >r  lshift         \ opcode imm maximum | slot
   over <  r> 0= or                     \ imm doesn't fit of slot=0
   if  NewGroup  then
   AppendIR
   c_slot c@  24 lshift
   cp @ +  calladdr !                   \ remember call address in case of ;
   0 c_slot c!  NewGroup
;

hex
: HardLit  \ n --                       \ compile a hard literal
   dup >r -if: negate |                 \ |n| | n
   1FFFFFF invert 2* over and  if       \ compile unsigned long
      drop r>  dup 18 rshift  op_lit Explicit   \ upper part
      FFFFFF and  op_litx Explicit      \ lower part
      exit
   then
   r> 0< if                             \ compile negative
      1- op_lit Explicit
      op_com Implicit  exit
   then
   op_lit Explicit                      \ compile positive
;

:noname \ FlushLit  \ --                \ compile a literal if it's pending
   c_litpend c@ if
      0 c_litpend c!
      nextlit @ HardLit
   then
   0 c_called c!                        \ everything clears the call tail
; is FlushLit

:noname \ NewGroup  \ --                \ finish the group and start a new one
   FlushLit                             \ if a literal is pending, compile it
   c_slot c@
   15 over - |-if 2drop exit |          \ already at first slot
   drop if
      op_no: Implicit                   \ skip unused slots
   then
   iracc @ ,c
   ClearIR
; is NewGroup

: literal,  \ n --                      \ compile a literal
   FlushLit
   1FFFFFF invert 2*  over and
   if HardLit exit then                 \ oversized literal, compile it now
   nextlit !  1 c_litpend c!            \ literal is pending
;
: compile,  \ xt --                     \ 6.2.0945  compile a call
   2/ 2/ op_call Explicit
   head @ 4 + c@  80 and  c_called c!   \ 0 = call-only
;
: ,exit  \ --
   c_called c@ if
      calladdr link>
      8  [ calladdr 3 + ] literal c@  lshift
      invert swap ROM!                  \ convert CALL to JUMP
      0 c_called c!
      0 calladdr ! exit
   then op_exit Implicit
;
decimal
