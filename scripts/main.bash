#!/bin/bash
#
# Main script that will drive CI/CD actions, depending on type of commit

if [[ "$TRAVIS_PULL_REQUEST" == "true" ]]; then
	echo "-- This is a pull request, bailing out."
	exit 0
fi

# CD_BRANCH is the brach we are passing from the travis CI settings and shows which branch CI should deploy from
if [[ "$TRAVIS_BRANCH" != "$CD_BRANCH" ]]; then
	echo "-- Testing on a branch other than $CD_BRANCH, bailing out."
	exit 0
fi

echo "-- Processing main script."
git config credential.helper "store --file=.git/credentials"; echo "https://${GITHUB_OAUTH_TOKEN}:@github.com" > .git/credentials 2>/dev/null
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# SSH endpoint not needed any longer, since we 're using OAuth tokens with https, but let's leave it around in case we need it in the future
#export REPO=`git config remote.origin.url`
#export SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}

#echo "-- Will use ssh repo: $SSH_REPO"
#git remote -v


# Update reference documentation
#./scripts/update-doc.bash

# Build and deploy Olympus
./scripts/build-olympus.bash

# Update the pod
#- pod lib lint
