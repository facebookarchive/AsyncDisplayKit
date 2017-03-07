#!/usr/bin/env bash
set -eo pipefail

UPDATE_STATUS_PATH=$1
BUILDKITE_PULL_REQUEST=$2
BUILDKITE_BUILD_URL=$3

function updateStatus() {
  if [ "${BUILDKITE_PULL_REQUEST}" != "false" ] ; then
    ${UPDATE_STATUS_PATH} "TextureGroup" "Texture" ${BUILDKITE_PULL_REQUEST} "$1" ${BUILDKITE_BUILD_URL} "$2" "CI/Pinterest" "$3"
  fi
}

if [[ -z "${UPDATE_STATUS_PATH}" || -z "${BUILDKITE_PULL_REQUEST}" || -z "${BUILDKITE_BUILD_URL}" ]] ; then
    echo "Update status path (${UPDATE_STATUS_PATH}), pull request (${BUILDKITE_BUILD_URL}) or build url (${BUILDKITE_PULL_REQUEST}) unset."
    trap - EXIT
    exit 255
fi

trapped="false"
function trap_handler() {
    if [[ "$trapped" = "false" ]]; then
        updateStatus "failure" "Tests failed…" `pwd`/log.txt
        echo "Tests failed, updated status to failure"
        rm `pwd`/log.txt
    fi
    trapped="true"
}
trap trap_handler INT TERM EXIT

updateStatus "pending" "Starting build…"

./build.sh all 2>&1|tee `pwd`/log.txt

rm `pwd`/log.txt

updateStatus "success" "Tests passed"

echo "All tests succeeded, updated status to success"
trap - EXIT
exit 0