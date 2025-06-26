# scripts/run_serotyping.py
from datetime import datetime 
import subprocess
import pandas as pd
import os

def run_serotyping(fasta_path):

    # Check if the file exists
    filename = os.path.basename(fasta_path)
    name_without_ext = os.path.splitext(filename)[0]

    # Generate timestamp to avoid overwriting
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    output_path = f"app/uploads/ectyper_output_{name_without_ext}_{timestamp}"

    # Run ECTyper command
    # Assume ectyper is installed and available in PATH
    subprocess.run([
        "ectyper", 
        "--verify",
        "--input", fasta_path,
        "--output", output_path,
        "--reference", "/usr/local/lib/python3.10/site-packages/ectyper/Data/EnteroRef_GTDBSketch_20231003_V2.msh"
    ], check=True)
    
    # Read and parse the output
    ectyper_output_file = os.path.join(output_path, "output.tsv")
    df = pd.read_csv(ectyper_output_file, sep="\t")
    
    row = df.iloc[0]
    
    result = {
        "species": row.get("Species", "N/A"),
        "serotype": row.get("Serotype", "N/A"),
        "qc": row.get("QC", "N/A"),
        "warnings": row.get("Warnings", "N/A")
    }
    
    return result
