#!/bin/bash -l
#SBATCH -A {UserPartition}   
#SBATCH -J BAKTA_ANN        
#SBATCH -t 04:00:00 (One genome takes 10-15 minutes)           
#SBATCH -N 1 (typically 1 node is enough. since it is > 100 cores on PDC)                    
#SBATCH --mem=200GB (Might need to be adjusted if error reports segfault etc.)               
#SBATCH -p main                   
#SBATCH --ntasks-per-node=1       
#SBATCH --output=/cfs/klemming/projects/supr/{UserPartition}/{Project}/logs/BAKTA_%j.out  # Standard output
#SBATCH --error=/cfs/klemming/projects/supr/{UserPartition}/{Project}/logs/BAKTA_%j.err   # Standard error

# Load necessary modules (can only load singularity after loading PDC)
ml PDC/23.12
ml singularity/4.1.1-cpeGNU-23.12

# Define paths to script and container
SINGULARITY_CONTAINER="/cfs/klemming/projects/supr/{UserPartition}/{Project}/BAKTA_parallel"
EXECUTABLE_SCRIPT="/mnt/data/projects/supr/{UserPartition}/{Project}/BAKTA_ann_GNU.sh"

# Execute script within singularity environment (Set to 10 parallel jobs and no file selection), bind mount all of /cfs/klemming (with permission) to /mnt/data
srun singularity exec -B /cfs/klemming:/mnt/data $SINGULARITY_CONTAINER bash $EXECUTABLE_SCRIPT 10 "NO"
