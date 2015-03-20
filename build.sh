#!/bin/bash

# **** Update me when new Xcode versions are released! ****
PLATFORM="platform=iOS Simulator,OS=8.1,name=iPhone 6"
SDK="iphonesimulator8.1"


# It is pitch black.
set -e
function trap_handler() {
    echo -e "\n\nOh no! You walked directly into the slavering fangs of a lurking grue!"
    echo "**** You have died ****"
    exit 255
}
trap trap_handler INT TERM EXIT


MODE="$1"

if [ "$MODE" = "tests" ]; then
    echo "Building & testing AsyncDisplayKit."
    pod install
    xctool \
        -workspace AsyncDisplayKit.xcworkspace \
        -scheme AsyncDisplayKit \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build test
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."

    for example in examples/*/; do
        echo "Building $example."
        pod install --project-directory=$example
        xctool \
            -workspace "${example}Sample.xcworkspace" \
            -scheme Sample \
            -sdk "$SDK" \
            -destination "$PLATFORM" \
            build
    done
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "life-without-cocoapods" ]; then
    echo "Verifying that AsyncDisplayKit functions as a static library."

    xctool \
        -workspace "smoke-tests/Life Without CocoaPods/Life Without CocoaPods.xcworkspace" \
        -scheme "Life Without CocoaPods" \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build
    trap - EXIT
    exit 0
fi

echo "Unrecognised mode '$MODE'."
