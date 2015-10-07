#!/bin/bash
#
# Build sofia sip library for all architectures and combine all the libs to a universal library
#

function build()
{
	SDK=$1
	ARCH=$2

	echo "--- Building for: $SDK, $ARCH"

	# cleanup previous runs
	echo "--- Cleaning up"
   make distclean > /dev/null

	I386_FLAGS=""
	if [[ $ARCH == "i386" ]]
	then
		I386_FLAGS="-m32"
	fi

	export DEVROOT="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer"
	export SDKROOT="$(xcrun --sdk $SDK --show-sdk-path)"
	export CC="$(xcrun --sdk $SDK --find clang)"
	export CXX="$(xcrun --sdk $SDK --find clang++)"
	export LD="$(xcrun --sdk $SDK --find ld)"
	export AR="$(xcrun --sdk $SDK --find ar)"
	export AS="$(xcrun --sdk $SDK --find as)"
	export NM="$(xcrun --sdk $SDK --find nm)"
	export RANLIB="$(xcrun --sdk $SDK --find ranlib)"

	if [[ $SDK == "iphonesimulator" ]]
	then
		export LDFLAGS=${I386_FLAGS}" -L${SDKROOT}/usr/lib/ -lresolv" # -miphoneos-version-min=7.0"
	else
		export LDFLAGS="-L${SDKROOT}/usr/lib/ -lresolv"
	fi

	export ARCH
	CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/"
	# for debug
	#CFLAGS=${I386_FLAGS}" -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -I${SDKROOT}/usr/include/ -g -O0"

	if [[ $SDK != "iphonesimulator" ]]
	then
		CFLAGS=${CFLAGS}" -DIOS_BUILD"
	else
		CFLAGS=${CFLAGS}" -miphoneos-version-min=7.0"
	fi

	export CFLAGS
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
	if [[ $SDK != "iphonesimulator" ]]
	then 
		# arm64 doesn't work here, although armv7 adn armv7s do. But arm covers us for armv7 and armv7s as well
   	./configure --host=arm-apple-darwin
	else
   	./configure --host=${ARCH}-apple-darwin
	fi

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
}

if [ ! -d "build" ] 
then
	mkdir build
fi

# i386 doesn't work 
#ARCH="i386"   
#SDK="iphonesimulator"
#build $SDK $ARCH

#ARCH="x86_64"
#SDK="iphonesimulator"
#build $SDK $ARCH

ARCH="armv7"
SDK="iphoneos"
build $SDK $ARCH 

ARCH="armv7s"
SDK="iphoneos"
build $SDK $ARCH

ARCH="arm64"
SDK="iphoneos"
build $SDK $ARCH

echo "--- Creating universal library at build/"
rm -f build/libsofia-sip-ua.a
lipo -create build/* -output build/libsofia-sip-ua.a
