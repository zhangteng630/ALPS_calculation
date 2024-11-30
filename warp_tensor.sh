#!/bin/bash

# Inputs
template='./tensor_template.nii.gz'
mask='./mask.nii.gz'

inputPrefix=$1
outputDir=$2

sub="${inputPrefix##*/}"
    
if [ ! -d $outputDir ]; then
    mkdir -p $outputDir
fi

# Copy FSL preprocessing result and reconstruct DTI-TK tensor.
cp "$inputPrefix"_L1.nii.gz "$outputDir"
cp "$inputPrefix"_L2.nii.gz "$outputDir"
cp "$inputPrefix"_L3.nii.gz "$outputDir"
cp "$inputPrefix"_V1.nii.gz "$outputDir"
cp "$inputPrefix"_V2.nii.gz "$outputDir"
cp "$inputPrefix"_V3.nii.gz "$outputDir"
TVFromEigenSystem -basename "$outputDir/$sub" -type FSL
    
# Convert the diffusivity unit to DTITK compatible one
TVtool -in "$outputDir/$sub.nii.gz" -scale 1000 -out "$outputDir/$sub.nii.gz"
    
# Remove outliers.
echo "Remove outliers"
TVtool -in "$outputDir/$sub.nii.gz" -norm
BinaryThresholdImageFilter "$outputDir/$sub"_norm.nii.gz "$outputDir/$sub"_non_outliers.nii.gz 0 100 1 0
TVtool -in "$outputDir/$sub.nii.gz" -mask "$outputDir/$sub"_non_outliers.nii.gz -out "$outputDir/$sub.nii.gz"
    
# Convert to SPD
TVtool -in "$outputDir/$sub.nii.gz" -spd -out "$outputDir/$sub.nii.gz"
    
# Change origin.    
echo "Change image origin to [0,0,0]"
TVAdjustVoxelspace -in "$outputDir/$sub.nii.gz" -origin 0 0 0
    
# Affine registration.
echo "Affine registration."
dti_affine_reg $template "$outputDir/$sub.nii.gz" EDS 4 4 4 0.01
    
# Deformable registration.
echo "Deformable registration."
dti_diffeomorphic_reg $template "$outputDir/$sub"_aff.nii.gz $mask 1 6 0.002
    
# Combine affine and displacement, and warp to template space with spacing = [1,1,1].
echo "Warp to template."
dfRightComposeAffine -aff "$outputDir/$sub.aff" -df "$outputDir/$sub"_aff_diffeo.df.nii.gz -out "$outputDir/$sub"_combined.df.nii.gz
deformationSymTensor3DVolume -in "$outputDir/$sub.nii.gz" -target $template -trans "$outputDir/$sub"_combined.df.nii.gz -out "$outputDir/$sub"_diffeo.nii.gz -vsize 1 1 1
dti_warp_to_template "$outputDir/$sub.nii.gz" $template 1 1 1

# Compute colored-RGB for visualization.
TVtool -in "$outputDir/$sub"_diffeo.nii.gz -rgb

