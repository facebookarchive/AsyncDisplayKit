#!/bin/sh
diff "${PODS_ROOT}/../Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
if [[ $? != 0 ]] ; then
    cat << EOM
error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
EOM
    exit 1
fi

