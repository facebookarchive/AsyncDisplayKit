#!/bin/sh
set -e

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
    ../AsyncDisplayKit/*.h

mv appledoc/html htdocs/appledoc

rmdir appledoc
