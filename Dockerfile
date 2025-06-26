# Use a non-slim Debian base so apt keys and big deps work
FROM python:3.10

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system + bioinformatics dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    samtools curl bowtie2 mash bcftools ncbi-blast+ seqtk \
    git python3-dev gcc make perl \
    libjson-perl libfile-slurp-perl liblist-moreutils-perl \
    libdatetime-perl libxml-simple-perl libdigest-md5-perl \
    bioperl libmoose-perl libmoo-perl \
    cpanminus && \
    cpanm --notest Moo File::Slurp JSON List::MoreUtils DateTime XML::Simple Digest::MD5 && \
    rm -rf /var/lib/apt/lists/*

# Install MLST
RUN git clone https://github.com/tseemann/mlst.git /opt/mlst && \
    chmod +x /opt/mlst/bin/mlst /opt/mlst/bin/any2fasta && \
    ln -s /opt/mlst/bin/mlst /usr/local/bin/mlst && \
    ln -s /opt/mlst/bin/any2fasta /usr/local/bin/any2fasta && \
    mlst --help > /dev/null || (echo "X MLST installation failed!" && exit 1)

# Install Python deps
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Install ECTyper
RUN git clone https://github.com/phac-nml/ecoli_serotyping.git /opt/ecoli_serotyping && \
    cd /opt/ecoli_serotyping && \
    git checkout v2.0.0 && \
    pip install .

# Download ECTyper MASH sketch file
RUN mkdir -p /usr/local/lib/python3.10/site-packages/ectyper/Data && \
    curl -fL "https://zenodo.org/records/13969103/files/EnteroRef_GTDBSketch_20231003_V2.msh?download=1" \
    -o /usr/local/lib/python3.10/site-packages/ectyper/Data/EnteroRef_GTDBSketch_20231003_V2.msh && \
    chmod 644 /usr/local/lib/python3.10/site-packages/ectyper/Data/EnteroRef_GTDBSketch_20231003_V2.msh && \
    mash info -t /usr/local/lib/python3.10/site-packages/ectyper/Data/EnteroRef_GTDBSketch_20231003_V2.msh || (echo "❌ MASH sketch file not valid!" && exit 1)

# Copy the app source
COPY . .

EXPOSE 5000

HEALTHCHECK CMD curl --fail http://localhost:5000 || exit 1

CMD ["gunicorn", "--chdir", "app", "main:app", "--bind", "0.0.0.0:5000", "--timeout", "600"]