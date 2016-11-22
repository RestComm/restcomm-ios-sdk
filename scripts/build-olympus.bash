#!/bin/bash
#
# Build Olympus after updating version string and deploy

PLIST_BUDDY="/usr/libexec/PlistBuddy"
INFOPLIST_FILE="Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist"

echo "-- Install CocoaPod dependencies"
pod install --project-directory=Examples/restcomm-olympus

echo "-- Build Olympus"
set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0'

echo "-- Updating .plist version strings:\n\tCFBundleShortVersionString $BASE_VERSION\n\tCFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}"
# Set base version
$PLIST_BUDDY -c "Set :CFBundleShortVersionString $BASE_VERSION" "$INFOPLIST_FILE"
# Set suffix
$PLIST_BUDDY -c "Set :CFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}" "$INFOPLIST_FILE"

#echo "-- PlistBuddy"
#PlistBuddy
