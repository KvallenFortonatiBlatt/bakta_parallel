#!/bin/bash
set -e
set -u

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges."
    echo "Usage: sudo $0 -s <sif_file> -o <output_sandbox_path>"
    exit 1
fi

# Default values
SIF_PATH=""
SANDBOX_PATH=""
DB_URL="https://zenodo.org/records/7025248/files/db.tar.gz"

# Function to display usage upon -h run
show_usage() {
    echo "Usage: sudo $0 -s <sif_file> -o <output_sandbox_path>"
    echo "  -s    Path to input BAKTA .sif file"
    echo "  -o    Path where to create the sandbox container"
    echo "  -h    Show this help message"
    exit 1
}

# Parse command line options
while getopts "s:o:h" opt; do
    case $opt in
        s) SIF_PATH="$OPTARG" ;;
        o) SANDBOX_PATH="$OPTARG" ;;
        h) show_usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; show_usage ;;
    esac
done

# Check if required parameters are provided
if [ -z "$SIF_PATH" ] || [ -z "$SANDBOX_PATH" ]; then
    echo "Error: Input SIF file and output sandbox path must be specified."
    show_usage
fi

# Check if SIF file exists
if [ ! -f "$SIF_PATH" ]; then
    echo "Error: SIF file '$SIF_PATH' not found."
    exit 1
fi

# Convert SIF to sandbox
echo "Converting SIF to sandbox container..."
singularity build --sandbox "$SANDBOX_PATH" "$SIF_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to convert SIF to sandbox."
    exit 1
fi

# Write the temp-script to run inside the container
## Installs GNU Parallel and downloads BAKTA database
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOL'
#!/bin/bash
set -e
set -u

echo "Setting up container environment..."

# Detect package manager and install GNU Parallel
if ! command -v parallel &> /dev/null; then
    echo "Installing GNU Parallel..."
    
    # Try to detect available package manager
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y parallel
    elif command -v yum &> /dev/null; then
        yum install -y parallel
    elif command -v apk &> /dev/null; then
        apk add --no-cache parallel
    elif command -v conda &> /dev/null; then
        conda install -c conda-forge parallel
    else
        echo "WARNING: Could not detect package manager. If you have a different distribution, please configure the temp script with your package manager."
        exit 1
    fi
    
    # Setup will-cite
    mkdir -p /root/.parallel
    touch /root/.parallel/will-cite
else
    echo "GNU Parallel is already installed."
fi

# Create BAKTA database directory
mkdir -p /opt/bakta_db/db

# Download and install BAKTA database
echo "Downloading BAKTA database (this may take a while)..."
cd /tmp
# Using curl as a fallback if wget is not available in the container
wget -q --show-progress https://zenodo.org/records/14916843/files/db.tar.xz -O db.tar.xz || curl -o db.tar.xz https://zenodo.org/records/14916843/files/db.tar.xz
echo "Extracting database..."
tar -xJf db.tar.xz -C /opt/bakta_db
rm db.tar.xz

# Verify installation
echo "Verifying installations..."
echo "BAKTA:"
bakta --version || echo "BAKTA not found or not in PATH"
echo "GNU Parallel:"
parallel --version || echo "GNU Parallel not found or not in PATH"

echo "Installation complete!"
EOL

# Make the script executable
chmod +x "$TEMP_SCRIPT"

# Run the script inside the sandbox container
echo "Preparing the sandbox container..."
singularity exec --writable "$SANDBOX_PATH" bash "$TEMP_SCRIPT"

# Clean up
rm "$TEMP_SCRIPT"

echo "Container preparation complete!"
echo "Your BAKTA sandbox with database is ready at: $SANDBOX_PATH"
echo ""
echo "To use this container with your pipeline:"
echo "singularity exec -B /your/host/path:/mnt/data $SANDBOX_PATH bash /path/to/BAKTA_ann_GNU.sh [JOBS] [TEMP]"
