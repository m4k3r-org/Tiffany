\ Interpreter words

\ convert char to uppercase, also used by `hfind`
: toupper  \ c -- c'
   dup [char] a [char] { within \ }
   32 and -
;
\ convert char to digit, return `ok` flag
: digit?  \ c base -- n ok?
   >r  toupper  [char] 0 -
   dup 10 17 within 0= >r               \ check your blind spot
   dup 9 > 7 and -
   r> over r> u< and                    \ check the base
;
\ convert string to number, stopping at first non-digit
: >number       \ ud a u -- ud a u      \ 6.1.0570
   begin dup
   while >r  dup >r c@ base @ digit?
   while swap base @ um* drop rot base @ um* d+ r> char+ r> 1-
   repeat drop r> r> then
;

: source    tibs 2@ ;                   \ -- addr len  entire source string
: /source   source >in @ /string ;      \ -- addr len  remaining source string

: skip  \ c-addr1 u1 char -- c-addr2 u2
   >r begin
      dup ifz: r> drop exit |           \ zero length quits
      over c@ r@ xor 0=
      |ifz r> drop exit |               \ mismatch quits
      1 /string
   again
;
: scan  \ c-addr1 u1 char -- c-addr2 u2
   >r begin
      dup ifz: r> drop exit |           \ zero length quits
      over c@ r@ xor
      |ifz r> drop exit |               \ mismatch quits
      1 /string
   again
;
: parse  \ char "ccc<char>" -- c-addr u \ 6.2.2008
   /source  over >r  rot scan  r>  rot over -  rot 0<>
   1 and over + >in +!
;
\ Version of parse that skips leading delimiters
: _parse  \ char "<chars>ccc<char>" -- c-addr u
   >r  /source over  r@ swap >r         \ a u char | char a
   skip drop r> - >in +!  r> parse      \ a u
;
: parse-name                            \ 6.2.2020
   bl _parse  \ "<spaces>name" -- c-addr u
;
: word  \ c "<ccc>string<c>" -- c-addr  \ 6.1.2450
   _parse pad  dup >r c!
   r@ c@+ cmove  r>                     \ use pad as temporary
;

: char  \ "char" -- n                   \ 6.1.0895
   parse-name drop c@
;

\ A version of FIND that accepts a counted string and returns a header token.
\ `toupper` converts a character to lowercase
\ `c_casesens` is the case-sensitive flag
\ `match` checks two strings for mismatch and keeps the first string
\ `_hfind` searches one wordlist for the string

: match  \ a1 n1 a2 n2 -- a1 n1 0 | nonzero
   third over xor 0=                    \ n2 <> n1
   |ifz drop dup xor exit |             \ a1 n1 0 | a1 n1 a2 n2
   drop over >r third >r  swap negate   \ a1 a2 -n | n1 a1
   begin >r
      c@+ >r swap c@+ r>                \ a2' a1' c1 c2 | n1 a1 -n
      c_casesens c@ 0= if
         toupper swap toupper           \ not case sensitive
      then
      xor if                            \ mismatch
         r> 3drop r> r>
         dup dup xor exit               \ 0
      then
   r> 1+ +until
   3drop r> drop r> 1+                  \ flag is n1+1
;
: _hfind  \ addr len wid -- addr len 0 | ht    Search one wordlist
   @ over 31 u> -19 and throw           \ name too long
   over ifz: dup xor exit |             \ addr 0 0   zero length string
   begin
      dup >r cell+ c@+  63 and          \ addr len 'name length | wid
      match if
         r> exit                        \ return only the ht
      then
      r> link>
   dup 0= until                         \ not found
;
: hfind  \ addr len -- addr len | 0 ht  \ search the search order
   c_wids c@ begin
      1- |-if 2drop exit |              \ finished, not found
      >r
      r@ cells context + @ _hfind       \ wid
      ?dup if
        r> dup xor swap exit
      then
      r> dup
   again
;
: CaseInsensitive  0 c_casesens c! ;
: CaseSensitive    1 c_casesens c! ;

\ Header space:     W len xtc xte link name
\ offset from ht: -16 -12  -8  -4    0 4

: h'  \ "name" -- ht
   parse-name  hfind  swap 0<>          \ len -1 | ht 0
   -13 and throw                        \ header not found
;
: '   \ "name" -- xte                   \ 6.1.0070
   h' cell- link>
;


\ Recognize a string as a number if possible.

\ Formats:
\ Leading minus applies to entire string.
\ A decimal anywhere means it's a 32-bit floating point number.
\ If string is bracketed by '' and inside is a valid utf-8 sequence, it's xchar.
\ $ prefix is hex.

\ get sign from start of string
: numbersign  \ addr u -- addr' u' sign
   over c@  [char] - =  dup >r
   if 1 /string then        r>
;
\ Attempt to convert to an integer in the current base
: tonumber  \ addr len -- n
   0 dup 2swap >number 0<> -13 and throw  2drop
;
hex
\ Attempt to convert utf-8 code point
: nextutf8  \ n a -- n' a'              \ add to utf-8 xchar
   >r 6 lshift r> count                 \ expect 80..BF
   dup 0C0 and 80 <> -0D and throw      \ n' a c
   3F and  swap >r  +  r>
;
: isutf8  \ addr len -- xchar
   over c@ 0F0 <  over 1 = and  if      \ plain ASCII
      drop c@ exit
   then
   over c@ 0E0 <  over 2 = and  if      \ 2-byte utf-8
      drop count 1F and  swap  nextutf8
      drop exit
   then
   over c@ 0F0 <  over 3 = and  if      \ 3-byte utf-8
      drop count 1F and  swap  nextutf8  nextutf8
      drop exit
   then
   -0D throw
;
decimal
\ Attempt to convert string to a number
: isnumber  \ addr u -- n
   numbersign  >r                       \ accept leading '-'
   2dup [char] . scan nip if            \ is there a decimal?
      -40 throw                         \ floats not implemented
   then
   dup 2 > if                           \ possible 'c' or 0x
      2dup over + 1-  c@ swap c@        \ a u c1 c2
      over = swap [char] ' = and        \ a u  is enclosed by ''
      if  1 /string 1- isutf8           \ attempt character
         r> if negate then  exit
      then
      over c@ [char] $ = if             \ leading $
         base @ >r hex  1 /string  tonumber
         r> base !
         r> if negate then  exit
      then
   then
   tonumber  r> if negate then
;

\ These expect a Forth QUIT loop for THROW to work.

: interpret
   begin  \ >in @ w_>in w!              \ save position in case of error (remove)
      parse-name  dup                   \ next blank-delimited string
   while
      hfind                             \ addr len | 0 ht
      over if
         isnumber
         state @ if literal, then
      else
         nip
         dup head !                     \ save last found word's head
         state @ 0= 0= 4 and            \ get offset to the xt
         cell+ -  link>                 \ get xtc or xte
         dup 8388608 and 0<>            \ is it a C function?
         -21 and throw                  \ that's a problem
         execute                        \ execute the xt
      then
      depth 0< -4 and throw             \ stack underflow
   repeat  2drop
;
