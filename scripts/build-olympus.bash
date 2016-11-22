#!/bin/bash
#
# Build Olympus after updating version string and deploy

#PLIST_BUDDY="/usr/libexec/PlistBuddy"
INFOPLIST_FILE="Examples/restcomm-olympus/restcomm-olympus/restcomm-olympus-Info.plist"

echo "-- Build"
set -o pipefail && xcodebuild build -workspace Examples/restcomm-olympus/restcomm-olympus.xcworkspace -scheme restcomm-olympus -destination 'platform=iOS Simulator,name=iPhone SE,OS=10.0'

echo "-- /usr/libexec/PlistBuddy"
# Set base version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BASE_VERSION" "$INFOPLIST_FILE"
# Set suffix
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION_SUFFIX}+${TRAVIS_BUILD_NUMBER}" "$INFOPLIST_FILE"

echo "-- PlistBuddy"
PlistBuddy
