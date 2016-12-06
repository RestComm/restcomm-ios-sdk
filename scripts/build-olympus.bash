#!/bin/bash
#
# Build Olympus after updating version string and deploy

PLIST_BUDDY="/usr/libexec/PlistBuddy"
INFOPLIST_FILE="Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist"
# Various files that we edit
SDK_COMMON_HEADER=RestCommClient/Classes/common.h
OLYMPUS_UTILS=Examples/restcomm-olympus/restcomm-olympus/Utils.m
OLYMPUS_PLIST=Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist

echo "-- Installing CocoaPod dependencies"
# TODO: add this back when we 're done
pod install --project-directory=Examples/restcomm-olympus

# For starters lets only create keychains in travis, since locally everything is setup already. But ultimately, we should create a separate new keychain locally to so that we can test that better
echo "-- TRAVIS: $TRAVIS"

# Decrypting certs and profiles (not sure if profiles actually need to be encrypted, but this is how others did it so I'm following the same route just to be on the safe side)
echo "-- Setting up signing"
echo "-- Decrypting keys, etc"
# Development
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/${DEVELOPMENT_CERT}.enc -d -a -out scripts/certs/${DEVELOPMENT_CERT}
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/${DEVELOPMENT_KEY}.enc -d -a -out scripts/certs/${DEVELOPMENT_KEY}

#openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-appledev-cert.cer.enc -d -a -out scripts/certs/developer-appledev-cert.cer
#openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-appledev-key.p12.enc -d -a -out scripts/certs/developer-appledev-key.p12

# Wildcard provisioning profile
#openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_NAME}.mobileprovision
# Olympus provisioning profile
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision

# Distribution
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/${DISTRIBUTION_CERT}.enc -d -a -out scripts/certs/${DISTRIBUTION_CERT}
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/${DISTRIBUTION_KEY}.enc -d -a -out scripts/certs/${DISTRIBUTION_KEY}

openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision

echo "-- Setting up keychain"
ORIGINAL_KEYCHAIN=`security default-keychain | rev | cut -d '/' -f -1 | sed 's/\"//' | rev`
echo "-- Original keychain: \"$ORIGINAL_KEYCHAIN\""
if [[ "$ORIGINAL_KEYCHAIN" == "$CUSTOM_KEYCHAIN" ]]
then
		echo "-- Custom keychain already set as default, bailing out to avoid issues."
		exit 1
fi

echo "-- Creating custom keychain for signing: \"$CUSTOM_KEYCHAIN\""
# Create a custom keychain, $CUSTOM_KEYCHAIN using passwordk $CUSTOM_KEYCHAIN_PASSWORD
security create-keychain -p $CUSTOM_KEYCHAIN_PASSWORD $CUSTOM_KEYCHAIN

echo "-- Setting up $CUSTOM_KEYCHAIN as default"
# Make the $CUSTOM_KEYCHAIN default, so xcodebuild will use it for signing
security default-keychain -s $CUSTOM_KEYCHAIN

# Unlock the keychain
security unlock-keychain -p $CUSTOM_KEYCHAIN_PASSWORD $CUSTOM_KEYCHAIN

# Set keychain timeout to 1 hour for long builds
# see http://www.egeek.me/2013/02/23/jenkins-and-xcode-user-interaction-is-not-allowed/
security set-keychain-settings -t 3600 -l ~/Library/Keychains/$CUSTOM_KEYCHAIN

