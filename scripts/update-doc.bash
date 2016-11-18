#!/bin/bash
#
# Generate apple doc reference documentation, update & commit gh-pages branch and push gh-pages branch to GitHub

DOC_BRANCH="gh-pages"

echo "-- Checking out $DOC_BRANCH as orphan"
git checkout --orphan $DOC_BRANCH
if [ $? -ne 0 ]
then
	echo "-- Error: could not checkout: $DOC_BRANCH"
	exit 1	
fi

# Need to make absolutely sure that we are in gh-pages before doing anything else
CURRENT_BRANCH=`git branch | grep \* | cut -d ' ' -f2`
echo "-- Current branch is: $CURRENT_BRANCH"
if [ "$CURRENT_BRANCH" != "$DOC_BRANCH" ] 
then
	echo "-- Error: Currently in wrong branch: $CURRENT_BRANCH instead of $DOC_BRANCH. Returning to master and bailing"
	git checkout master
	exit 1	
fi

# When the orphan branch is created all files are staged automatically, so we need to remove them from staging area and leave them to working dir
git rm --cached -r . > /dev/null
#echo "-- Rebasing $CURRENT_BRANCH to master"
#git rebase master
#if [ $? -ne 0 ]
#then
#	echo "-- Error: could not rebase $DOC_BRANCH to master. Returning to master and bailing"
#	git checkout master
#	exit 1	
#fi

# Do the generation
echo "-- Generating appledoc documentation"
appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h

# Add generated doc to staging area
echo "-- Adding changes to staging area and committing"
git add doc/

# Commit
git commit -m "Update $DOC_BRANCH"
if [ $? -eq 0 ]
then
	echo "-- Force pushing $DOC_BRANCH to origin"
	git push -f origin $DOC_BRANCH
fi

# Removing non staged changes from gh-pages, so that we can go back to master without issues
echo "-- Removing non staged changes from $DOC_BRANCH"
git clean -fd

# Debug command to verify everything is in order
git status

echo "-- Done updating docs, checking out master"
git checkout master
