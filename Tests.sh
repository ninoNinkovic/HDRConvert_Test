#!/bin/bash

set -x


# CTL Base
CTLBASE=$EDRHOME/ACES/CTL
# DPXEXR Tools (sigma_compare)
DPXEXR=$EDRHOME/Tools/demos/sc
# HDRConvert
HDRConvert=$EDRHOME/HDRConvert/trunk/bin

# Files
MARKET=$EDRDATA/EXR/Technicolor/Market3Clip4000/Market3Clip4000_1920x1080p_50_hf_709_00100.exr
BALLOON=$EDRDATA/EXR/Technicolor/BalloonClip4000/BalloonClip4000_1920x1080p_25_hf_709_00100.exr


NAMES=(MARKET BALLOON)


for NAME in ${NAMES[@]}; do

# Null convert
$HDRConvert/HDRConvert.exe -f $HDRConvert/HDRConvert.cfg \
  -p SourceFile=${!NAME}  \
  -p OutputFile=$NAME-null-HDRC.exr \
  -p NormalizationScale=1.0 \
  -p SourceColorPrimaries=0  `# 709` \
  -p OutputChromaFormat=3    `# 444`\
  -p OutputColorSpace=1      `# RGB`\
  -p OutputColorPrimaries=1  `# 2020`\
  -p TransferFunction=0      `# none`\
  -p NumberOfFrames=1
  
$HDRConvert/HDRConvert.exe -f $HDRConvert/HDRConvert.cfg \
  -p SourceFile=$NAME-null-HDRC.exr  \
  -p OutputFile=$NAME-null-HDRC2709.exr \
  -p NormalizationScale=1.0 \
  -p SourceColorPrimaries=1 `# 2020` \
  -p OutputChromaFormat=3    `# 444`\
  -p OutputColorSpace=1      `# RGB`\
  -p OutputColorPrimaries=0  `# 709`\
  -p TransferFunction=0      `# none`\
  -p NumberOfFrames=1  
  
# compare 2020 round trip from 709 to 709  
$DPXEXR/sigma_compare_PQ ${!NAME}  $NAME-null-HDRC2709.exr > CMP-$NAME-null_HDRConvert.log  
  

# Convert to 2020
$HDRConvert/HDRConvert.exe -f $HDRConvert/HDRConvert.cfg \
  -p SourceFile=${!NAME}  \
  -p OutputFile=$NAME-2020-HDRC.exr \
  -p NormalizationScale=1.0 \
  -p SourceColorPrimaries=0  `# 709` \
  -p OutputChromaFormat=3    `# 444`\
  -p OutputColorSpace=1      `# RGB`\
  -p OutputColorPrimaries=1  `# 2020`\
  -p TransferFunction=0      `# none`\
  -p NumberOfFrames=1

ctlrender -force -ctl $CTLBASE/709-2-2020.ctl -ctl $CTLBASE/nullA.ctl \
    -compression NONE \
    ${!NAME} \
    -format exr16 $NAME-2020-CTL.exr
    
# Compare CTL generated 2020 from HDRConvert    
$DPXEXR/sigma_compare_PQ $NAME-2020-CTL.exr  $NAME-2020-CTL.exr > SELF-2020-CTL.log  
$DPXEXR/sigma_compare_PQ $NAME-2020-HDRC.exr  $NAME-2020-HDRC.exr > SELF-2020-HDRConvert.log  
$DPXEXR/sigma_compare_PQ $NAME-2020-CTL.exr  $NAME-2020-HDRC.exr > CMP-$NAME-2020-CTL_vs_HDRConvert.log  


# Convert to PQ 2020
$HDRConvert/HDRConvert.exe -f $HDRConvert/HDRConvert.cfg \
  -p SourceFile=$NAME-2020-HDRC.exr  \
  -p OutputFile=$NAME-2020-HDRC-PQ.exr \
  -p NormalizationScale=10000.0 \
  -p SourceColorPrimaries=1  `# 2020` \
  -p OutputChromaFormat=3    `# 444`\
  -p OutputColorSpace=1      `# RGB`\
  -p OutputColorPrimaries=1  `# 2020`\
  -p TransferFunction=1      `# PQ`\
  -p NumberOfFrames=1

# Create "Video Range PQ"
ctlrender -force -ctl $CTLBASE/709-2-2020.ctl -ctl $CTLBASE/PQnk.ctl -ctl $CTLBASE/nullA.ctl\
    -compression NONE \
    ${!NAME} \
    -format exr16 $NAME-2020-CTL-PQ.exr
    

# Convert to tiff (need to squeeze PQ as EXR to Video Range)
ctlrender -force -ctl $CTLBASE/null.ctl -ctl $CTLBASE/Full-2-VideoRange.ctl \
   $NAME-2020-HDRC-PQ.exr -format tiff16 $NAME-2020-HDRC-PQ.tiff
   
