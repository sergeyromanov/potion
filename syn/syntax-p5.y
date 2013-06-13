# -*- mode: antlr; tab-width:8 -*-
#
# syntax-p5.g
# perl5 tokens and grammar
#
# (c) 2009 _why
# (c) 2013 by perl11 org
#

%{
#ifndef P2
# define P2
#endif
#include "p2.h"
#include "internal.h"
#include "asm.h"
#include "ast.h"

#define YYSTYPE PN
#define YY_XTYPE Potion *
#define YY_XVAR P

#define YY_INPUT(G, buf, result, max) { \
  YY_XTYPE P = G->data; \
  if (P->yypos < PN_STR_LEN(P->input)) { \
    result = max; \
    if (P->yypos + max > PN_STR_LEN(P->input)) \
      result = (PN_STR_LEN(P->input) - P->yypos); \
    PN_MEMCPY_N(buf, PN_STR_PTR(P->input) + P->yypos, char, result + 1); \
    P->yypos += max; \
  } else { \
    result = 0; \
  } \
}

#define YY_NAME(N) p5_code_##N

#define YY_TNUM 3
#define YY_TDEC 13

#ifdef YY_DEBUG
# define YYDEBUG_PARSE   DEBUG_PARSE
# define YYDEBUG_VERBOSE DEBUG_PARSE_VERBOSE

# define YY_SET(G, text, count, thunk, P) \
  yyprintf((stderr, "%s %d %p:<%s>\n", thunk->name, count,(void*)yy,\
           PN_STR_PTR(potion_send(yy, PN_string, 0)))); \
  G->val[count]= yy;
#endif

#define DEF_PSRC P->source?P->source:PN_TUP0()
//const char *Nullch = '\0';
%}

perl5 = -- s:statements end-of-file
        { $$ = P->source = PN_AST(CODE, s);
          if (yyleng) YY_ERROR(G,"** Syntax error"); }

# AST BLOCK captures lexicals
# Note that if/else blocks (mblock) do not capture lexicals
# block = '{' s:lineseq '}' { $$ = PN_AST(BLOCK, s) }

statements =
    s1:stmt           { $$ = s1 = PN_IS_TUPLE(s1) ? s1 : PN_TUP(s1) }
        (sep? s2:stmt { $$ = s1 = PN_PUSH(s1, s2) })* sep?
    | ''              { $$ = PN_NIL }

stmt = pkgdecl
    | BEGIN b:block           { p2_eval(P, b, POTION_JIT) }
    | subrout
    | use
    | ifstmt
    | assigndecl
    | block
    | s:sets semi
        ( or x:sets semi      { s = PN_OP(AST_OR, s, x) }
        | and x:sets semi     { s = PN_OP(AST_AND, s, x) })*
                              { $$ = s }
    | expr

BEGIN   = "BEGIN" space+
PACKAGE = "package" space+
USE     = "use" space+
SUB     = "sub" space+
IF      = "if" space+
ELSIF   = "elsif" space+
ELSE    = "else" space+
MY      = "my" space+

p5-siglist = list-start p:sig_p5 list-end - 
        { P->source = PN_NIL; $$ = PN_AST(LIST, P->source) }
subrout = SUB n:id - l:p5-siglist? b:block -
        { $$ = PN_AST2(ASSIGN, PN_AST(EXPR, PN_TUP(PN_AST(MSG, n))),
                               PN_AST(EXPR, PN_TUP(PN_AST2(PROTO, l, b)))) }
anonsub = SUB l:p5-siglist? b:block -
        { $$ = PN_AST2(PROTO, l, b) }
# so far no difference in global or lex assignment
#subrout = SUB n:id - l:p5-siglist?? a:subattrlist? b:block
#lexsubrout = MY - SUB n:subname p:proto? a:subattrlist? b:subbody
#        { $$ = PN_AST2(ASSIGN, n, PN_AST2(PROTO, p, b)) }
#subattrlist = ':' -? arg-name

# TODO: compile-time sideeffs (BEGIN block) in the compiler
use = USE n:id - semi    { $$ = PN_AST2(MSG, PN_STRN("use", 3), n) }

pkgdecl = PACKAGE n:arg-name semi          {} # TODO: set namespace
    | PACKAGE n:arg-name v:version? b:block

