#!/bin/bash
#
# Usage:
# $ . <sdk> <arch>
#
# Examples:
# . iphonesimulator i386
function build()
{

	#SDK="iphoneos"
	#ARCH="armv7"

	#if [[ $# -ne 2 ]]
	#then
	#	echo "Usage: ios.script.bash <sdk> <architecture>"
	#	exit 1
	#fi 

	## Setup environment for build
	#if [[ $1 == "simulator" ]]
	#then
	#	SDK="iphonesimulator"
	#fi
	SDK=$1
	ARCH=$2
	echo "--- Building for: $SDK, $ARCH"

	# cleanup previous runs
	echo "--- Cleaning up"
   make distclean > /dev/null

	I386_FLAGS=""
	if [[ $2 == "i386" ]]
	then
		I386_FLAGS="-m32"
	fi

	export DEVROOT="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer"
	export SDKROOT="$(xcrun --sdk $SDK --show-sdk-path)"

	if [[ $1 == "iphonesimulator" ]]
	then
		export CC="$(xcrun --sdk $SDK --find clang)"
		export CXX="$(xcrun --sdk $SDK --find clang++)"
		#export CC="$(xcrun --sdk $SDK --find gcc)"
		#export CXX="$(xcrun --sdk $SDK --find g++)"
		# no longer exist:
		#export CC=$DEVROOT/usr/bin/gcc
		#export CXX=$DEVROOT/usr/bin/g++
	else
		export CC="$(xcrun --sdk $SDK --find clang)"
		export CXX="$(xcrun --sdk $SDK --find clang++)"
	fi

	export LD="$(xcrun --sdk $SDK --find ld)"

	if [[ $1 == "iphonesimulator" ]]
	then
		# there was no 'ar' in simulator DEVROOT, so I used the OSX one and worked
		#export AR="/usr/bin/ar"
		export AR="$(xcrun --sdk $SDK --find ar)"
	else
		export AR="$(xcrun --sdk $SDK --find ar)"
	fi

	export AS="$(xcrun --sdk $SDK --find as)"
	export NM="$(xcrun --sdk $SDK --find nm)"

	if [[ $1 == "iphonesimulator" ]]
	then
		# there was no 'ranlib' in simulator DEVROOT, so I used the OSX one and worked
		export RANLIB="/usr/bin/ranlib"
		#export RANLIB="$(xcrun --sdk $SDK --find ranlib)"
	else
		export RANLIB="$(xcrun --sdk $SDK --find ranlib)"
	fi

	if [[ $1 == "iphonesimulator" ]]
	then
		export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv" # -miphoneos-version-min=7.0"
	else
		export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv"
	fi

	#export ARCH="armv7"
	export ARCH
	CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/"

	if [[ $1 != "iphonesimulator" ]]
	then
		CFLAGS=${CFLAGS}" -DIOS_BUILD"
	else
		CFLAGS=${CFLAGS}" -miphoneos-version-min=7.0"
	fi


	export CFLAGS
	#export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/"

	export CPPFLAGS="${CFLAGS}"
	export CXXFLAGS="${CFLAGS}"

	echo "--- Environment set:"
	echo "Using CC: $CC"
	echo "Using SDK: $SDK"
	echo "Using ARCH: $ARCH"
	echo "Using DEVROOT: $DEVROOT"
	echo "Using SDKROOT: $SDKROOT"
	echo "Using CFLAGS: $CFLAGS"
	echo "Using LDFLAGS: $LDFLAGS"
	echo "Using AR: $AR"
	echo "Using LD: $LD"
	echo "Using AS: $AS"
	echo "Using NM: $NM"
	echo "Using RANLIB: $RANLIB"


	echo "--- Configuring"
   ./configure --host=${ARCH}-apple-darwin
	#./configure --host=armv7-apple-darwin --prefix=/Users/Antonis/src-pkg/sofia-sip-$2-$1
   #./configure --host=x86_64-apple-darwin --prefix=/Users/Antonis/src-pkg/sofia-sip-$2-$1
   #./configure --host=i386-apple-darwin --prefix=/Users/Antonis/src-pkg/sofia-sip-$2-$1 --enable-shared=no --verbose


	echo "--- Building"
   #make SOFIA_SILENT=""   # verbose
   make 
	
	if [ $? -eq 0 ]
	then
		cp libsofia-sip-ua/.libs/libsofia-sip-ua.a build/libsofia-sip-ua-${ARCH}.a
	else 
		echo "--- Error building Sofia SIP"
		exit 1
	fi
   #cp "libmp3lame/.libs/libmp3lame.a" "build/libmp3lame-${PLATFORM}.a"
}

if [ ! -d "build" ] 
then
	mkdir build
fi
# i386 doesn't work 
#ARCH="i386"   
#SDK="iphonesimulator"
#build $SDK $ARCH

ARCH="x86_64"
SDK="iphonesimulator"
build $SDK $ARCH

ARCH="armv7"
SDK="iphoneos"
build $SDK $ARCH 

ARCH="armv7s"
SDK="iphoneos"
build $SDK $ARCH

echo "--- Creating universal library at build/"
lipo -create build/* -output build/libsofia-sip-ua.a
