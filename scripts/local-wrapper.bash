#!/bin/bash
#
# Main script to be used for local builds (i.e. not Travis CI), that sets up the environment so that scripts designed for Travis CI can work locally,
# and we can do fast builds/testing/deployment even if Travis CI is not available (something that happens often, sadly)
#
# For local builds we need to have exported ENTERPRISE_DISTRIBUTION_KEY_PASSWORD and DEPLOY in the shell env

if [ ! -z "$TRAVIS" ]
then
	# if this is a travis build, no need to do anything, just continue with main script
	./scripts/main.bash
	echo "-- This is Travis CI build, no need to local setup"
	exit 0
fi

# For now using copies of same values once for travis and one for locally. When things clear up with can update accordingly
if [ ! -z "$TRAVIS" ]
then
	# Travis build
	export COMMIT_USERNAME="Travis CI"
	export COMMIT_AUTHOR_EMAIL="antonis.tsakiridis@telestax.com"
	export APP_NAME="restcomm-olympus"
	export DEVELOPER_NAME="iPhone Distribution: Telestax, Inc."
	export DEVELOPMENT_TEAM="H9PG74NSQT"
	export DEVELOPMENT_PROVISIONING_PROFILE_NAME="development"
	export DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME="development-olympus"
	export DISTRIBUTION_PROVISIONING_PROFILE_NAME="enterprise-distribution"
else
	export CD_BRANCH="develop"
	export BASE_VERSION="1.0.0"
	export VERSION_SUFFIX="beta.4.1"
	export COMMIT_USERNAME="Antonis Tsakiridis"
	export COMMIT_AUTHOR_EMAIL="antonis.tsakiridis@telestax.com"
	export APP_NAME="restcomm-olympus"
	export DEVELOPER_NAME="iPhone Distribution: Telestax, Inc."
	export DEVELOPMENT_TEAM="H9PG74NSQT"
	export DEVELOPMENT_PROVISIONING_PROFILE_NAME="development"
	export DEVELOPMENT_PROVISIONING_PROFILE_OLYMPUS_NAME="development-olympus"
	export DISTRIBUTION_PROVISIONING_PROFILE_NAME="enterprise-distribution"
	export DEPLOY="true"
fi

# Local build
#DEPLOY=true
#if [[ "$DEPLOY" == "true" ]]
#then
#fi
