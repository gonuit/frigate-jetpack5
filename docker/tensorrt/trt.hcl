variable "ARCH" {
  default = "amd64"
}
variable "BASE_IMAGE" {
  default = null
}
variable "SLIM_BASE" {
  default = null
}
variable "TRT_BASE" {
  default = null
}
variable "COMPUTE_LEVEL" {
  default = ""
}
variable "BASE_HOOK" {
  # Ensure an up-to-date python 3.11 is available in jetson images
  default = <<EOT
if grep -q focal /etc/os-release; then
  # focal (jetpack 5): deadsnakes has no arm64 binaries, use python-build-standalone
  # and enable deb-src entries for apt-get build-dep
  curl -fsSL -o /tmp/python311.tar.gz https://github.com/astral-sh/python-build-standalone/releases/download/20260623/cpython-3.11.15+20260623-aarch64-unknown-linux-gnu-install_only.tar.gz \
    && echo "1de978b7039f345dacdddc3efb0726ce5b957bbbd34161037a4b426aabb18bf5  /tmp/python311.tar.gz" | sha256sum -c \
    && tar -xzf /tmp/python311.tar.gz --strip-components=1 -C /usr/local \
    && rm /tmp/python311.tar.gz \
    && sed -n "s/^deb /deb-src /p" /etc/apt/sources.list >> /etc/apt/sources.list
elif grep -iq \"ubuntu\" /etc/os-release; then
  . /etc/os-release

  # Add the deadsnakes PPA repository
  echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $VERSION_CODENAME main" >> /etc/apt/sources.list.d/deadsnakes.list
  echo "deb-src https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu $VERSION_CODENAME main" >> /etc/apt/sources.list.d/deadsnakes.list

  # Add deadsnakes signing key
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776
fi
EOT
}

target "_build_args" {
  args = {
    BASE_IMAGE = BASE_IMAGE,
    SLIM_BASE = SLIM_BASE,
    TRT_BASE = TRT_BASE,
    COMPUTE_LEVEL = COMPUTE_LEVEL,
    BASE_HOOK = BASE_HOOK
  }
  platforms = ["linux/${ARCH}"]
}

target wget {
  dockerfile = "docker/main/Dockerfile"
  target = "wget"
  inherits = ["_build_args"]
}

target deps {
  dockerfile = "docker/main/Dockerfile"
  target = "deps"
  inherits = ["_build_args"]
}

target rootfs {
  dockerfile = "docker/main/Dockerfile"
  target = "rootfs"
  inherits = ["_build_args"]
}

target wheels {
  dockerfile = "docker/main/Dockerfile"
  target = "wheels"
  inherits = ["_build_args"]
}

target devcontainer {
  dockerfile = "docker/main/Dockerfile"
  platforms = ["linux/amd64"]
  target = "devcontainer"
}

target "trt-deps" {
  dockerfile = "docker/tensorrt/Dockerfile.base"
  context = "."
  contexts = {
    deps = "target:deps",
  }
  inherits = ["_build_args"]
}

target "tensorrt" {
  dockerfile = "docker/tensorrt/Dockerfile.${ARCH}"
  context = "."
  contexts = {
    wget = "target:wget",
    wheels = "target:wheels",
    deps = "target:deps",
    rootfs = "target:rootfs"
  }
  target = "frigate-tensorrt"
  inherits = ["_build_args"]
}

target "devcontainer-trt" {
  dockerfile = "docker/tensorrt/Dockerfile.amd64"
  context = "."
  contexts = {
    wheels = "target:wheels",
    trt-deps = "target:trt-deps",
    devcontainer = "target:devcontainer"
  }
  platforms = ["linux/amd64"]
  target = "devcontainer-trt"
}
