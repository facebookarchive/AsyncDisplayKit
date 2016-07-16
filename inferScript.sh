#!/bin/sh

if ! [ -x "$(command -v infer)" ]; then
    echo "infer not found"
    echo "Install infer with homebrew: brew install infer"
else
    infer --continue --reactive -- xcodebuild build -workspace AsyncDisplayKit.xcworkspace -scheme "AsyncDisplayKit-iOS" -configuration Debug -sdk iphonesimulator9.3
fi
