#!/bin/bash
#
# Build Olympus after updating version string and deploy

PLIST_BUDDY="/usr/libexec/PlistBuddy"
INFOPLIST_FILE="Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist"

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
# Create a custom keychain, $CUSTOM_KEYCHAIN (not much interested for password as it will be hosted an CI env and removed right after)
security create-keychain -p keychain_password $CUSTOM_KEYCHAIN

echo "-- Setting up $CUSTOM_KEYCHAIN as default"
# Make the $CUSTOM_KEYCHAIN default, so xcodebuild will use it for signing
security default-keychain -s $CUSTOM_KEYCHAIN

# Unlock the keychain
security unlock-keychain -p keychain_password $CUSTOM_KEYCHAIN

# Set keychain timeout to 1 hour for long builds
# see http://www.egeek.me/2013/02/23/jenkins-and-xcode-user-interaction-is-not-allowed/
security set-keychain-settings -t 3600 -l ~/Library/Keychains/$CUSTOM_KEYCHAIN

# Add certificates to keychain and allow codesign to access them
security import ./scripts/certs/${APPLE_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
# Development
security import ./scripts/certs/${DEVELOPMENT_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
security import ./scripts/certs/${DEVELOPMENT_KEY} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign

#security import ./scripts/certs/developer-appledev-cert.cer -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
#security import ./scripts/certs/developer-appledev-key.p12 -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign
# Distribution
security import ./scripts/certs/${DISTRIBUTION_CERT} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -T /usr/bin/codesign
security import ./scripts/certs/${DISTRIBUTION_KEY} -k ~/Library/Keychains/$CUSTOM_KEYCHAIN -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign

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


echo -e "-- Updating .plist version strings:\n\tCFBundleShortVersionString $BASE_VERSION\n\tCFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}"
# Set base version
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $BASE_VERSION" "$INFOPLIST_FILE"
# Set suffix
$PLIST_BUDDY -c "Set :CFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}" "$INFOPLIST_FILE"

echo "-- Building Olympus"
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY='iPhone Distribution' DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM PROVISIONING_PROFILE=$DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME PROVISIONING_PROFILE_SPECIFIER=''

# Build and sign with development certificate (cannot use distribution cert here!)
#xcodebuild archive \
#             -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace \
#             -scheme restcomm-olympus \
#             -configuration Enterprise \
#             -derivedDataPath ./build \
#             -archivePath ./build/Products/restcomm-olympus.xcarchive 
#CODE_SIGN_IDENTITY="iPhone Developer: Ivelin Ivanov (E3D845CWDU)" DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM 
#             -archivePath ./build/Products/restcomm-olympus.xcarchive CODE_SIGN_IDENTITY="iPhone Developer" DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM 
#PROVISIONING_PROFILE=$DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME

if [ ! -z "$TRAVIS" ]
then
	#travis_wait 60 xcodebuild archive  -project Examples/test-xcode8/test-xcode8.xcodeproj  -scheme test-xcode8  -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/test-xcode8.xcarchive 
	#travis_wait 60 xcodebuild archive  -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace  -scheme restcomm-olympus  -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/restcomm-olympus.xcarchive 
	xcodebuild archive -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/restcomm-olympus.xcarchive 
else
	#xcodebuild archive  -project Examples/test-xcode8/test-xcode8.xcodeproj  -scheme test-xcode8  -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/test-xcode8.xcarchive | xcpretty
	xcodebuild archive -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/restcomm-olympus.xcarchive
fi
#xcodebuild archive  -project Examples/test-xcode8/test-xcode8.xcodeproj  -scheme test-xcode8  -configuration Release  -derivedDataPath ./build  -archivePath ./build/Products/test-xcode8.xcarchive 

echo "-- Exporting Archive"
# Exporting and signing with distribution certificate
#xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA
if [ ! -z "$TRAVIS" ]
then
	#travis_wait 60 xcodebuild -exportArchive -archivePath ./build/Products/test-xcode8.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA
	#travis_wait 60 xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA
	xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA 
else
	# Use system rvm to avoid build error
	#rvm system
	#xcodebuild -exportArchive -archivePath ./build/Products/test-xcode8.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA
	xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA 
fi
#xcodebuild -exportArchive -archivePath ./build/Products/test-xcode8.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA

# From blog post
#set -o pipefail && xctool -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -sdk iphoneos -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO 'CODE_SIGN_RESOURCE_RULES_PATH=$(SDKROOT)/ResourceRules.plist'

# Sign App
#echo "-- Signing App"
#PROVISIONING_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision"
#OUTPUTDIR="$PWD/build/Release-iphoneos"
#xcrun -log -sdk iphoneos PackageApplication "$OUTPUTDIR/$APP_NAME.app" -o "$OUTPUTDIR/$APP_NAME.ipa" -sign "$DEVELOPER_NAME" -embed "$PROVISIONING_PROFILE"


# Clean up
echo "-- Cleaning up"

echo "-- Setting original keychain, \"$ORIGINAL_KEYCHAIN\", as default"
security default-keychain -s $ORIGINAL_KEYCHAIN

echo "-- Removing custom keychain $CUSTOM_KEYCHAIN"
security delete-keychain $CUSTOM_KEYCHAIN

echo "-- Removing keys, certs and profiles"
rm scripts/certs/${DEVELOPMENT_CERT} scripts/certs/${DEVELOPMENT_KEY} scripts/certs/${DISTRIBUTION_CERT} scripts/certs/${DISTRIBUTION_KEY} ~/Library/MobileDevice/Provisioning\ Profiles/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision ./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision ./scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision
