# BAKTA Parallel Annotation Pipeline

A set of scripts for high-throughput parallel BAKTA for HPC environments (Slurm workload manager).

## Overview

This pipeline facilitates the parallel annotation of multiple bacterial genomes using BAKTA, optimized for HPC environments. It includes:

- Automatic input file management
- Parallel processing with GNU Parallel
- Checkpoint system to resume interrupted jobs and prevent accidental running the same genome twice 
- HPC friendliness (expecting a SLURM-based system)

## Requirements

- Singularity/Apptainer (≥ 4.0)
- Singularity sandbox container with expanded BAKTA DB, BAKTA install and GNU Parallel
- Suitable computational enviroment: 
    - Slurm workload manager-based HPC enviroment (ex. PDC/Dardel)
    - PC with capable multicore processor and >32 GB RAM (Not tested extensively, but should work)
- Sufficient storage and computational resources

## Directory Structure

The pipeline expects the following directory structure:

```
# The expected file structure (Inside the mounted container space, example uses PDCs directory structure (supr))
/mnt/data/projects/supr/{UserPartition}/{Project}/
├── USER_FASTA_DIR/              # Contains input genome FASTA files (.fa)
├── USER_Ref.csv                 # Reference file with strain identifiers (optional)
└── BAKTA_ann_GNU.sh             # Main execution script

# Installed inside the singularity sandbox container
/opt/bakta_db/
└── db                           # BAKTA database directory

# Output, automatically piped back into host directory as job finishes 
/mnt/data/scratch/{UserInitial}/{Username}/
├── {Project}/BAKTA_OUTPUT/      # Output directory 
└── BAKTA_TMP/                   # Temporary working directory
```

## Configuration

Before running the pipeline, modify the following parameters in the scripts:

1. In `BAKTA_ann_GNU.sh`:
   - `FASTA_DIR`: Path to input FASTA files
   - `REF_FILE`: Path to the CSV reference file for strain selection
   - `DB_PATH`: Path to BAKTA database
   - `OUTPUT_DIR`: Path for annotation results
   - `TMP_DIR`: Path for temporary files (The dir used during the run, by default made and deleted from scratch)
   - Adjust the `--genus` parameter in the BAKTA command to whatever genus youre working with 

2. In `jobscript_BAKTA_parallel.sh`:
   - Update Slurm parameters (account, time, memory) based on your needs
   - Update paths to the Singularity container and executable script

## Usage

### Running the Pipeline

0. *Set up singularity container (if you dont already have a suitable sandbox)*:
   - Make sure that you have a suitable bakta.sif singularity image file
      - It can be retrieved using the dockerimage retained by the developers: 
         ```bash
         singularity build bakta_latest.sif docker://oschwengers/bakta:latest
         ```
   - Run the prepare_bakta_sandbox.sh script (make sure it has x-privileges) with sudo permissions
      - ex. Run: 
         ```bash
         sudo ./prepare_bakta_sandbox.sh -s ./bakta.sif -o ./bakta_sandbox
         ```
   - Make sure that the std.out prints a version for each tool in the container

1. **Set up your environment**:
   - Ensure all paths in the scripts are correctly configured
   - Prepare your input FASTA files (.fa) in the designated directory
   - Alter the jobscript and runscript as needed for this run

   (TIP)
   Typically i make a copy of the script and jobscript in a new directory for every new project, good for archiving previous runs and keeping hardcoded changes

2. **Submit the job to Slurm**:
   ```bash
   sbatch jobscript_BAKTA_parallel.sh
   ```

### Script Parameters

The `BAKTA_ann_GNU.sh` script accepts two optional parameters:

1. `MAX_PARALLEL_JOBS` (default: 2)
   - Number of parallel BAKTA processes to run
   - Example: `10` would run 10 genomes concurrently using 5 cores each (needs 50 cores alloted by the HPC)

2. `MakeTEMPdir` (default: "YES")
   - "YES": Selectively process genomes listed in the reference CSV file
   - "NO": Process all .fa files in the input directory

Example of options use: 
```bash
BAKTA_ann_GNU.sh 2 "NO"
```

### Addinational Script Notes
Example direct execution (Outside of HPC, not tested):
```bash
singularity exec -B /your/dir/to/data:/mnt/data /path/to/singularity/container bash BAKTA_ann_GNU.sh 8 "NO"  # Run 8 parallel jobs, process all genomes in the input
```

## Output Organization

For each input genome, the pipeline creates:
- A dedicated output directory named after the genome
- BAKTA annotation files with standardized prefixes
- A hidden `.completed` marker file to prevent running completed genomes again (could technically also resume a failed run without having to start over annotation on all genomes, WIP)

Final results will be in `/mnt/data/scratch/{UserInitial}/{Username}/{Project}/BAKTA_OUTPUT/`

## Troubleshooting

- Check Slurm log files in the designated logs directory
- For memory errors, increase the `--mem` parameter in the job script
- If jobs are taking too long, optimize the core usage further. Too few and the the tool is ineffective, too many and there will be hardware communication issues.
- If using the latest bakta version, make sure that the database downloaded into the container using the prepare_bakta_sandbox.sh script matches that version!

## Performance Notes

- Each genome typically requires 10-15 minutes to annotate
- Memory usage depends on genome size and complexity
- Adjust `MAX_PARALLEL_JOBS` based on available compute resources

_______________________________________________________________________________________________________________________________________________________________________

## Credits

### Authors
- Tor Kling (Anne Farewell Lab, University of Gothenburg) - Pipeline development and implementation

### Software Credits
- [BAKTA](https://github.com/oschwengers/bakta) - Rapid annotation of bacterial genomes and plasmids
- [GNU Parallel](https://www.gnu.org/software/parallel/) - Shell tool for parallel execution
- [Singularity/Apptainer](https://apptainer.org/) - Container platform

### Acknowledgments
- This work was performed using resources provided by PDC Center for High Performance Computing at KTH, provided access through NAISS

---
*Last updated: [Mar 28th 2025]*
