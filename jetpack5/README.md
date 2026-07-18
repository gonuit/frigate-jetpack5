# Frigate 0.17 on JetPack 5

Upstream dropped the jp5 images in 0.16. This branch rebuilds v0.17.2 for
JetPack 5, using a CUDA 11.4 build of onnxruntime 1.19.2 from
[onnxruntime-jetpack5](https://github.com/gonuit/onnxruntime-jetpack5).

Same features as the official jp6 image: `onnx` detector on the GPU, legacy
`tensorrt` detector, Coral USB, jetson ffmpeg.

## Prebuilt image

```sh
docker pull ghcr.io/gonuit/frigate-jetpack5:0.17.2-tensorrt-jp5
```

## Building

On a JetPack 5 device with docker and buildx:

```sh
make local-trt-jp5
```

Builds `frigate:latest-tensorrt-jp5`. The onnxruntime wheel is downloaded
during the build.

## Configuration

Same as the official jp6 image. YOLOv9 export snippet from the docs, tweaked
so it runs on the Jetson too (stock torch fails to install on arm64):

```sh
docker build . --build-arg MODEL_SIZE=s --build-arg IMG_SIZE=320 --output . -f- <<'EOF'
FROM python:3.11 AS build
RUN apt-get update && apt-get install --no-install-recommends -y cmake libgl1 && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.10.4 /uv /bin/
WORKDIR /yolov9
ADD https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system torch torchvision --index-url https://download.pytorch.org/whl/cpu
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system onnx==1.18.0 onnxruntime onnxsim==0.4.* onnxscript
ARG MODEL_SIZE
ARG IMG_SIZE
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt
RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py
RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz ${IMG_SIZE} --simplify --include onnx
FROM scratch
ARG MODEL_SIZE
ARG IMG_SIZE
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx
EOF
```

Put the model in your config volume and use:

```yaml
detectors:
  onnx:
    type: onnx
    device: Tensorrt

model:
  model_type: yolo-generic
  path: /config/model_cache/yolov9-s-320.onnx
  labelmap_path: /labelmap/coco-80.txt
  input_tensor: nchw
  input_dtype: float
  width: 320
  height: 320
```

Tested on a Xavier NX (JetPack 5.0.2): three camera streams with hardware
decode, ~9 ms inference with yolov9-s 320, ~21 ms with yolov9-c 416
(`device: Tensorrt`). Orin and Coral USB are untested.
