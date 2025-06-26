# Use a non-slim Debian base so apt keys and big deps work
FROM python:3.10

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
# Use official Python image

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    samtools \
    curl \
    bowtie2 \
    mash \
    bcftools \
    ncbi-blast+ \
    seqtk \
    git \
    python3-dev \
    gcc \
    make \
    perl \
    libjson-perl \
    libfile-slurp-perl \
    liblist-moreutils-perl \
    cpanminus && \
    cpanm --notest Moo File::Slurp JSON List::MoreUtils && \
    rm -rf /var/lib/apt/lists/*


#  WORKS LOCALLY BUT NOT IN DOCKER
# Install mlst and any2fasta from mlst GitHub repo
# RUN git clone https://github.com/tseemann/mlst.git /opt/mlst && \
#     chmod +x /opt/mlst/bin/mlst && \
#     ln -s /opt/mlst/bin/mlst /usr/local/bin/mlst && \
#     curl -fsSL https://raw.githubusercontent.com/tseemann/any2fasta/master/any2fasta -o /usr/local/bin/any2fasta && \
#     chmod +x /usr/local/bin/any2fasta


# # Install mlst and its bundled any2fasta
# RUN git clone https://github.com/tseemann/mlst.git /opt/mlst && \
#     chmod +x /opt/mlst/bin/mlst /opt/mlst/bin/any2fasta && \
#     ln -s /opt/mlst/bin/mlst /usr/local/bin/mlst && \
#     ln -s /opt/mlst/bin/any2fasta /usr/local/bin/any2fasta


# install core system deps for ECTyper + MLST
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      samtools bowtie2 mash bcftools ncbi-blast+ seqtk \
      git curl perl python3-dev gcc make \
      libjson-perl libfile-slurp-perl liblist-moreutils-perl \
      cpanminus \
 && cpanm --notest Moo File::Slurp JSON List::MoreUtils \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/tseemann/mlst.git /opt/mlst \
 && chmod +x /opt/mlst/bin/mlst \
 && ln -s /opt/mlst/bin/mlst /usr/local/bin/mlst \
 && ln -s /opt/mlst/bin/any2fasta /usr/local/bin/any2fasta

RUN curl -fsSL \
     https://raw.githubusercontent.com/tseemann/any2fasta/master/any2fasta \
   -o /usr/local/bin/any2fasta \
 && chmod +x /usr/local/bin/any2fasta


# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt


# Download ECTyper MASH sketch file during build
RUN mkdir -p /usr/local/lib/python3.10/site-packages/ectyper/Data && \
    curl -fL "https://zenodo.org/records/13969103/files/EnteroRef_GTDBSketch_20231003_V2.msh?download=1" \
      -o /usr/local/lib/python3.10/site-packages/ectyper/Data/EnteroRef_GTDBSketch_20231003_V2.msh


# Clone and install ECTyper (ecoli_serotyping) python package
RUN git clone https://github.com/phac-nml/ecoli_serotyping.git /opt/ecoli_serotyping && \
    cd /opt/ecoli_serotyping && \
    git checkout v2.0.0 && \
    pip install .

# Copy the MASH sketch file into the ectyper expected location
# COPY ectyper_data/EnteroRef_GTDBSketch_20231003_V2.msh /usr/local/lib/python3.10/site-packages/ectyper/Data/

# Copy application source code
COPY . .

# Back to app root before running
# WORKDIR /app

# Expose Flask port
# EXPOSE 10000
EXPOSE 5000

# health check for Render
HEALTHCHECK CMD curl --fail http://localhost:5000 || exit 1

# Start the app using gunicorn
CMD ["gunicorn", "--chdir", "app", "main:app", "--bind", "0.0.0.0:5000", "--timeout", "600"]

# CMD ["gunicorn", "-b", "0.0.0.0:5000", "app.main:app"]