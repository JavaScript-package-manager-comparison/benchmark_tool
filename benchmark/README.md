# Benchmark Tool for Package Manager Comparison

Tool designed to measure and compare the performance of various JavaScript package managers within Docker environments.

## 🛠 Prerequisites
- Docker installed and running
- Docker Compose

## 🚀 Quick Start

### 1. Clean build
Prepare the environment and ensure no cached layers are used:

```bash
docker compose build --no-cache
```

### 2. Run benchmark
Execute the main benchmarking suite:

```bash
docker compose run --rm benchmark
```

### 3. Cleanup
To remove all images and containers created by this tool:

```Bash
docker compose down --rmi all
```
## 📊 Results
The benchmark results will be stored in `results` directory