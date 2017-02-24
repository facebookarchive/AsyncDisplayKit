#!/bin/bash

PLATFORM="platform=iOS Simulator,name=iPhone 7"
SDK="iphonesimulator"
DERIVED_DATA_PATH="~/ASDKDerivedData"


# It is pitch black.
set -e
function trap_handler {
    echo -e "\n\nOh no! You walked directly into the slavering fangs of a lurking grue!"
    echo "**** You have died ****"
    exit 255
}
trap trap_handler INT TERM EXIT

# Derived data handling
eval [ ! -d $DERIVED_DATA_PATH ] && eval mkdir $DERIVED_DATA_PATH
function clean_derived_data {
    eval find $DERIVED_DATA_PATH -mindepth 1 -delete
}

# Build example
function build_example {
    example="$1"

    clean_derived_data
    
    if [ -f "${example}/Podfile" ]; then
        echo "Using CocoaPods"
        if [ -f "${example}/Podfile.lock" ]; then
            rm "$example/Podfile.lock"
        fi
        rm -rf "$example/Pods"
        pod install --project-directory=$example

        set -o pipefail && xcodebuild \
            -workspace "${example}/Sample.xcworkspace" \
            -scheme Sample \
            -sdk "$SDK" \
            -destination "$PLATFORM" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            build | xcpretty $FORMATTER
    elif [ -f "${example}/Cartfile" ]; then
        echo "Using Carthage"
        local_repo=`pwd`
        current_branch=`git rev-parse --abbrev-ref HEAD`
        cd $example

        echo "git \"file://${local_repo}\" \"${current_branch}\"" > "Cartfile"
        carthage update --platform iOS

        set -o pipefail && xcodebuild \
            -project "Sample.xcodeproj" \
            -scheme Sample \
            -sdk "$SDK" \
            -destination "$PLATFORM" \
            build | xcpretty $FORMATTER

        cd ../..
    fi
}

MODE="$1"

if type xcpretty-travis-formatter &> /dev/null; then
    FORMATTER="-f $(xcpretty-travis-formatter)"
  else
    FORMATTER="-s"
fi

if [ "$MODE" = "tests" ]; then
    echo "Building & testing AsyncDisplayKit."
    pod install
    set -o pipefail && xcodebuild \
        -workspace AsyncDisplayKit.xcworkspace \
        -scheme AsyncDisplayKit \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build-for-testing test | xcpretty $FORMATTER
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "tests_listkit" ]; then
    echo "Building & testing AsyncDisplayKit+IGListKit."
    pod install --project-directory=ASDKListKit
    set -o pipefail && xcodebuild \
        -workspace ASDKListKit/ASDKListKit.xcworkspace \
        -scheme ASDKListKitTests \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build-for-testing test | xcpretty $FORMATTER
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    for example in examples/*/; do
        echo "Building (examples) $example."

        build_example $example
    done
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples-pt1" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -6 | head); do
        echo "Building (examples-pt1) $example."

        build_example $example
    done
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples-pt2" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -12 | tail -6 | head); do
        echo "Building $example (examples-pt2)."

        build_example $example
    done
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples-pt3" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -7 | head); do
        echo "Building $example (examples-pt3)."

        build_example $example
    done
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "examples-extra" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    for example in $((find ./examples_extra -type d -maxdepth 1 \( ! -iname ".*" \)) | head -7 | head); do
        echo "Building $example (examples-extra)."

        build_example $example
    done
    trap - EXIT
    exit 0
fi

# Support building a specific example: sh build.sh example examples/ASDKLayoutTransition
if [ "$MODE" = "example" ]; then
    echo "Verifying that all AsyncDisplayKit examples compile."
    #Update cocoapods repo
    pod repo update master

    build_example $2
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "life-without-cocoapods" ]; then
    echo "Verifying that AsyncDisplayKit functions as a static library."

    set -o pipefail && xcodebuild \
        -workspace "smoke-tests/Life Without CocoaPods/Life Without CocoaPods.xcworkspace" \
        -scheme "Life Without CocoaPods" \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build | xcpretty $FORMATTER
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "framework" ]; then
    echo "Verifying that AsyncDisplayKit functions as a dynamic framework (for Swift/Carthage users)."

    set -o pipefail && xcodebuild \
        -project "smoke-tests/Framework/Sample.xcodeproj" \
        -scheme Sample \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build | xcpretty $FORMATTER
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "cocoapods-lint" ]; then
    echo "Verifying that podspec lints."

    set -o pipefail && pod env && pod lib lint
    trap - EXIT
    exit 0
fi

if [ "$MODE" = "carthage" ]; then
    echo "Verifying carthage works."
    
    set -o pipefail && carthage update && carthage build --no-skip-current
fi

echo "Unrecognised mode '$MODE'."
