# Definitions for build scripts
# 
# Copyright (C) 2012-2014 Gregor Richards
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

ORIGPWD="$PWD"
cd "$MUSL_CC_BASE"
MUSL_CC_BASE="$PWD"
export MUSL_CC_BASE
cd "$ORIGPWD"
unset ORIGPWD

if [ ! -e config.sh ]
then
    echo 'Create a config.sh file.'
    exit 1
fi

# Versions of things (do this before config.sh so they can be config'd)
#BINUTILS_URL=http://ftp.gnu.org/gnu/binutils/binutils-2.25.1.tar.bz2
BINUTILS_URL=http://mirrors.kernel.org/sourceware/binutils/snapshots/binutils-2.24.90.tar.bz2
#last GPL2 release is 2.17, with backported  -Bsymbolic support
#BINUTILS_URL=http://landley.net/aboriginal/mirror/binutils-2.17.tar.bz2
GCC_VERSION=4.2.4
GDB_VERSION=7.9.1
GMP_VERSION=6.1.0
MPC_VERSION=1.0.3
MPFR_VERSION=3.1.4
LIBELF_VERSION=master
# check available versions at ftp://sourceware.org/pub/newlib/index.html
NEWLIB_VERSION=1.19.0

# You can choose languages
LANG_CXX=no
LANG_OBJC=no
LANG_FORTRAN=no

. ./config.sh

# Auto-deteect an ARCH if not specified
ARCH=mmix
TRIPLE=mmix

# Choose our languages
LANGUAGES=c
[ "$LANG_CXX" = "yes" ] && LANGUAGES="$LANGUAGES,c++"
[ "$LANG_OBJC" = "yes" ] && LANGUAGES="$LANGUAGES,objc"
[ "$LANG_CXX" = "yes" -a "$LANG_OBJC" = "yes" ] && LANGUAGES="$LANGUAGES,obj-c++"
[ "$LANG_FORTRAN" = "yes" ] && LANGUAGES="$LANGUAGES,fortran"

# Use gmake if it exists
if [ -z "$MAKE" ]
then
    MAKE=make
    gmake --help > /dev/null 2>&1 && MAKE=gmake
fi

# Generate CC_PREFIX from CC_BASE_PREFIX and TRIPLE if not specified
[ -n "$CC_BASE_PREFIX" -a -z "$CC_PREFIX" ] && CC_PREFIX="$CC_BASE_PREFIX/$TRIPLE"
[ -z "$CC_PREFIX" ] && die 'Failed to determine a CC_PREFIX.'

PATH="$CC_PREFIX/bin:$PATH"
export PATH

# Get the target-specific multilib option, if applicable
GCC_MULTILIB_CONFFLAGS="--disable-multilib --with-multilib-list="
if [ "$ARCH" = "x32" ]
then
    GCC_MULTILIB_CONFFLAGS="--with-multilib-list=mx32"
fi

die() {
    echo "$@"
    exit 1
}

fetch() {
    if [ ! -e "$MUSL_CC_BASE/tarballs/$2" ]
    then
        wget -O "$MUSL_CC_BASE/tarballs/$2.part" -c "$1""$2"
        mv "$MUSL_CC_BASE/tarballs/$2.part" "$MUSL_CC_BASE/tarballs/$2"
    fi
    return 0
}

extract() {
    if [ ! -e "$2/extracted.$3" ]
    then
        tar xf "$MUSL_CC_BASE/tarballs/$1" ||
            tar Jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar jxf "$MUSL_CC_BASE/tarballs/$1" ||
            tar zxf "$MUSL_CC_BASE/tarballs/$1"
        mkdir -p "$2"
        touch "$2/extracted.$3"
    fi
}

stripfileext() {
	case "$1" in
		*.tar.*) printf "%s" "$1"| sed 's/\.tar\.[0-9a-z]*$//' ;;
		*) basename "$1" | sed 's/\..*//' ;;
	esac
}

