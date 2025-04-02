#!/bin/bash
set -e
set -u
set -o pipefail
set -x

# Parse command-line arguments for path to input file
MAX_PARALLEL_JOBS=${1:-2}  # Default to 2 if not provided, expecting a machine with 10 core processors
MakeTEMPdir=${2:-"YES"}  # Default to YES if not provided

## Setup directories, hardcoded by default and alter as needed
FASTA_DIR="/mnt/data/projects/supr/{UserPartition}/{Project}/{USER_FASTA_DIR}"
REF_FILE="/mnt/data/projects/supr/{UserPartition}/{Project}/{USER_Ref.csv}"
DB_PATH="/opt/bakta_db/db"
OUTPUT_DIR="/mnt/data/scratch/{UserInitial}/{Username}/{Project}/BAKTA_OUTPUT"
TMP_DIR="/mnt/data/scratch/{UserInitial}/{Username}/BAKTA_TMP"

# Make directories if they do not exist and set open permissions
mkdir -p $OUTPUT_DIR
mkdir -p $TMP_DIR
chmod 777 "$OUTPUT_DIR"
chmod 777 "$TMP_DIR"

echo "Directories set"

# Copy the correct input files based on the strain ref file
# This allows for selective annotation, in case not all strains are used in the experiment 
# Checks first if a BAKTA_TMP folder exists, if not, it creates one and processes the files
if [ "$MakeTEMPdir" == "YES" ]; then
    echo "Copying input files"
    for fasta_file in "$FASTA_DIR"/*.fa; do
        strain_name=$(basename "$fasta_file" | cut -d'.' -f1)
        # Match the basename of the fasta file to the first column of the experimental metadata file
        if awk -F',' -v strain="$strain_name" '$1 == strain {found=1} END {exit !found}' "$REF_FILE"; then
            echo "$strain_name found in $REF_FILE"
            cp -v "$fasta_file" "$TMP_DIR"
            echo "Copied fasta file to temp folder"
        else
            echo "$strain_name not found in $REF_FILE"
        fi
    done

else
    echo "Using all input files"
    cp -v "$FASTA_DIR"/*.fa "$TMP_DIR"
    echo "Copied all fasta files to temp folder" 
fi

echo "Input files Ready"

# Count Genomes 
TOT_GENOMES=$(find "$TMP_DIR" -maxdepth 1 -name "*.fa" | wc -l)
find "$TMP_DIR" -type f -name "*.fa" -exec chmod 666 {} \;
echo "Temp full access set"

# Define function to run BAKTA on a single fasta file (For GNU Parallel)
run_bakta() {
    local fasta_file=$(realpath "$1")
    local db_path="$2"
    local output_base="$3"
    local base_name=$(basename "$fasta_file" .fa)
    local output_dir="${output_base}/${base_name}"
    local marker_file="${output_dir}/.completed"

    # Debugging information
    echo "Input: $fasta_file"
    echo "Output: $output_dir"

        # Check if already completed
    if [[ -f "$marker_file" ]]; then
        echo "Skipping $base_name - already processed"
        return 0
    fi
    
    # Make output directory
    mkdir -p "output_dir" || { echo "Error creating $output_dir"; }

    # Setup directories
    mkdir -p "${output_dir}/genome" || { echo "Error creating directory"; return 1; }
    cp -v "$fasta_file" "${output_dir}/genome/input.fa" || { echo "Error copying file"; return 1; }
    chmod 666 "${output_dir}/genome/input.fa"

    # Run BAKTA with direct path, Set the base genus to Escherichia but alter as needed
    cd "${output_dir}/genome" && \
    while read -r genome_file; do
        bakta --db "$db_path" \
              --genus "Escherichia" \
              --output "./OUTPUT" \
              --prefix "$base_name" \
              --threads 5 \
              "./input.fa"
    done < <(echo "./input.fa")

    if [ $? -eq 0 ]; then
        touch "$marker_file"
        echo "Completed $base_name"
        return 0
    else
        echo "Error processing $base_name" >&2
        return 1
    fi
}
export -f run_bakta

# Main parallel execution
echo "Running BAKTA in parallel on $TOT_GENOMES genomes"
FAILED=0
find "$TMP_DIR" -maxdepth 1 -name "*.fa" | \
    parallel -j "$MAX_PARALLEL_JOBS" \
            --joblog "$OUTPUT_DIR/parallel_job.log" \
            run_bakta {} "$DB_PATH" "$OUTPUT_DIR" || FAILED = 1 

if [ $FAILED -eq 0 ]; then
    echo "All BAKTA jobs completed successfully"
    rm -rf "$TMP_DIR"
    chmod 775 "$OUTPUT_DIR"
    echo "Results in $OUTPUT_DIR"
else
    echo "Some BAKTA jobs failed. Check $OUTPUT_DIR/parallel_job.log"
    exit 1
fi

