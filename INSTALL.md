# ~ building potion ~

Normally

    $ make

To build with debugging symbols

    $ make DEBUG=1

To build without JIT

    $ make JIT=0

Lastly, to verify your build

    $ make test

## ~ the latest potion ~

To build the bleeding edge, you will need
GNU make, binutils, perl, sed, and gcc or clang.

    $ git clone --branch master git://github.com/perl11/potion.git
    $ cd potion
    $ make

## ~ external dependencies ~

    build-time: gnu make, perl, sed, gcc or clang, echo, cat, expr, git
    (perl is only needed because of BSD/darwin sed problems)

    run-time:
    libuv, sregex, libtommath are included, but external packagers
    should choose to use existing packages. see dist.mak

    optional:

    libudis on x86 (debugging only)
      http://udis86.sourceforge.net/ x86 16,32,64 bit
      port install udis86

    libdistorm64 on x86 (debugging only)
      http://ragestorm.net/distorm/ x86 16,32,64 bit with all intel/amd extensions
      apt-get install libdistorm64-dev

    libdisasm on i386 (debugging only)
      http://bastard.sourceforge.net/libdisasm.html 386 32bit only
      apt-get install libdisasm-dev

    sloccount (for make sloc)
      apt-get install sloccount

    redcloth (for make doc install)
      apt-get install ruby-redcloth, or
      port install rb-redcloth

    doxygen 1.8 or 1.9 (for make doc install)
      apt-get install doxygen, or
      port install doxygen

    GNU global (for make docall install)
      apt-get install global, or
      port install global

## ~ installing ~

    $ sudo make install

## ~ building on windows ~

Potion's win32 binaries are built using MinGW.
<http://mingw.org/>

It's a bit hard to setup mingw and gmake on Windows.
I usually run a shell under Cygwin and add MinGW
to my $PATH.

Once that's all done,

    $ make

The easiest way to do this, actually, is on Linux or Darwin.
On Ubuntu, if you have MinGW installed,

    $ make; make clean
    $ make config CC=i586-mingw32msvc-gcc
    $ touch core/syntax.c
    $ make && make dist

This will first create a native greg and core/syntax.c,
sets CROSS=1 and cross-compile with the given CC.
See tools/mk-release.sh

make test will not work, you need to copy a make dist tarball
to the machine and test it there.

## ~ building on bsd ~

BSD make is not supported.
You can either install gnu make (gmake)

    $ sudo port install gmake

or try ./configure which creates a special BSD config.mk

or try to merge 'master' with the branch 'bsd'

    $ git merge bsd
    ... resolve conflicts, or not

## ~ building with a strict C++ compiler ~

potion does not support strict C++ compilers.

Either add a C dialect to CC in config.inc (i.e. -std=c89),

    g++ --help=C; clang++ -x C -std=gnu89

or try to merge with the branch 'p2-c++'.

## ~ creating documentation ~

This is required for make install and release admins.
You'll need

    redcloth to convert .textile to html,
    doxygen (1.8 or 1.9), and
    GNU global for gtags and htags

