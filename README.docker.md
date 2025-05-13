# Using the AVS Benchmark Tools with Docker

This document explains how to build and use the Docker container defined in the `dockerfile` to run the Aerospike Vector Search (AVS) benchmark tools (`hdf_import.py`, `hdf_query.py`, etc.). Using Docker provides a consistent and isolated environment with all necessary dependencies pre-installed.

## Prerequisites

*   **Docker:** You need Docker installed on your system. Visit [docker.com](https://docs.docker.com/get-docker/) for installation instructions.
*   **Docker Buildx (Recommended for Multi-Arch):** If you need to build images for architectures different from your host machine (e.g., building an `arm64` image on an `amd64` host or vice-versa), Docker Buildx is recommended. It's usually included with modern Docker Desktop installations.

## Building the Docker Image

1.  **Navigate:** Open a terminal or command prompt and navigate to the root directory of the `avs-benchmark-ann` project (where the `dockerfile` is located).
2.  **Build:** Run the build command.

    *   **For your host's architecture:**
        ```bash
        docker build -t avs-benchmark-tool .
        ```
        *(You can replace `avs-benchmark-tool` with your preferred image name)*

    *   **For multi-architecture (amd64 & arm64) using buildx (Recommended):**
        ```bash
        # Optional: Create and switch to a new builder instance if you haven't already
        # docker buildx create --use --name mybuilder

        # Build for both platforms and push to a registry (replace 'your-repo' if pushing)
        docker buildx build --platform linux/amd64,linux/arm64 -t your-repo/avs-benchmark-tool:latest --push .

        # OR Build for a specific platform and load locally (e.g., for arm64)
        # docker buildx build --platform linux/arm64 -t avs-benchmark-tool:arm64 --load .
        ```

## Running Benchmark Scripts

The Docker container is designed to execute the Python benchmark scripts directly. You specify the script name and its arguments after the `docker run` command and image name.

**General Structure:**

```bash
docker run [DOCKER_OPTIONS] <IMAGE_NAME> <SCRIPT_NAME.py> [SCRIPT_ARGUMENTS...]
```

**Key Docker Options:**

*   `--rm`: Automatically removes the container filesystem when the container exits. Recommended for benchmark runs.
*   `-it`: Use if a script requires interactive input (though these benchmark scripts generally don't).
*   `-v /path/on/host:/app/data`: **Highly Recommended for Persisting Datasets.** This mounts a directory from your host machine (`/path/on/host`) into the container at `/app/data`. The benchmark scripts cache downloaded datasets (like `glove-100-angular`) in `/app/data`. Using a volume mount prevents re-downloading datasets every time you run the container.
    *   Example: `-v "$(pwd)/data:/app/data"` mounts a directory named `data` inside your current working directory on the host. Create this `data` directory on your host if it doesn't exist.

**Connecting to AVS:**

*   **AVS on Host Machine (Docker Desktop):** Often, you can use the special DNS name `host.docker.internal` as the hostname. The port will be the one AVS is listening on (e.g., 10000).
    *   Example: `--host host.docker.internal --vectorport 10000`
*   **AVS in another Docker Container:** If AVS is running in another container on the same Docker network, use the AVS container's name as the hostname.
*   **AVS on a Remote Machine:** Use the remote machine's IP address or hostname. Ensure your Docker container can reach that address (network configuration/firewalls).
*   **Using `--vectorloadbalancer`:** When connecting to a single AVS node (especially via `host.docker.internal`) or an external load balancer address from within Docker, add the `--vectorloadbalancer` flag to your command. This tells the client library not to attempt cluster node discovery based on the seed node's potentially internal address, preventing connection errors where the client might try to connect back to `127.0.0.1` inside the container. NOTE: using --vectorloadbalancer forces an extra network hop which can affect performance, it is best to properly configure an AVS test cluster that does not need this flag when optimizing for performance. You may need to configure the AVS node's [advertised listener addresses](https://aerospike.com/docs/vector/manage/config#advertised-listener) if you are running AVS in the cloud or on docker.

### Example: Basic Benchmark Run

This example runs a small benchmark using the `glove-100-angular` dataset against an AVS cluster assumed to be accessible from the container (e.g., running on the host at port 10000).

1.  **Create a local data directory (if it doesn't exist):**
    ```bash
    mkdir -p data
    ```

2.  **Step 1: Import Data & Create Index**
    This command downloads the dataset (if not already in the mounted `./data` volume), connects to AVS, drops any existing index with the default name, creates a new one, and populates it.

    ```bash
    docker run --rm -v "$(pwd)/data:/app/data" avs-benchmark-tool \
      hdf_import.py \
        --dataset glove-100-angular \
        --host host.docker.internal \
        --vectorport 10000 \
        --vectorloadbalancer \
        --idxdrop
    ```
    *(Replace `host.docker.internal` and `10000` if your AVS setup differs)*

3.  **Step 2: Query the Index**
    Once the import is complete, run queries against the newly populated index.

    ```bash
    docker run --rm -v "$(pwd)/data:/app/data" avs-benchmark-tool \
      hdf_query.py \
        --dataset glove-100-angular \
        --host host.docker.internal \
        --vectorport 10000 \
        --vectorloadbalancer \
        --runs 1 \
        --limit 10 \
        --check
    ```
    *(Adjust host/port as needed. The volume mount ensures `hdf_query.py` can also access dataset metadata if needed)*

### Other Script Examples

*   **Download a BigANN Dataset (requires `axel` and `azcopy` installed in the image):**
    ```bash
    docker run --rm -v "$(pwd)/data:/app/data" avs-benchmark-tool \
      bigann_download.py --dataset <bigann_dataset_name>
    ```

*   **Create an HDF dataset from Aerospike data:**
    ```bash
    docker run --rm -v "$(pwd)/data:/app/data" avs-benchmark-tool \
      hdf_create_dataset.py \
        --idx <source_index_name> \
        --hdf data/<output_hdf_filename>.hdf5 \
        --hosts <aerospike_db_host>:<aerospike_db_port> \
        [other_args...]
    ```
    *(Note: `--hdf data/...` saves the output HDF file within the mounted volume, making it accessible on your host)*

Remember to consult the main `README.md` or use the `--help` argument for each script (`docker run avs-benchmark-tool <script_name.py> --help`) to see all available options.
