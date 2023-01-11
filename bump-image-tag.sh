#!/bin/bash

OLD_BUILD_NUM=$(head -1 image_build_num.txt | tr -d '\n') 
NEW_BUILD_VALUE=`expr $OLD_BUILD_NUM + 1`
NEW_BUILD_NUM=$(printf "%03d" $NEW_BUILD_VALUE)
echo "$NEW_BUILD_NUM" > image_build_num.txt
git add image_build_num.txt
