# Base image: Using Python 3.10 on Debian Bullseye (slim version)
FROM python:3.10-slim-bullseye

# Set environment variables for Python and Pip
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on

# Install common system dependencies first
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    gpg \
    curl \
    axel \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install azcopy based on architecture using direct download via aka.ms links
# ARG TARGETARCH is automatically available during buildx
ARG TARGETARCH
RUN \
    # Set DEBIAN_FRONTEND to noninteractive to avoid potential prompts
    export DEBIAN_FRONTEND=noninteractive && \
    AZCOPY_URL="" && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        echo "Setting azcopy download URL for arm64 (using aka.ms link)" && \
        AZCOPY_URL="https://aka.ms/downloadazcopy-v10-linux-arm64"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        echo "Setting azcopy download URL for amd64 (using aka.ms link)" && \
        # Note: aka.ms/downloadazcopy-v10-linux typically points to the amd64 version
        AZCOPY_URL="https://aka.ms/downloadazcopy-v10-linux"; \
    else \
        echo "Unsupported architecture for azcopy: $TARGETARCH" && exit 1; \
    fi && \
    \
    echo "Downloading azcopy from $AZCOPY_URL" && \
    # Use curl with -L to follow redirects from aka.ms
    curl -L "$AZCOPY_URL" -o /tmp/azcopy.tar.gz && \
    # Extract the azcopy binary to /usr/local/bin
    tar -xzf /tmp/azcopy.tar.gz -C /usr/local/bin --strip-components=1 --wildcards '*/azcopy' && \
    chmod +x /usr/local/bin/azcopy && \
    rm /tmp/azcopy.tar.gz && \
    echo "Successfully installed latest azcopy via direct download for $TARGETARCH"

# Verify azcopy installation
RUN azcopy --version

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file first to leverage Docker's build cache
COPY requirements.txt .

# Install Python dependencies specified in requirements.txt
RUN pip install -r requirements.txt

# Copy the rest of the application code from the build context into the working directory
# This includes all .py files, the 'bigann' directory, README, etc.
COPY . .

# Create a directory for dataset caching by the scripts (e.g., ./data)
# This directory can be mounted as a volume from the host to persist downloaded datasets.
RUN mkdir -p /app/data

# Set the entrypoint to python3.
# When running the container, you will specify the script name and its arguments after the image name.
ENTRYPOINT ["python3"]

# Example: If you wanted a default command (uncomment and modify as needed):
# CMD ["hdf_import.py", "--help"]