ifstmt = IF e:ifexpr s:block - !"els"  { $$ = PN_OP(AST_AND, e, s) }
       | IF e:ifexpr s1:block -        { $$ = e = PN_AST3(MSG, PN_if, PN_AST(LIST, PN_TUP(e)), s1) }
         (ELSIF e1:ifexpr f:block -    { $$ = e = PN_PUSH(PN_TUPIF(e), PN_AST3(MSG, PN_elsif, PN_AST(LIST, PN_TUP(e1)), f)) } )*
         (ELSE s2:block                { $$ = PN_PUSH(PN_TUPIF(e), PN_AST3(MSG, PN_else, PN_NIL, s2)) } )?
ifexpr = '(' - expr - ')' -

assigndecl =
        l:global - assign e:expr       { $$ = PN_AST2(ASSIGN, l, e) }
      | MY - l:lexical - assign e:expr { $$ = PN_AST2(ASSIGN, l, e) }
      # no list assignment yet my () = expr

lexical = global

sets = e:eqs?
       ( assign s:sets       { e = PN_AST2(ASSIGN, e, s) }
       | or assign s:sets    { e = PN_AST2(ASSIGN, e, PN_OP(AST_OR, e, s)) }
       | and assign s:sets   { e = PN_AST2(ASSIGN, e, PN_OP(AST_OR, e, s)) }
       | pipe assign s:sets  { e = PN_AST2(ASSIGN, e, PN_OP(AST_PIPE, e, s)) }
       | caret assign s:sets { e = PN_AST2(ASSIGN, e, PN_OP(AST_CARET, e, s)) }
       | amp assign s:sets   { e = PN_AST2(ASSIGN, e, PN_OP(AST_AMP, e, s)) }
       | bitl assign s:sets  { e = PN_AST2(ASSIGN, e, PN_OP(AST_BITL, e, s)) }
       | bitr assign s:sets  { e = PN_AST2(ASSIGN, e, PN_OP(AST_BITR, e, s)) }
       | plus assign s:sets  { e = PN_AST2(ASSIGN, e, PN_OP(AST_PLUS, e, s)) }
       | minus assign s:sets { e = PN_AST2(ASSIGN, e, PN_OP(AST_MINUS, e, s)) }
       | times assign s:sets { e = PN_AST2(ASSIGN, e, PN_OP(AST_TIMES, e, s)) }
       | div assign s:sets   { e = PN_AST2(ASSIGN, e, PN_OP(AST_DIV, e, s)) }
       | rem assign s:sets   { e = PN_AST2(ASSIGN, e, PN_OP(AST_REM, e, s)) }
       | pow assign s:sets   { e = PN_AST2(ASSIGN, e, PN_OP(AST_POW, e, s)) })?
       { $$ = e }

eqs = c:cmps
      ( cmp x:cmps          { c = PN_OP(AST_CMP, c, x) }
      | eq x:cmps           { c = PN_OP(AST_EQ, c, x) }
      | neq x:cmps          { c = PN_OP(AST_NEQ, c, x) })*
      { $$ = c }

cmps = o:bitors
       ( gte x:bitors        { o = PN_OP(AST_GTE, o, x) }
       | gt x:bitors         { o = PN_OP(AST_GT, o, x) }
       | lte x:bitors        { o = PN_OP(AST_LTE, o, x) }
       | lt x:bitors         { o = PN_OP(AST_LT, o, x) })*
       { $$ = o }

bitors = a:bitand
         ( pipe x:bitand       { a = PN_OP(AST_PIPE, a, x) }
         | caret x:bitand      { a = PN_OP(AST_CARET, a, x) })*
         { $$ = a }

bitand = b:bitshift
         ( amp x:bitshift      { b = PN_OP(AST_AMP, b, x) })*
         { $$ = b }

bitshift = s:sum
           ( bitl x:sum          { s = PN_OP(AST_BITL, s, x) }
           | bitr x:sum          { s = PN_OP(AST_BITR, s, x) })*
           { $$ = s }

sum = p:product
      ( plus x:product      { p = PN_OP(AST_PLUS, p, x) }
      | minus x:product     { p = PN_OP(AST_MINUS, p, x) })*
      { $$ = p }

product = p:power
          ( times x:power           { p = PN_OP(AST_TIMES, p, x) }
          | div x:power             { p = PN_OP(AST_DIV, p, x) }
          | rem x:power             { p = PN_OP(AST_REM, p, x) })*
          { $$ = p }

