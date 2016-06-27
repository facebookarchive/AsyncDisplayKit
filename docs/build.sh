#!/bin/sh
set -e

HEADERS=`ls ../AsyncDisplayKit/*.h ../AsyncDisplayKit/Details/ASRangeController.h ../AsyncDisplayKit/Layout/*.h`

rm -rf htdocs appledoc

jekyll build --destination htdocs

appledoc \
    --no-create-docset \
    --create-html \
    --exit-threshold 2 \
    --no-repeat-first-par \
    --no-merge-categories \
    --explicit-crossref \
    --warn-missing-output-path \
    --warn-missing-company-id \
    --warn-undocumented-object \
    --warn-undocumented-member \
    --warn-empty-description \
    --warn-unknown-directive \
    --warn-invalid-crossref \
    --warn-missing-arg \
    --project-name AsyncDisplayKit \
    --project-company Facebook \
    --company-id "com.facebook" \
    --output appledoc \
    $HEADERS

mv appledoc/html htdocs/appledoc

rmdir appledoc