fetchextract() {
    name="$1"
    shift
    baseurl="$1"
    [ -z "$2" ] && baseurl=$(printf "%s" "$1" | sed 's/\(.*\/\).*/\1/')
    dir="$2"
    [ -z "$dir" ] && dir=$(stripfileext $(basename "$1"))
    fn="$2""$3"
    [ -z "$fn" ] && fn=$(basename "$1")

    fetch "$baseurl" "$fn"
    extract "$fn" "$dir" "$name"
}

gitfetchextract() {
    name="$1"
    shift
    if [ ! -e "$MUSL_CC_BASE/tarballs/$3".tar.gz ]
    then
        git archive --format=tar --remote="$1" "$2" | \
            gzip -c > "$MUSL_CC_BASE/tarballs/$3".tar.gz || die "Failed to fetch $3-$2"
    fi
    if [ ! -e "$3/extracted.$name" ]
    then
        mkdir -p "$3"
        (
        cd "$3" || die "Failed to cd $3"
        extract "$3".tar.gz extracted
        touch extracted.$name
        )
    fi
}

newlibfetchextract() {
    fetchextract newlib http://mirrors.kernel.org/sourceware//newlib/ newlib-${NEWLIB_VERSION} .tar.gz
}

gccprereqs() {
    if [ ! -e gcc-$GCC_VERSION/gmp ]
    then
        fetchextract gmp http://ftp.gnu.org/pub/gnu/gmp/ gmp-$GMP_VERSION .tar.bz2
        mv gmp-$GMP_VERSION gcc-$GCC_VERSION/gmp
    fi

    if [ ! -e gcc-$GCC_VERSION/mpfr ]
    then
        fetchextract mpfr http://ftp.gnu.org/gnu/mpfr/ mpfr-$MPFR_VERSION .tar.bz2
        mv mpfr-$MPFR_VERSION gcc-$GCC_VERSION/mpfr
    fi

    if [ ! -e gcc-$GCC_VERSION/mpc ]
    then
        fetchextract mpc https://ftp.gnu.org/gnu/mpc/ mpc-$MPC_VERSION .tar.gz
        mv mpc-$MPC_VERSION gcc-$GCC_VERSION/mpc
    fi
}

patch_source() {
    BD="$1"

    (
    cd "$BD" || die "Failed to cd $BD"

    if [ ! -e patched ]
    then
        for f in "$MUSL_CC_BASE/patches/$BD"-*.diff ; do
            if [ -e "$f" ] ; then patch -p1 < "$f" || die "Failed to apply patch $f to $BD" ; fi
        done
        touch patched
    fi
    )
}

build() {
    BP="$1"
    BD="$2"
    CF="./configure"
    BUILT="$PWD/$BD/built$BP"
    shift; shift

    if [ ! -e "$BUILT" ]
    then
        patch_source "$BD"

        (
        cd "$BD" || die "Failed to cd $BD"

        if [ "$BP" ]
        then
            mkdir -p build"$BP"
            cd build"$BP" || die "Failed to cd to build dir for $BD $BP"
            CF="../configure"
        fi
        ( $CF --prefix="$PREFIX" "$@" &&
            $MAKE $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        )
    fi
}

buildmake() {
    BD="$1"
    BUILT="$PWD/$BD/built"
    shift

    if [ ! -e "$BUILT" ]
    then
        patch_source "$BD"

        (
        cd "$BD" || die "Failed to cd $BD"

        ( $MAKE "$@" $MAKEFLAGS &&
            touch "$BUILT" ) ||
            die "Failed to build $BD"

        )
    fi
}

doinstall() {
    BP="$1"
    BD="$2"
    INSTALLED="$PWD/$BD/installed$BP"
    shift; shift

    if [ ! -e "$INSTALLED" ]
    then
        (
        cd "$BD" || die "Failed to cd $BD"

        if [ "$BP" ]
        then
            cd build"$BP" || die "Failed to cd build$BP"
        fi

        ( $MAKE install "$@" $MAKEINSTALLFLAGS &&
            touch "$INSTALLED" ) ||
            die "Failed to install $BP"

        )
    fi
}

buildinstall() {
    build "$@"
    doinstall "$1" "$2"
}