power = e:expr
        ( pow x:expr { e = PN_OP(AST_POW, e, x) })*
        { $$ = e }

expr = ( not e:expr           { e = PN_AST(NOT, e) }
       | bitnot e:expr        { e = PN_AST(WAVY, e) }
       | l:atom times !times r:atom { e = PN_OP(AST_TIMES, l, r) }
       | l:atom div   !div r:atom   { e = PN_OP(AST_DIV,  l, r) }
       | l:atom minus !minus r:atom { e = PN_OP(AST_MINUS, l, r) }
       | l:atom plus !plus r:atom  { e = PN_OP(AST_PLUS,  l, r) }
       | mminus e:value        { e = PN_OP(AST_INC, e, PN_NUM(-1) ^ 1) }
       | pplus e:value         { e = PN_OP(AST_INC, e, PN_NUM(1) ^ 1) }
       | e:value (pplus        { e = PN_OP(AST_INC, e, PN_NUM(1)) }
                | mminus       { e = PN_OP(AST_INC, e, PN_NUM(-1)) })?)
       | e:atom ( c:call { e = PN_PUSH(PN_TUPIF(e), c) } )*
       | e:method
       { $$ = PN_AST(EXPR, e) }

# removed lambda (anonsub)
atom = e:value | e:list | e:call | e:anonsub

#FIXME methods and indirect methods:
#   chr 101 => (expr (value (101), msg ("chr")))
#   print chr 101 => (expr (value (101), msg ("chr"), msg ("print")))
#   obj->meth(args) => (expr (msg obj), msg (meth) list (expr args))
call = m:name l:list l1:list?
        { l1 = PN_IS_TUPLE(PN_S(l,0))?potion_tuple_shift(P,0,PN_S(l,0)):PN_AST(VALUE,0);
          if (!PN_S(l,0)) { PN_SRC(m)->a[1] = PN_SRC(l); }
          $$ = PN_AST(EXPR, PN_PUSH(PN_TUP(l1), m)); }
     | m:name        { $$ = PN_AST(EXPR, PN_TUP(m)) }

method = v:value - arrow m:name l:list  { PN_SRC(m)->a[1] = PN_SRC(l); $$ = PN_PUSH(PN_TUPIF(v), m) }
       | v:value - arrow m:name         { $$ = PN_PUSH(PN_TUPIF(v), m) }

name = !keyword m:msg     { $$ = PN_AST(MSG, m) }

lick-items = i1:lick-item     { $$ = i1 = PN_TUP(i1) }
            (sep i2:lick-item { $$ = i1 = PN_PUSH(i1, i2) })*
             sep?
           | ''               { $$ = PN_NIL }

lick-item = m:msg t:list v:loose { $$ = PN_AST3(LICK, m, v, t) }
          | m:msg t:list { $$ = PN_AST3(LICK, m, PN_NIL, t) }
          | m:msg v:loose t:list { $$ = PN_AST3(LICK, m, v, t) }
          | m:msg v:loose { $$ = PN_AST2(LICK, m, v) }
          | m:msg         { $$ = PN_AST(LICK, m) }

loose = value
      | v:unquoted { $$ = PN_AST(VALUE, v) }

# anonymous sub, w or w/o proto (aka list)
#sub = 'sub' - n:arg-name - t:list? b:block  { PN_AST2(ASSIGN, n, PN_AST2(PROTO, t, b)) }
list = list-start s:statements list-end -    { $$ = PN_AST(LIST, s) }
block = block-start s:statements block-end - { $$ = PN_AST(BLOCK, s) }
lick = lick-start i:lick-items lick-end -    { $$ = PN_AST(LIST, i) }
group = group-start s:statements group-end - { $$ = PN_AST(EXPR, s) }

#path = '/' < utfw+ > - { $$ = PN_STRN(yytext, yyleng) }
#path    = < utfw+ > -  { $$ = PN_STRN(yytext, yyleng) }
msg = < utfw+ > -   { $$ = PN_STRN(yytext, yyleng) }

value = i:immed - { $$ = PN_AST(VALUE, i) }
      | global
      | lick
      | group