# Add certificates to keychain and allow codesign to access them
security import ./scripts/certs/${APPLE_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
# Development
security import ./scripts/certs/${DEVELOPMENT_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
security import ./scripts/certs/${DEVELOPMENT_KEY} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign -A

#security import ./scripts/certs/developer-appledev-cert.cer -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
#security import ./scripts/certs/developer-appledev-key.p12 -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign
# Distribution
security import ./scripts/certs/${DISTRIBUTION_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
security import ./scripts/certs/${DISTRIBUTION_KEY} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign -A

echo "Installing provisioning profiles, so that XCode can find them"
#echo "Checking scripts"
#find scripts
# Put the provisioning profile in the right place so that they are picked up by Xcode
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
#cp "./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
cp "./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
cp "./scripts/provisioning-profile/$DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
#cp "./scripts/provisioning-profile/provisioningprofilemanualdevelopment3.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/4a55a44a-c058-45d0-accd-f06b6b0b72fa.mobileprovision

echo "-- Checking provisioning profiles"
#find scripts
ls -al ~/Library/MobileDevice/Provisioning\ Profiles/
echo "Checking signing identities: "
security find-identity -p codesigning -v


if [ ! -z "$TRAVIS" ]
then
	# Travis
	BUNDLE_VERSION="${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}"
else
	# Local, let's use the commit hash for now
	BUNDLE_VERSION="${VERSION_SUFFIX}+${COMMIT_SHA1}"
fi
echo -e "-- Updating .plist version strings:\n\tCFBundleShortVersionString $BASE_VERSION\n\tCFBundleVersion ${BUNDLE_VERSION}"
# Set base version
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $BASE_VERSION" "$INFOPLIST_FILE"
$PLIST_BUDDY -c "Set :CFBundleVersion ${BUNDLE_VERSION}" "$INFOPLIST_FILE"
# Set suffix

# Update build string in sources if needed
echo "-- Updating Sofia SIP User Agent with version"
if [ ! -f $SDK_COMMON_HEADER ]; then
	echo "$SDK_COMMON_HEADER not found, bailing"
	exit 1;
fi
sed -i '' "s/#BASE_VERSION/$BASE_VERSION/" $SDK_COMMON_HEADER 
sed -i '' "s/#VERSION_SUFFIX/$VERSION_SUFFIX/" $SDK_COMMON_HEADER 
if [ ! -z "$TRAVIS" ]
then
	sed -i '' "s/#BUILD/$TRAVIS_BUILD_NUMBER/" $SDK_COMMON_HEADER
else
	sed -i '' "s/#BUILD/$COMMIT_SHA1/" $SDK_COMMON_HEADER
fi

if [ ! -f $OLYMPUS_UTILS ]; then
	echo "$OLYMPUS_UTILS not found, bailing"
	exit 1;
fi
sed -i '' "s/#GIT-HASH/$COMMIT_SHA1/" $OLYMPUS_UTILS 

# Build and sign with development certificate (cannot use distribution cert here!)
echo "-- Building Olympus"
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY='iPhone Distribution' DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM PROVISIONING_PROFILE=$DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME PROVISIONING_PROFILE_SPECIFIER=''

if [ ! -z "$TRAVIS" ]
then
	#travis_wait 60 ...
	xcodebuild archive -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/restcomm-olympus.xcarchive 
else
	xcodebuild archive -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/restcomm-olympus.xcarchive # | xcpretty
fi

# Exporting and signing with distribution certificate
echo "-- Exporting Archive"
if [ ! -z "$TRAVIS" ]
then
	#travis_wait 60 ...
	xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA 
else
	# IMPORTANT: Use system rvm to avoid build error
	#rvm system
	xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA | xcpretty
fi

echo "-- Uploading to TestFairy"
#./scripts/testfairy-uploader.sh /Users/antonis/Documents/telestax/code/restcomm-ios-sdk/build/Products/IPA/restcomm-olympus.ipa 


# Clean up
echo "-- Cleaning up"

echo "-- Edited source files to discard version strings: $SDK_COMMON_HEADER, $OLYMPUS_UTILS, $OLYMPUS_PLIST"
git checkout -- $SDK_COMMON_HEADER $OLYMPUS_UTILS $OLYMPUS_PLIST

echo "-- Setting original keychain, \"$ORIGINAL_KEYCHAIN\", as default"
security default-keychain -s $ORIGINAL_KEYCHAIN

echo "-- Removing custom keychain $CUSTOM_KEYCHAIN"
security delete-keychain $CUSTOM_KEYCHAIN

echo "-- Removing keys, certs and profiles"
rm scripts/certs/${DEVELOPMENT_CERT} scripts/certs/${DEVELOPMENT_KEY} scripts/certs/${DISTRIBUTION_CERT} scripts/certs/${DISTRIBUTION_KEY} ~/Library/MobileDevice/Provisioning\ Profiles/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision ./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision ./scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision
