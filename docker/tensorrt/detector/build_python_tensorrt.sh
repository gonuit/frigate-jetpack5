#!/bin/bash

set -euxo pipefail

mkdir -p /trt-wheels

if [[ "${TARGETARCH}" == "arm64" ]]; then

  # NVIDIA supplies python-tensorrt for python3.10, but frigate uses python3.11,
  # so we must build python-tensorrt ourselves.

  # Get python-tensorrt source
  mkdir -p /workspace
  cd /workspace
  git clone -b "release/${TENSORRT_VER%.*}" https://github.com/NVIDIA/TensorRT.git --depth=1

  # Collect dependencies
  EXT_PATH=/workspace/external && mkdir -p $EXT_PATH
  pip3 install pybind11 && ln -s "$(pip3 show pybind11 | grep -Po '^Location: \K.*')/pybind11" $EXT_PATH/pybind11
  ln -s "$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["include"])')" $EXT_PATH/python3.11
  ln -s /usr/include/aarch64-linux-gnu/NvOnnxParser.h /workspace/TensorRT/parsers/onnx/

  # Build wheel
  cd /workspace/TensorRT/python
  EXT_PATH=$EXT_PATH PYTHON_MAJOR_VERSION=3 PYTHON_MINOR_VERSION=11 TARGET_ARCHITECTURE=aarch64 TENSORRT_MODULE=tensorrt /bin/bash ./build.sh
  find build -name 'tensorrt-*.whl' -exec mv -v {} /trt-wheels/ \;
  ls /trt-wheels/tensorrt-*.whl

fi