immed = undef { $$ = PN_NIL }
#      | true  { $$ = PN_TRUE }
#      | false { $$ = PN_FALSE }
      | hex   { $$ = PN_NUM(PN_ATOI(yytext, yyleng, 16)) }
      | dec   { $$ = ($$ == YY_TNUM) ? PN_NUM(PN_ATOI(yytext, yyleng, 10))
                   : potion_decimal(P, yytext, yyleng) }
      | str1 | str2

global  = scalar | listvar | hashvar | listel | hashel | funcvar | globvar
# FIXME: starting wordchar (no numbers) + wordchars
id = < IDFIRST utfw* > { $$ = PN_STRN(yytext, yyleng) }
# send the value a msg, every global is a closure (see name)
scalar  = < '$' i:id > - { $$ = PN_AST(MSG, PN_STRCAT("$", PN_STR_PTR(i))) }
listvar = < '@' i:id > - { $$ = PN_AST(MSG, PN_STRCAT("@", PN_STR_PTR(i))) }
hashvar = < '%' i:id > - { $$ = PN_AST(MSG, PN_STRCAT("%", PN_STR_PTR(i))) }
funcvar = < '&' i:id > - { $$ = PN_AST(MSG, PN_STRCAT("&", PN_STR_PTR(i))) }
globvar = < '*' i:id > - { $$ = PN_AST(MSG, PN_STRCAT("*", PN_STR_PTR(i))) }
listel  = < '$' l:id - '[' - i:value - ']' > -
        { $$ = PN_AST2(LICK, PN_STRCAT("@", PN_STR_PTR(l)), i) }
hashel  = < '$' h:id - '{' - i:value - '}' > -
        { $$ = PN_AST2(LICK, PN_STRCAT("%", PN_STR_PTR(h)), i) }

# isWORDCHAR && IDFIRST, no numbers
IDFIRST = [A-Za-z_]
     | '\304' [\250-\277]
     | [\305-\337] [\200-\277]
     | [\340-\357] [\200-\277] [\200-\277]
     | [\360-\364] [\200-\277] [\200-\277] [\200-\277]
# isWORDCHAR? \w and [:word:]
utfw = [A-Za-z0-9_]
     | '\304' [\252-\277]
     | [\305-\337] [\200-\277]
     | [\340-\357] [\200-\277] [\200-\277]
     | [\360-\364] [\200-\277] [\200-\277] [\200-\277]
# isWORDCHAR && XID_Continue
#IDCONT = [A-Za-z0-9_ ():\240-]
#     | '\304' [\250-\277]
#     | [\305-\337] [\200-\277]
#     | [\340-\357] [\200-\277] [\200-\277]
#     | [\360-\364] [\200-\277] [\200-\277] [\200-\277]
#IDPRINT = [\40-\176]
#     | [\302-\337] [\200-\277]
#     | [\340-\357] [\200-\277] [\200-\277]
#     | [\360-\364] [\200-\277] [\200-\277] [\200-\277]
utf8 = [\t\n\r\40-\176]
     | [\302-\337] [\200-\277]
     | [\340-\357] [\200-\277] [\200-\277]
     | [\360-\364] [\200-\277] [\200-\277] [\200-\277]

semi = ';'
comma = ','
arrow = "->" -
block-start = '{' space*
block-end = semi? space* '}'
list-start = '(' -
list-end = ')' -
lick-start = '[' -
lick-end = ']' -
group-start = '{'
group-end = '}'
bitnot = '~' -
assign = '=' -
pplus = "++" -
mminus = "--" -
minus = '-' -
plus = '+' -
times = '*' -
div = '/' -
rem = '%' -
pow = "**" -
bitl = "<<" -
bitr = ">>" -
amp = '&' -
caret = '^' -
pipe = '|' -
lt = '<' -
lte = "<=" -
gt = '>' -
gte = ">=" -
neq = ("!=" | "ne" !utfw) --
eq = ("==" | "eq" !utfw) --
cmp = "<=>" --
and = ("&&" | "and" !utfw) --
or = ("||" | "or" !utfw) --
not = ("!" | "not" !utfw) --
# only compiler specific keywords
keyword = ("and" | "or" | "not")

undef = "undef" !utfw
#true = "true" !utfw
#false = "false" !utfw
hexl = [0-9A-Fa-f]
hex = '0x' < hexl+ >
dec = < ('0' | [1-9][0-9]*) { $$ = YY_TNUM }
        ('.' [0-9]+ { $$ = YY_TDEC })?
        ('e' [-+] [0-9]+ { $$ = YY_TDEC })? >
