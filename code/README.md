# Image analysis using Mask - EBImage-based analysis with Kenneth's help

## directories
dir_code="/project2/gilad/joycehsiao/fucci-seq/code/"
dir_images_data="/project2/gilad/fucci-seq/images_curated"
dir_intensities="/project2/gilad/fucci-seq/intensities"
dir_scratch_images="/scratch/midway2/joycehsiao/fucci-seq/images_processed"
dir_images_combined="/project2/gilad/fucci-seq/images_combined"
dir_images_wellId="/project2/gilad/fucci-seq/images_wellid"
dir_intensities_stats"/project2/gilad/fucci-seq/images_intensities"
dir_data="/project2/gilad/joycehsiao/fucci-seq/data/"

### Step 1: Detecting edges of the nuclei
input: dir_images_data
output: dir_intensities
dir_code/
|-- submit-fucciMask.sh
|   |-- fucciMask.sbatch
|   |-- fucciMask.wrapper.R: for all 96 wells
|   |-- fucciMask.R: for ones single well

### Step 2: Combing cropped images from different
input: dir_scratch_images, dir_intensities, dir_images_wellId
output: dir_images_combined
dir_code/
|-- submit-fucciMask.combineImages.sh
|   |-- fucciMask.combineImages.sbatch
|   |-- fucciMask.combineImages.R

### Step 3: Make well labels in tiff
input: NULL
output: dir_images_wellId
dir_code/
|-- makeWellIdImages.R

### Step 4: Summarize intensity values
input: dir_intensities
output: dir_intensities_stats
dir_code/
|-- intensity.summarize.R: compute summary statistics
