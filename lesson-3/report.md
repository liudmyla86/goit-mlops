Report: Comparison of Fat vs Slim Docker Images (ml-infer)
1. What Was Compared
	Fat Image	Slim Image
Dockerfile	Dockerfile.fat	Dockerfile.slim
Base image	python:3.13	python:3.13-slim (multi-stage)
Number of build stages	1	2 (builder → runtime)
System packages	build-essential, libjpeg-dev, zlib1g-dev, libpng-dev, curl, git, vim	build-essential/libjpeg-dev/zlib1g-dev only in builder; final image contains only libjpeg62-turbo, zlib1g
pip cache	--no-cache-dir	--no-cache-dir, installed into --prefix=/install; only the installed packages are copied to /usr/local
Git / build tools in final layer	Yes (remain in the image)	No (discarded together with the builder stage)
2. Actual Measured Metrics

Commands used to obtain the data:

docker build -f Dockerfile.fat -t ml-infer-fat:1.0 .
docker build -f Dockerfile.slim -t ml-infer-slim:1.0 .
docker images | grep ml-infer
docker history ml-infer-fat:1.0
docker history ml-infer-slim:1.0
Metric	Fat Image	Slim Image
Image size	6.75 GB	5.71 GB
Number of layers (docker history)	22	17
Largest layer	RUN pip install -r requirements.txt — 5.58 GB	COPY --from=builder /install /usr/local — 5.57 GB
Build time	~12 min (743.8s)	~11 min (665.3s)
Inference result (top-3, example.jpg)	golden retriever (0.32) / Irish setter (0.07) / Chesapeake Bay retriever (0.06)	golden retriever (0.32) / Irish setter (0.07) / Chesapeake Bay retriever (0.06) — identical result
Unnecessary tools in the final layer	git, vim, curl, build-essential are present	absent — only JPEG/PNG runtime libraries remain
3. Analysis
What Was Unnecessary in the Fat Image
build-essential, libjpeg-dev, zlib1g-dev, and libpng-dev are needed only for compiling native extensions during pip install. However, in the fat image they remain permanently even though they are no longer required for inference.
git, curl, and vim are development tools that are unnecessary for running inference in a production container. They add extra megabytes and increase the attack surface.
The full python:3.13 base image is inherently larger than the python:3.13-slim variant even before any Python packages are installed.
The absence of a multi-stage build means that build tools remain permanently in the final image layers.
What Changed in the Slim Image
Multi-stage build: build dependencies (build-essential, *-dev packages) are used only during the builder stage and are physically excluded from the final image. The runtime stage contains only the minimal libjpeg62-turbo and zlib1g packages.
pip install --prefix=/install combined with COPY --from=builder /install /usr/local excludes the pip cache and build tools from the final layers without requiring manual PYTHONPATH configuration.
The number of layers decreased from 22 to 17 (-23%), while the image size decreased from 6.75 GB to 5.71 GB (-15%, or approximately 1.04 GB).
.dockerignore ensures that .git, __pycache__/, caches, and documentation are not included in the build context of either image.
Why the Size Difference Is Smaller Than Expected

The largest layer in both images is the installation of torch/torchvision (~5.57–5.58 GB), and this size dominates the overall image regardless of whether the packages are installed directly in the fat image or during the builder stage of the slim image.

The standard PyPI wheel for torch pulls in a complete set of CUDA libraries (nvidia-cublas-cu12, nvidia-cudnn-cu12, nvidia-cusparse-cu12, etc.), even though inference in this project runs only on the CPU.

Therefore, the main benefit of the multi-stage approach in this case is not reducing the size of PyTorch itself, but removing system build tools and unnecessary layers around it.

Did the Inference Result Change?

No. Both images use the same model/model.pt file (TorchScript, serialized once using export_model.py), the same preprocessing (weights.transforms()), and the same inference code (app/inference.py).

The top-3 predictions for example.jpg (an image of a golden retriever) were identical in both containers:

golden retriever — confidence 0.32
Irish setter — confidence 0.07
Chesapeake Bay retriever — confidence 0.06

All three breeds are visually similar in appearance, so these predictions are reasonable for the model.

Suggestions for Further Optimization
CPU-only PyTorch wheels: explicitly install torch==2.7.0+cpu from the dedicated CPU index (--index-url https://download.pytorch.org/whl/cpu). This could eliminate approximately 4–5 GB of CUDA dependencies that are completely unnecessary for this CPU-only inference scenario. This optimization would have a much greater impact than the multi-stage structure alone.
Separate model weights from application code: instead of storing model.pt inside the Docker image, mount it as a volume or download it from object storage when the container starts.
Model distillation / quantization: use torch.quantization or export the model to ONNX and use ONNX Runtime, which can provide a significantly smaller runtime environment than the full PyTorch package for inference-only scenarios.
Alpine/distroless base image: for an even smaller runtime image, consider gcr.io/distroless/python3 or an Alpine-based image, while taking into account possible compatibility issues between musl libc and native Python wheels.
4. Conclusion

The multi-stage build and the use of python:3.13-slim resulted in a real image size reduction of approximately 1.04 GB (15%) and reduced the number of layers from 22 to 17 (-23%), without affecting inference correctness. The top-3 predictions were completely identical in both containers.

At the same time, the greatest opportunity for further optimization lies not in the Dockerfile structure itself, but in using a CPU-only PyTorch build. PyTorch with its CUDA dependencies (~5.57 GB) is the dominant contributor to the size of both images and significantly outweighs the savings achieved by removing build tools.
