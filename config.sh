CC_BASE_PREFIX=$HOME/toolchains

. configs/mmix

MAKEFLAGS=-j8

# Enable this to build the bootstrap gcc (thrown away) without optimization, to reduce build time
GCC_STAGE1_NOOPT=1
