#!/bin/bash
#
# Generate apple doc reference documentation and update gh-pages branch

git checkout gh-pages
git rebase master
appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h
git commit -m "Update gh-pages"
git push origin gh-pages
