#!/bin/bash
#
# Generate apple doc reference documentation

appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h
