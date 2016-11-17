#!/bin/bash
#
# Generate apple doc reference documentation, update & commit gh-pages branch and push gh-pages branch to GitHub

DOC_BRANCH="gh-pages"

echo "-- Checking out $DOC_BRANCH"
git checkout $DOC_BRANCH
if [ $? -ne 0 ]
then
	echo "-- Error: could not checkout: $DOC_BRANCH"
	exit 1	
fi

# Need to make absolutely sure that we are in gh-pages branch when rebasing! Rebasing can be nasty in master branch
CURRENT_BRANCH=`git branch | grep \* | cut -d ' ' -f2`
if [ $CURRENT_BRANCH != $DOC_BRANCH ] 
then
	echo "-- Error: Currently in wrong branch: $CURRENT_BRANCH instead of $DOC_BRANCH. Returning to master and bailing"
	git checkout master
	exit 1	
fi

echo "-- Rebasing $CURRENT_BRANCH to master"
git rebase master
if [ $? -ne 0 ]
then
	echo "-- Error: could not rebase $DOC_BRANCH to master. Returning to master and bailing"
	git checkout master
	exit 1	
fi

# Do the generation
echo "-- Generating appledoc documentation"
appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h

# Add and commit
echo "-- Adding changes to staging area and committing"
git add .

# Only commit if there are differences
git diff --quiet --exit-code --cached || git commit -m "Update $DOC_BRANCH"
if [ $? -eq 0 ]
then
	echo "-- Force pushing $DOC_BRANCH to origin"
	git push -f origin $DOC_BRANCH
fi

echo "-- Done updating docs, checking out master"
git checkout master
