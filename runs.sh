#!/bin/bash

set -x

rm -fv *.log *.tiff *.exr *.jpg *.png *.data *.yuv
ls -lt



./Tests.sh   $maxRange
./plot.sh    $maxRange



for frame in *tiff
do
convert $frame -quality 90 ${frame%tiff}jpg
rm -fv $frame
done


rm -rf *.exr


exit