ctlrender -force -ctl $CTLBASE/null.ctl \
      $NAME-2020-CTL-PQ.exr -format tiff16 $NAME-2020-CTL-PQ.tiff

# compare tiffs with video range PQs
$EDRHOME/Tools/tifcmp/tifcmp $NAME-2020-HDRC-PQ.tiff $NAME-2020-CTL-PQ.tiff B10 -o 127 -g 10

# Flip PQ back to EXR
ctlrender -force -ctl $CTLBASE/INVPQnk.ctl -ctl $CTLBASE/nullA.ctl\
    -compression NONE \
    $NAME-2020-HDRC-PQ.tiff \
    -format exr16 $NAME-2020-HDRC-PQ-Linear.exr
    
ctlrender -force -ctl $CTLBASE/INVPQnk.ctl -ctl $CTLBASE/nullA.ctl\
    -compression NONE \
    $NAME-2020-CTL-PQ.tiff \
    -format exr16 $NAME-2020-CTL-PQ-Linear.exr  
    
# compare PQ tiffs as Linear EXR    
$DPXEXR/sigma_compare_PQ $NAME-2020-CTL-PQ-Linear.exr  $NAME-2020-HDRC-PQ-Linear.exr > CMP-$NAME-2020-CTL_vs_HDRConvert-PQ-Linear.log  


# Implement YUV
# converts linear 2020 to video range yuv
#
$HDRConvert/HDRConvert.exe -f $HDRConvert/HDRConvert.cfg \
  -p SourceFile=$NAME-2020-HDRC.exr  \
  -p OutputFile=$NAME-2020-HDRC-PQ.yuv \
  -p NormalizationScale=10000.0 \
  -p SourceColorPrimaries=1  `# 2020` \
  -p OutputChromaFormat=1    `# 420`\
  -p OutputColorSpace=0      `# YUV`\
  -p OutputColorPrimaries=1  `# 2020`\
  -p TransferFunction=1      `# PQ`\
  -p NumberOfFrames=1

# yuv file that HDRConvert makes is video range
mkdir tifXYZ
rm -rfv tifHDRC
$EDRHOME/Tools/YUV/yuv2tif $NAME-2020-HDRC-PQ.yuv B10 HD1920 2020 -f 1
mv tifXYZ tifHDRC

# yuv for tif2yuv/yuv2tif starting from HDRConvert file input
mkdir tifXYZ
rm -rfv tifCTL
$EDRHOME/Tools/YUV/tif2yuv $NAME-2020-HDRC-PQ.tiff   B10 HD1920 2020 -o $NAME-2020-CTL-PQ.yuv     
$EDRHOME/Tools/YUV/yuv2tif $NAME-2020-CTL-PQ.yuv B10 HD1920 2020 -f 1
mv tifXYZ tifCTL

# flip recovered PQ tiff back to exr and compare
ctlrender -force -ctl $CTLBASE/INVPQnk.ctl -ctl $CTLBASE/nullA.ctl\
    -compression NONE \
    tifHDRC/XpYpZp000000.tif \
    -format exr16 $NAME-2020-HDRC-PQ-Linear-YUV.exr
    
ctlrender -force -ctl $CTLBASE/INVPQnk.ctl -ctl $CTLBASE/nullA.ctl\
    -compression NONE \
    tifCTL/XpYpZp000000.tif \
    -format exr16 $NAME-2020-CTL-PQ-Linear-YUV.exr 
    
# compare PQ tiffs as Linear EXR    
$DPXEXR/sigma_compare_PQ $NAME-2020-CTL-PQ-Linear-YUV.exr  $NAME-2020-HDRC-PQ-Linear-YUV.exr > CMP-$NAME-2020-CTL_vs_HDRConvert-PQ-Linear-YUV.log 


# Compare HDRConvert recovered 444 linear to source
$DPXEXR/sigma_compare_PQ $NAME-2020-HDRC.exr  $NAME-2020-HDRC-PQ-Linear-YUV.exr > CMP-$NAME-2020-Source_vs_HDRConvert-PQ-Linear-YUV.log 

# Compare tif2yuv/yuv2tif recovered 444 linear to source
$DPXEXR/sigma_compare_PQ $NAME-2020-HDRC.exr  $NAME-2020-CTL-PQ-Linear-YUV.exr > CMP-$NAME-2020-Source_vs_yuv2tif-PQ-Linear-YUV.log

# Compare on same plot
echo "#10k16b-HDRC" > CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log 
echo "#10k16b-HDRC" >> CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log
cat CMP-$NAME-2020-Source_vs_HDRConvert-PQ-Linear-YUV.log >> CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log

echo "#10k16b-YUV2TIF" >> CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log
echo "#10k16b-YUV2TIF" >> CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log
cat CMP-$NAME-2020-Source_vs_yuv2tif-PQ-Linear-YUV.log >> CMP-$NAME-2020-CTL_and_HDRConvert-YUV.log

done

exit


  
