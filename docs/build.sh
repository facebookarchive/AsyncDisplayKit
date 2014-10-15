#!/bin/sh
set -e

HEADERS=`ls ../AsyncDisplayKit/*.h | grep -v Subclasses`

rm -rf htdocs appledoc

jekyll build --destination htdocs

appledoc \
    --no-create-docset \
    --create-html \
    --exit-threshold 2 \
    --no-repeat-first-par \
    --project-name AsyncDisplayKit \
    --project-company Facebook \
    --company-id "com.facebook" \
    --output appledoc \
    $HEADERS

mv appledoc/html htdocs/appledoc

rmdir appledoc
