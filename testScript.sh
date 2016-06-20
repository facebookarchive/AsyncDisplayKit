#!/bin/bash


## ls is unsafe
#for file in $(ls -d */ | tail -4 | head -2)
#do
#echo $file
#done

n=4
#total_examples=(find . -type d -maxdepth 1 \( ! -iname ".*" \)) | wc -l
##examples_per_part = int(total_examples + n - 1) / n
#
echo $n
#echo $total_examples
#echo $examples_per_part

for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -6 | head)
do
echo "Building $example (examples-pt1)."
done

#for file in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -6)
#do
#echo $file
#done
#
#for file in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -12 | tail -6)
#do
#echo $file
#done
#
#for file in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | tail -8)
#do
#echo $file
#done
