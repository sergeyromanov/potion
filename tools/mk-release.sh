#!/bin/sh
case `uname -o` in
*Linux) # native to x86_64, cross to i686 via -m32, i686-w64-mingw32-gcc and x86_64-w64-mingw32-gcc
        CC="clang-3.3"
        CROSS="i686-w64-mingw32-gcc x86_64-w64-mingw32-gcc" ;;
Darwin) # native clang not stable enough (16byte %esp alignment), use ports gcc
        CC="gcc-mp-4.8"
        CROSS="i386-mingw32-gcc" ;;
Cygwin) # native via gcc4
        CC="gcc-4"
        if [ `uname -m` = x86_64 ]; then #Cygwin64
            CC="gcc"
        fi
        ;;
esac
#LATER evtl.: ppc, arm, darwin pkg

dorelease() {
    make realclean
    echo make CC="$1"
    make CC="$1" DEBUG=0
    make test
    make dist
}

docross() {
    make clean
    rm config.inc
    echo make config CC="$1"
    make -s -f config.mak CC="$1" DEBUG=0
    make -s core/config.h
    touch syn/greg syn/syntax.c syn/syntax-p5.c
    echo make CC="$1"
    make CC="$1" DEBUG=0
    make dist
}

for c in $CC; do
    dorelease "$c"
done

# build greg and syntax.c native
make clean
make syn/syntax.c
make syn/syntax-p5.c

for c in $CROSS; do
    docross "$c"
done

case `uname -o` in
  *Linux) dorelease "gcc -m32" ;;
esac
