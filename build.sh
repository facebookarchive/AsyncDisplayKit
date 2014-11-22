#!/bin/sh
xctool \
    -workspace AsyncDisplayKit.xcworkspace \
    -scheme AsyncDisplayKit \
    -sdk iphonesimulator8.1 \
    -destination "platform=iOS Simulator,OS=${1},name=iPhone 5" \
    build test
