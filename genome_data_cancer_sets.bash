#!/bin/bash

### Step 1: Install gdc-client if not already installed
# Add to PATH permanently by adding to .bashrc
if ! command -v gdc-client &> /dev/null; then
    echo "Installing gdc-client..."
    wget https://gdc.cancer.gov/files/public/file/gdc-client_v1.6.1_Ubuntu_x64.zip
    unzip gdc-client_v1.6.1_Ubuntu_x64.zip
    chmod +x gdc-client
    
    # Add to PATH permanently
    echo "export PATH=\$PATH:$PWD" >> ~/.bashrc
    export PATH=$PATH:$PWD  # Also add for current session
    
    echo "gdc-client installed and added to PATH"
fi

### Step 2: Download MAF files using the manifest
# Ensure the manifest file exists
if [ -f gdc_manifest.2025-03-31.115831.txt ]; then
    echo "Downloading files using manifest..."
    gdc-client download -m gdc_manifest.2025-03-31.115831.txt
else
    echo "Error: gdc_manifest.2025-03-31.115831.txt not found"
    exit 1
fi

### Step 3: Move downloaded files up one directory
echo "Moving downloaded files..."
for dir in $(ls -d */); do
    mv "$dir"* ./ 2>/dev/null || true  # Move files, ignore errors
    rmdir "$dir" 2>/dev/null || true   # Remove directory if empty
done

### Step 4: Process mutation files
# Define the genes of interest
GENE1="TP53"
GENE2="STAT5A"
OUTPUT_FILE="mutation_rates.txt"

# Initialize output file
echo "Mutation Rates Report" > $OUTPUT_FILE
echo "Generated on: $(date)" >> $OUTPUT_FILE
echo "---------------------------------" >> $OUTPUT_FILE

echo "Processing mutation files..."

for maf in *.maf.gz; do
    if [ ! -f "$maf" ]; then
        echo "No .maf.gz files found"
        continue
    fi
    
    echo "Processing $maf..."
    echo "Processing $maf..." >> $OUTPUT_FILE
    
    # Process the file directly without decompressing to disk
    # 1. Skip first 7 comment lines
    # 2. Get header line (8th line) to find gene symbol column
    # 3. Count occurrences of each gene in the correct column
    
    # Find the column number for Hugo_Symbol (gene name)
    HEADER_LINE=$(zcat "$maf" | head -8 | tail -1)
    GENE_COL=$(echo "$HEADER_LINE" | tr '\t' '\n' | grep -n "Hugo_Symbol" | cut -d: -f1)
    
    if [ -z "$GENE_COL" ]; then
        echo "Warning: Could not find Hugo_Symbol column in $maf, trying alternate column names..." 
        # Try other possible column names
        for COL_NAME in "Gene" "Gene_Symbol" "HUGO_Symbol"; do
            GENE_COL=$(echo "$HEADER_LINE" | tr '\t' '\n' | grep -n "$COL_NAME" | cut -d: -f1)
            if [ ! -z "$GENE_COL" ]; then
                echo "Found gene column with name: $COL_NAME"
                break
            fi
        done
    fi
    
    if [ -z "$GENE_COL" ]; then
        echo "Error: Could not identify gene column in $maf" 
        echo "Error: Could not identify gene column" >> $OUTPUT_FILE
        continue
    fi
    
    # Count mutations using awk to target specific column
    # Skip the first 8 lines (7 comments + header)
    TP53_COUNT=$(zcat "$maf" | awk -v start_line=9 -v col="$GENE_COL" -F'\t' 'NR >= start_line && $col == "TP53" {count++} END {print count}')
    STAT5A_COUNT=$(zcat "$maf" | awk -v start_line=9 -v col="$GENE_COL" -F'\t' 'NR >= start_line && $col == "STAT5A" {count++} END {print count}')
    
    echo "$GENE1 Mutations: $TP53_COUNT" 
    echo "$GENE1 Mutations: $TP53_COUNT" >> $OUTPUT_FILE
    
    echo "$GENE2 Mutations: $STAT5A_COUNT" 
    echo "$GENE2 Mutations: $STAT5A_COUNT" >> $OUTPUT_FILE
    
    echo "---------------------------------" >> $OUTPUT_FILE
done

### Step 5: Summarize results
echo "Generating summary..."
TOTAL_TP53=$(grep -A1 "Processing" "$OUTPUT_FILE" | grep "$GENE1" | awk '{sum += $NF} END {print sum}')
TOTAL_STAT5A=$(grep -A2 "Processing" "$OUTPUT_FILE" | grep "$GENE2" | awk '{sum += $NF} END {print sum}')

echo "Summary:" >> $OUTPUT_FILE
echo "Total $GENE1 mutations across all files: $TOTAL_TP53" >> $OUTPUT_FILE
echo "Total $GENE2 mutations across all files: $TOTAL_STAT5A" >> $OUTPUT_FILE

### Step 6: Display disk space usage
df -h

### Completion Message
echo "Mutation analysis complete. Results saved in $OUTPUT_FILE"
echo "Total $GENE1 mutations: $TOTAL_TP53"
echo "Total $GENE2 mutations: $TOTAL_STAT5A"
