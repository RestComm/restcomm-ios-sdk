#!/bin/bash
#
# Generate apple doc reference documentation, update & commit gh-pages branch and push gh-pages branch

echo "Checking out gh-pages"
git checkout gh-pages
echo "Rebasing gh-pages to master"
git rebase master
# Do the generation
echo "Generating appledoc documentation"
appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h
# Add and commit
echo "Adding changes to staging area and committing"
git add .
# Only commit if there are differences
git diff --quiet --exit-code --cached || git commit -m "Update gh-pages"
echo "Force-pushing gh-pages to origin"
git push -f origin gh-pages
echo "Done updating docs, checking out master"
git checkout master
