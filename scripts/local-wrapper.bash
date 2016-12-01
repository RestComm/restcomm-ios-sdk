#!/bin/bash
#
# Main script to be used for local builds (i.e. not Travis CI), that sets up the environment so that scripts designed for Travis CI can work locally,
# and we can do fast builds/testing/deployment even if Travis CI is not available (something that happens often, sadly)
#
# For local builds we need to have exported ENTERPRISE_DISTRIBUTION_KEY_PASSWORD and DEPLOY in the shell env

#if [ ! -z "$TRAVIS" ]
#then
#	# if this is a travis build, no need to do anything, just continue with main script
#	echo "-- This is Travis CI build, no need to local setup"
#	exit 0
#fi

# Common to local and travis builds
export COMMIT_AUTHOR_EMAIL="antonis.tsakiridis@telestax.com"
export APP_NAME="restcomm-olympus"
export DEVELOPER_NAME="iPhone Distribution: Telestax, Inc."
export DEVELOPMENT_TEAM="H9PG74NSQT"
#export DEVELOPMENT_PROVISIONING_PROFILE_NAME="development"

export APPLE_CERT="AppleWWDRCA.cer"
export DEVELOPMENT_CERT="developer-cert.cer"
export DEVELOPMENT_KEY="developer-key.p12"
export DISTRIBUTION_CERT="enterprise-distribution-cert.cer"
export DISTRIBUTION_KEY="enterprise-distribution-key.p12"
export DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME="profile-development-olympus"
export DISTRIBUTION_PROVISIONING_PROFILE_OLYMPUS_NAME="profile-distribution-olympus"
export CUSTOM_KEYCHAIN="ios-build.keychain"

if [ ! -z "$TRAVIS" ]
then
	# Travis build
	export COMMIT_USERNAME="Travis CI"
else
	# Local build
	export CD_BRANCH="develop"
	export BASE_VERSION="1.0.0"
	export VERSION_SUFFIX="beta.4.1"
	export COMMIT_USERNAME="Antonis Tsakiridis"
	export DEPLOY="true"
fi

# Local build
#DEPLOY=true
#if [[ "$DEPLOY" == "true" ]]
#then
#fi

./scripts/main.bash
