#!/bin/bash

# This script creates a shell environment depending on the arguments we
# provide, in which we are then able to build for simulator (either i386 or
# x86_64) or for device (currently armv7 or armv7s) without issues.
#
# Examples:
# a. simulator - 32 bit
#   $ . ./ios.script.bash simulator i386
#   $ ./configure --host=i386-apple-darwin --prefix=...
# b. simulator - 64 bit
#   $ . ./ios.script.bash simulator x86_64
#   $ ./configure --host=x86_64-apple-darwin --prefix=...
# c. device - armv7
#   $ . ./ios.script.bash iphoneos armv7
#   $ ./configure --host=armv7-apple-darwin --prefix=...
# d. device - armv7s
#   $ . ./ios.script.bash iphoneos armv7s
#   $ ./configure --host=armv7s-apple-darwin --prefix=...


SDK="iphoneos"
ARCH="armv7"

if [[ $# -ne 2 ]]
then
	echo "Usage: ios.script.bash <sdk> <architecture>"
	exit 1
fi 

if [[ $1 == "simulator" ]]
then
	SDK="iphonesimulator"
fi

ARCH=$2
I386_FLAGS=""
if [[ $2 == "i386" ]]
then
	I386_FLAGS="-m32"
fi

export DEVROOT="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer"
export SDKROOT="$(xcrun --sdk $SDK --show-sdk-path)"

if [[ $1 == "simulator" ]]
then
	export CC=$DEVROOT/usr/bin/gcc
	export CXX=$DEVROOT/usr/bin/g++
else
	export CC="/usr/bin/clang"
	export CXX="/usr/bin/clang++"
fi

export LD="${DEVROOT}/usr/bin/ld"

if [[ $1 == "simulator" ]]
then
	# there was no 'ar' in simulator DEVROOT, so I used the OSX one and worked
	export AR="/usr/bin/ar"
else
	export AR="${DEVROOT}/usr/bin/ar"
fi

export AS="${DEVROOT}/usr/bin/as"
export NM="${DEVROOT}/usr/bin/nm"

if [[ $1 == "simulator" ]]
then
	# there was no 'ranlib' in simulator DEVROOT, so I used the OSX one and worked
	export RANLIB="/usr/bin/ranlib"
else
	export RANLIB="${DEVROOT}/usr/bin/ranlib"
fi

if [[ $1 == "simulator" ]]
then
	export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/  -miphoneos-version-min=7.0"
else
	export LDFLAGS="-L${SDKROOT}/usr/lib/"
fi

#export ARCH="armv7"
export ARCH
export CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/"
#export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/"

export CPPFLAGS="${CFLAGS}"
export CXXFLAGS="${CFLAGS}"

echo "---------------"
echo "Using CC: $CC"
echo "Using SDK: $SDK"
echo "Using ARCH: $ARCH"
echo "Using DEVROOT: $DEVROOT"
echo "Using SDKROOT: $SDKROOT"
echo "Using CFLAGS: $CFLAGS"
echo "Using LDFLAGS: $LDFLAGS"
echo "Using AR: $AR"
echo "Using AS: $AS"
echo "Using NM: $NM"
echo "Using RANLIB: $RANLIB"
echo "---------------"

