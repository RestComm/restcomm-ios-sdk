#!/bin/bash
#
# Build Olympus after updating version string and deploy

PLIST_BUDDY="/usr/libexec/PlistBuddy"
INFOPLIST_FILE="Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist"

echo "-- Installing CocoaPod dependencies"
pod install --project-directory=Examples/restcomm-olympus

# Decrypting certs
echo "-- Setting up signing"
# Development
# Wildcard provisioning profile
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_NAME}.mobileprovision
# Olympus provisioning profile
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME}.mobileprovision
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-cert.cer.enc -d -a -out scripts/certs/developer-cert.cer
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-key.p12.enc -d -a -out scripts/certs/developer-key.p12
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-appledev-cert.cer.enc -d -a -out scripts/certs/developer-appledev-cert.cer
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/developer-appledev-key.p12.enc -d -a -out scripts/certs/developer-appledev-key.p12
# Distribution
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_NAME}.mobileprovision.enc -d -a -out scripts/provisioning-profile/${DISTRIBUTION_PROVISIONING_PROFILE_NAME}.mobileprovision
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/enterprise-distribution-cert.cer.enc -d -a -out scripts/certs/enterprise-distribution-cert.cer
openssl aes-256-cbc -k "$ENTERPRISE_DISTRIBUTION_KEY_PASSWORD" -in scripts/certs/enterprise-distribution-key.p12.enc -d -a -out scripts/certs/enterprise-distribution-key.p12

# --------
# Create a custom keychain
security create-keychain -p travis ios-build.keychain

# Make the custom keychain default, so xcodebuild will use it for signing
security default-keychain -s ios-build.keychain

# Unlock the keychain
security unlock-keychain -p travis ios-build.keychain

# Set keychain timeout to 1 hour for long builds
# see http://www.egeek.me/2013/02/23/jenkins-and-xcode-user-interaction-is-not-allowed/
security set-keychain-settings -t 3600 -l ~/Library/Keychains/ios-build.keychain

# Add certificates to keychain and allow codesign to access them
security import ./scripts/certs/AppleWWDRCA.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
# Development
security import ./scripts/certs/developer-cert.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
security import ./scripts/certs/developer-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign
security import ./scripts/certs/developer-appledev-cert.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
security import ./scripts/certs/developer-appledev-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign
# Distribution
security import ./scripts/certs/enterprise-distribution-cert.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
security import ./scripts/certs/enterprise-distribution-key.p12 -k ~/Library/Keychains/ios-build.keychain -P $ENTERPRISE_DISTRIBUTION_KEY_PASSWORD -T /usr/bin/codesign

echo "Checking scripts"
find scripts
# Put the provisioning profile in the right place so that they are picked up by Xcode
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp "./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
cp "./scripts/provisioning-profile/$DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
cp "./scripts/provisioning-profile/$DISTRIBUTION_PROVISIONING_PROFILE_NAME.mobileprovision" ~/Library/MobileDevice/Provisioning\ Profiles/
echo "Checking provisioning profiles"
find scripts
ls -al ~/Library/MobileDevice/Provisioning\ Profiles/

echo "Signing identities: "
security find-identity -p codesigning -v
# --------


echo -e "-- Updating .plist version strings:\n\tCFBundleShortVersionString $BASE_VERSION\n\tCFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}"
# Set base version
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $BASE_VERSION" "$INFOPLIST_FILE"
# Set suffix
$PLIST_BUDDY -c "Set :CFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}" "$INFOPLIST_FILE"

echo "-- Building Olympus"
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS,name=iPhone SE,OS=10.0' | xcpretty
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO
#set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination generic/platform=iOS -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY='iPhone Distribution' DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM PROVISIONING_PROFILE=$DISTRIBUTION_PROVISIONING_PROFILE_NAME PROVISIONING_PROFILE_SPECIFIER=''

# Build and sign with development certificate (cannot use distribution cert here!)
#xcodebuild archive \
#             -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace \
#             -scheme restcomm-olympus \
#             -configuration Enterprise \
#             -derivedDataPath ./build \
#             -archivePath ./build/Products/restcomm-olympus.xcarchive 
#CODE_SIGN_IDENTITY="iPhone Developer: Ivelin Ivanov (E3D845CWDU)" DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM 
#             -archivePath ./build/Products/restcomm-olympus.xcarchive CODE_SIGN_IDENTITY="iPhone Developer" DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM 
#PROVISIONING_PROFILE=$DISTRIBUTION_PROVISIONING_PROFILE_NAME

xcodebuild archive \
             -project Examples/test-xcode8/test-xcode8.xcodeproj \
             -scheme test-xcode8 \
             -configuration Enterprise \
             -derivedDataPath ./build \
             -archivePath ./build/Products/test-xcode8.xcarchive 

echo "-- Exporting Archive"
# Exporting and signing with distribution certificate
#xcodebuild -exportArchive -archivePath ./build/Products/restcomm-olympus.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA
xcodebuild -exportArchive -archivePath ./build/Products/test-xcode8.xcarchive -exportOptionsPlist ./scripts/exportOptions-Enterprise.plist -exportPath ./build/Products/IPA

# From blog post
#set -o pipefail && xctool -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -sdk iphoneos -configuration Release OBJROOT=$PWD/build SYMROOT=$PWD/build ONLY_ACTIVE_ARCH=NO 'CODE_SIGN_RESOURCE_RULES_PATH=$(SDKROOT)/ResourceRules.plist'

# Sign App
#echo "-- Signing App"
#PROVISIONING_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$DISTRIBUTION_PROVISIONING_PROFILE_NAME.mobileprovision"
#OUTPUTDIR="$PWD/build/Release-iphoneos"
#xcrun -log -sdk iphoneos PackageApplication "$OUTPUTDIR/$APP_NAME.app" -o "$OUTPUTDIR/$APP_NAME.ipa" -sign "$DEVELOPER_NAME" -embed "$PROVISIONING_PROFILE"
