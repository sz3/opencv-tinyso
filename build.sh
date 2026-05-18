#!/usr/bin/env bash
# docker run --rm -v ".:/work" -v "~/Android/Sdk/ndk/27.3.13750724/:/work/android-ndk:ro" -v "~/Android/Sdk/:/work/android-sdk:ro" ubuntu:24.04 bash /work/build.sh
## expects /work/opencv4 to contain the opencv source

BUILD_ROOT=${BUILD_ROOT:-/work}
cd $BUILD_ROOT

set -exuo pipefail
OPENCV_SRC="${BUILD_ROOT}/opencv4"
ANDROID_NDK="${BUILD_ROOT}/android-ndk"
ANDROID_SDK_ROOT="${BUILD_ROOT}/android-sdk"
BUILD_DIR="${BUILD_ROOT}/build"
OUTPUT_DIR="${BUILD_ROOT}/output"

ABI="${ABI:-arm64-v8a}"
API_LEVEL="${API_LEVEL:-21}"
JOBS="${JOBS:-$(nproc)}"

# install deps
apt-get update -qq
xargs apt-get install -y --no-install-recommends <<-EOF
	cmake
	make
	ninja-build
	openjdk-17-jdk-headless
	python3
	unzip
	wget
	file
EOF

# make sure things are sane
TOOLCHAIN="${ANDROID_NDK}/build/cmake/android.toolchain.cmake"
if [[ ! -f "$TOOLCHAIN" ]]; then
    echo "ERROR: NDK toolchain not found at: $TOOLCHAIN" >&2
    exit 1
fi
if [[ ! -f "${OPENCV_SRC}/CMakeLists.txt" ]]; then
    echo "ERROR: OpenCV source not found at: $OPENCV_SRC" >&2
    exit 1
fi

# cmake
mkdir -p "$BUILD_DIR"
cmake_flags=(
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
    -DANDROID_ABI="$ABI"
    -DANDROID_PLATFORM="android-${API_LEVEL}"
    -DANDROID_STL=c++_shared
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_LIST=calib3d,imgcodecs,imgproc,photo,core,java
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_ANDROID_PROJECTS=ON
    -DBUILD_ANDROID_EXAMPLES=OFF
    -DBUILD_TESTS=OFF
    -DBUILD_PERF_TESTS=OFF
    -DBUILD_DOCS=OFF
    -DBUILD_opencv_apps=OFF
    -DOPENCV_ENABLE_DOWNLOAD=OFF
    -DWITH_OPENCL=OFF
    -DWITH_OPENCL_SVM=OFF
    -DWITH_CUDA=OFF
    -DWITH_FFMPEG=OFF
    -DWITH_TBB=OFF
    -DWITH_GSTREAMER=OFF
)
cmake -S "$OPENCV_SRC" -B "$BUILD_DIR" "${cmake_flags[@]}"

# do the real work
cmake --build "$BUILD_DIR" --target opencv_java -j"$JOBS"

# validate
SO_SRC=$(find "$BUILD_DIR" -name "libopencv_java4.so" | head -n1)
if [[ -z "$SO_SRC" ]]; then
    echo "ERROR: libopencv_java4.so not found under $BUILD_DIR" >&2
    exit 1
fi

# stage
NATIVE_LIBS="${OUTPUT_DIR}/sdk/native/libs/${ABI}"
mkdir -p "$NATIVE_LIBS"
cp "$SO_SRC" "${NATIVE_LIBS}/libopencv_java4.so"