version = 'v'? < ('0' | [1-9][0-9]*) { $$ = YY_TNUM }
          ('.' [0-9]+ { $$ = YY_TDEC })? >

q1 = [']   # ' emacs highlight problems
c1 = < (!q1 utf8)+ > { P->pbuf = potion_asm_write(P, P->pbuf, yytext, yyleng) }
str1 = q1 { P->pbuf = potion_asm_clear(P, P->pbuf) }
       < (q1 q1 { P->pbuf = potion_asm_write(P, P->pbuf, "'", 1) } | c1)* >
       q1 { $$ = potion_bytes_string(P, PN_NIL, (PN)P->pbuf) }

esc         = '\\'
escn        = esc 'n' { P->pbuf = potion_asm_write(P, P->pbuf, "\n", 1) }
escb        = esc 'b' { P->pbuf = potion_asm_write(P, P->pbuf, "\b", 1) }
escf        = esc 'f' { P->pbuf = potion_asm_write(P, P->pbuf, "\f", 1) }
escr        = esc 'r' { P->pbuf = potion_asm_write(P, P->pbuf, "\r", 1) }
esct        = esc 't' { P->pbuf = potion_asm_write(P, P->pbuf, "\t", 1) }
escu        = esc 'u' < hexl hexl hexl hexl > {
  int nbuf = 0;
  char utfc[4] = {0, 0, 0, 0};
  unsigned long code = PN_ATOI(yytext, yyleng, 16);
  if (code < 0x80) {
    utfc[nbuf++] = code;
  } else if (code < 0x7ff) {
    utfc[nbuf++] = (code >> 6) | 0xc0;
    utfc[nbuf++] = (code & 0x3f) | 0x80;
  } else {
    utfc[nbuf++] = (code >> 12) | 0xe0;
    utfc[nbuf++] = ((code >> 6) & 0x3f) | 0x80;
    utfc[nbuf++] = (code & 0x3f) | 0x80;
  }
  P->pbuf = potion_asm_write(P, P->pbuf, utfc, nbuf);
}
escc = esc < utf8 > { P->pbuf = potion_asm_write(P, P->pbuf, yytext, yyleng) }

q2 = ["]
e2 = '\\' ["] { P->pbuf = potion_asm_write(P, P->pbuf, "\"", 1) }
c2 = < (!q2 !esc utf8)+ > { P->pbuf = potion_asm_write(P, P->pbuf, yytext, yyleng) }
str2 = q2 { P->pbuf = potion_asm_clear(P, P->pbuf) }
       < (e2 | escn | escb | escf | escr | esct | escu | escc | c2)* >
       q2 { $$ = potion_bytes_string(P, PN_NIL, (PN)P->pbuf) }

unq-char = '{' unq-char+ '}'
         | '[' unq-char+ ']'
         | '(' unq-char+ ')'
         | !'{' !'[' !'(' !'}' !']' !')' utf8
unq-sep = sep !'{' !'[' !'('
unquoted = < (!unq-sep !lick-end unq-char)+ > { $$ = PN_STRN(yytext, yyleng) }

- = (space | comment)*
-- = (space | comment | semi)*
sep = semi (space | comment | semi)*
comment	= '#' (!end-of-line utf8)*
# PSXSPC
# \240 U+A0 NO-BREAK SPACE
# \205 U+85 NEL
space = ' ' | '\f' | '\v' | '\t' | '\205' | '\240' | end-of-line
end-of-line = '\r\n' | '\n' | '\r' { $$ = PN_AST2(DEBUG, PN_NUM(G->lineno), PN_NIL) }
end-of-file = !'\0'

# for potion_sig, used in the runtime initialization
sig = args+ end-of-file
args = arg-list (arg-sep arg-list)*
arg-list = arg-set (optional arg-set)?
         | optional arg-set
arg-set = arg (comma - arg)*

arg-name = < utfw+ > - { $$ = PN_STRN(yytext, yyleng) }
# types are numbers
arg-type = < ('s' | 'S' | 'n' | 'N' | 'b' | 'B' | 'k' | 't' | 'o' | 'O' | '-' | '&') > -
       { $$ = PN_NUM(yytext[0]) }
arg = n:arg-name assign t:arg-type
                       { P->source = PN_PUSH(PN_PUSH(PN_PUSH(P->source, n), t), PN_NIL) }
    | t:arg-type       { P->source = PN_PUSH(P->source, t) }
optional = '|' -       { P->source = PN_PUSH(P->source, PN_NUM('|')) }
arg-sep = '.' -        { P->source = PN_PUSH(P->source, PN_NUM('.')) }

# p5 sigs. used by the seperate p2_sig
sig_p5 = args2* end-of-file
args2 = arg2-list (arg2-yada)*
yada = "..."
arg2-yada = yada -    { P->source = PN_PUSH(P->source, PN_NUM('.')) }
arg2-list = arg2-set (optional arg2-set)?
         | optional arg2-set
arg2-set = arg2 (comma - arg2)*

arg2-name = < [$@%] id > - { $$ = PN_STRN(yytext, yyleng) }
# types are classes
arg2-type = i:id space+  { $$ = potion_class_find(P, i); if (!$$) yyerror(G,"Invalid type") }
arg2 = n:arg2-name
      { P->source = PN_PUSH(DEF_PSRC, n) }
    | t:arg2-type n:arg2-name
      { P->source = PN_PUSH(PN_PUSH(DEF_PSRC, n), t) }
    | n:arg2-name - '=' - d:value
      { P->source = PN_PUSH(PN_PUSH(PN_PUSH(DEF_PSRC, n), PN_NUM(':')), d) }
    | t:arg2-type n:arg2-name - '=' - d:value
      { if (t != PN_TYPE(d)) yyerror(G,"wrong type of default argument");
        P->source = PN_PUSH(PN_PUSH(PN_PUSH(DEF_PSRC, n), PN_NUM(':')), d) }

%%

PN p2_parse(Potion *P, PN code, char *filename) {
  GREG *G = YY_NAME(parse_new)(P);
  P->yypos = 0;
  P->input = code;
  P->source = PN_NIL;
  P->pbuf = potion_asm_new(P);
#ifdef YY_DEBUG
  yydebug = P->flags & (DEBUG_PARSE | DEBUG_PARSE_VERBOSE);
#endif

  G->filename = filename;
  if (!YY_NAME(parse)(G)) {
    YY_ERROR(G, "** Syntax error");
    fprintf(stderr, "%s", PN_STR_PTR(code));
  }
  YY_NAME(parse_free)(G);

  code = P->source;
  P->source = PN_NIL;
  return code;
}

// duplicate but still needed to compile internal methods
PN potion_sig(Potion *P, char *fmt) {
  PN out = PN_NIL;
  if (fmt == NULL) return PN_NIL;
  if (fmt[0] == '\0') return PN_FALSE;

  GREG *G = YY_NAME(parse_new)(P);
  P->yypos = 0;
  P->input = potion_byte_str(P, fmt);
  P->source = out = PN_TUP0();
  P->pbuf = NULL;

  if (!YY_NAME(parse_from)(G, yy_sig))
    YY_ERROR(G, "** Signature syntax error");
  YY_NAME(parse_free)(G);

  out = P->source;
  P->source = PN_NIL;
  return out;
}

PN p2_sig(Potion *P, char *fmt) {
  PN out = PN_NIL;
  if (fmt == NULL) return PN_NIL; // no signature, arg check off
  if (fmt[0] == '\0') return PN_FALSE; // empty signature, no args

  GREG *G = YY_NAME(parse_new)(P);
  P->yypos = 0;
  P->input = potion_byte_str(P, fmt);
  P->source = out = PN_TUP0();
  P->pbuf = NULL;

  if (!YY_NAME(parse_from)(G, yy_sig_p5))
    YY_ERROR(G, "** Signature syntax error");
  YY_NAME(parse_free)(G);

  out = P->source;
  P->source = PN_NIL;
  return out;
}

int potion_sig_find(Potion *P, PN cl, PN name)
{
  PN_SIZE idx = 0;
  PN sig;
  if (!PN_IS_CLOSURE(cl))
    cl = potion_obj_get_call(P, cl);

  if (!PN_IS_CLOSURE(cl))
    return -1;

  sig = PN_CLOSURE(cl)->sig;

  if (!PN_IS_TUPLE(sig))
    return -1;

  PN_TUPLE_EACH(sig, i, v, {
    if (v == PN_NUM(idx) || v == name)
      return idx;
    if (PN_IS_NUM(v))
      idx++;
  });

  return -1;
}
