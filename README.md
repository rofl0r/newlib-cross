About newlib-cross
==================

This is a small suite of scripts and patches to build a newlib gcc toolchain
for a number of supported systems, or just regular newlib toolchain for
baremetal systems that don't require any additional patches.

supported:
mmix - cross-compiler for knuth's MMIX simulator.
       note: this compiler builds without custom patches, but only gcc 4.2.4
       is tested (see configs/mmix).
psp  - cross-compiler for playstation portable, intended to be used with
       pspsdk ( https://github.com/pspdev/pspsdk ).
       supported are all versions where there exists a gcc-x.x.x-psp.diff
       in patches/.

./build.sh should build a cross compiler to $HOME/toolchains, no muss, no fuss.
You should edit config.sh to select a config preset and eventually override
paths, and component versions to your likings. 
you may even copy config.sh to another directory then run build.sh from there
to avoid polluting the source dir, but clean.sh can always clean up after a
build.

Notes on building normal cross compilers
========================================

* You can set versions of binutils, GCC or newlib in config.sh with:

        BINUTILS_VERSION=<version>
        GCC_VERSION=<version>
        NEWLIB_VERSION=<version>

only tested versions are the ones set by default.

* You can set configure flags for each step:

        BINUTILS_CONFFLAGS=...
        GCC_BOOTSTRAP_CONFFLAGS=...
        NEWLIB_CONFFLAGS=...
        GCC_CONFFLAGS=...

* If you do not have the GMP, MPFR and/or MPC development libraries on your
  host, you can build them along with GCC with a config.sh line:

        GCC_BUILTIN_PREREQS=yes


Other scripts and helpers
=========================

* config.sh is an example configuration file. In many cases, it will do exactly
  what you want it to do with no modification, which is why it's simply named
  "config.sh" instead of, e.g., "config-sample.sh"

* extra/build-gcc-deps.sh will build the dependencies for GCC into the build
  prefix specified by config.sh, which are just
  often a nice thing to have. It is of course not necessary.


Requirements
============

newlib-cross depends on:

* shell and core utils (busybox is fine)
* mercurial or git (for checkout only)
* wget (busybox is fine)
* patch
* gcc
* make
* awk

The following are GCC dependencies, which can be installed on the host system,
or installed automatically using `GCC_BUILTIN_PREREQS=yes`:
ONLY NEEDED FOR GCC versions >= 4.3

* gmp
* mpfr
* mpc

Building GMP additionally requires m4.
