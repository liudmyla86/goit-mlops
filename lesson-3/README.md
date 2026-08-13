 Homework #3 — ML Model Containerization (fat vs slim)

This project demonstrates a complete MLOps cycle for a simple inference
task: environment setup → model export to TorchScript → writing an
inference script → building two Docker images (fat / slim) → comparing
results and image sizes.

Model: **MobileNetV2** (ImageNet, 1000 classes) from `torchvision.models`,
exported to **TorchScript** format (`torch.jit.trace`).

## Project Structure

lesson-3/
├── app/
│ └── inference.py # inference script (top-3 predictions)
├── model/
│ └── model.pt # TorchScript model (created by export_model.py)
├── scripts/
│ └── install_dev_tools.sh # environment check/setup script
├── screenshots/ # screenshots of real runs (build, run, inference)
├── export_model.py # export MobileNetV2 -> TorchScript
├── requirements.txt # torch / torchvision / pillow
├── Dockerfile.fat # "heavy" image (python:3.13)
├── Dockerfile.slim # optimized multi-stage image (python:3.13-slim)
├── .dockerignore
├── example.jpg # test image (dog, golden retriever)
├── report.md # fat vs slim comparison with real metrics
└── README.md


## Requirements

- Docker + Docker Compose V2 (`docker compose version`)
- Python **3.13**+
- pip3
- Packages: `torch==2.7.0`, `torchvision==0.22.0`, `pillow==11.2.1` (see `requirements.txt`)

## 1. Environment Setup

```bash
bash scripts/install_dev_tools.sh
```

The script is idempotent: it checks for Docker, Docker Compose V2,
Python ≥ 3.13, pip, and the required ML libraries; anything missing is
either installed automatically or a precise instruction is printed. All
results are logged to `install.log`. Verified by running twice in a
row — the second run performs no repeated `pip install` calls and simply
confirms `OK: already installed`.

## 2. Local Verification (without Docker)

Install dependencies:

```bash
pip install -r requirements.txt
```

Export the model to TorchScript:

```bash
python export_model.py
# -> downloads pretrained MobileNetV2 weights and creates model/model.pt
```

Run inference locally:

```bash
python app/inference.py example.jpg
```

Real result for `example.jpg` (photo of a dog on the beach):

Top-3 predictions for 'example.jpg':

class_id=207 golden retriever confidence=0.3226
class_id=213 Irish setter confidence=0.0683
class_id=209 Chesapeake Bay retriever confidence=0.0575

## 3. Building Docker Images

Fat image (simple, python:3.13, single stage):

```bash
docker build -f Dockerfile.fat -t ml-infer-fat:1.0 .
```

Slim image (multi-stage, python:3.13-slim):

```bash
docker build -f Dockerfile.slim -t ml-infer-slim:1.0 .
```

## 4. Running Inference in Containers

Both images already contain `example.jpg` and `model/model.pt` inside
(copied during the build), so they can be run without a bind mount:

```bash
docker run --rm ml-infer-fat:1.0
docker run --rm ml-infer-slim:1.0
```

Or explicitly pass a different image via bind mount:

```bash
docker run --rm -v "$(pwd)/example.jpg:/app/example.jpg" ml-infer-fat:1.0 example.jpg
docker run --rm -v "$(pwd)/example.jpg:/app/example.jpg" ml-infer-slim:1.0 example.jpg
```

Top-3 predictions **fully match** across both images (verified with a
real build — see `report.md`).

## 5. Comparing Images

```bash
docker images | grep ml-infer
docker history ml-infer-fat:1.0
docker history ml-infer-slim:1.0
```

Real results:

| Metric | Fat | Slim |
|---|---|---|
| Image size | 6.75 GB | 5.71 GB |
| Number of layers | 22 | 17 |

Full analysis, heaviest layers, and optimization suggestions — see [`report.md`](./report.md).

## 6. Screenshots

Real runs on the local machine (Docker Desktop, Windows, Git Bash):

**Building the fat image:**
![build fat](./screenshots/mlops%203.1.png)

**Building the slim image:**
![build slim](./screenshots/mlops%203.2.png)

**Inference result / image comparison:**
![inference result](./screenshots/mlops%203.3.png)

**`docker images` — size of both images:**
![docker images](./screenshots/mlops%203.4.png)

## Source of example.jpg

`example.jpg` is a photo of a golden retriever dog on a beach, used to
verify the correctness of the inference pipeline and the consistency of
results between the fat and slim images.

## Note on the Development Environment

The project was fully built and verified on a real machine with Docker
Desktop (Windows, Git Bash / MINGW64): both images were built and run
successfully, top-3 predictions match, and real sizes/layer counts are
recorded in `report.md`.
