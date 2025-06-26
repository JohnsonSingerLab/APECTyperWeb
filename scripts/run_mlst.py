import subprocess
import pandas as pd
import os

def run_mlst(fasta_path):
    output_path = fasta_path + "_mlst.tsv"

    # Run MLST command
    with open(output_path, "w") as f:
        subprocess.run([
            "mlst",
            fasta_path
        ], stdout=f, check=True)

    # Read and parse the output
    df = pd.read_csv(output_path, sep="\t", header=None)
    row = df.iloc[0]

    # Extract the third column
    sequence_type = row[2] if len(row) > 2 else "N/A"

    result = {
        "sequence_type": sequence_type
    }

    return result