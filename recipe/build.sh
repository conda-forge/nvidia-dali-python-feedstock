#!/bin/bash
set -e

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
# https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html?highlight=tegra#cross-compilation
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type:-"sbsa"} == "sbsa" ]] && targetsDir="targets/sbsa-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type:-"sbsa"} == "tegra" ]] && targetsDir="targets/aarch64-linux"

if [ -z "${targetsDir+x}" ]; then
    echo "target_platform: ${target_platform} is unknown! targetsDir must be defined!" >&2
    exit 1
fi

if [[ ${cuda_compiler_version} == "11."* ]]; then
  CUDATOOLKIT_PREFIX_PATH=/usr/local/cuda-11.8
fi
if [[ ${cuda_compiler_version} == "12."* ]]; then
  CUDATOOLKIT_PREFIX_PATH=${PREFIX}
fi

if [ -z "${CUDATOOLKIT_PREFIX_PATH+x}" ]; then
    echo "cuda_compiler_version ${cuda_compiler_version} is unknown! CUDATOOLKIT_PREFIX_PATH must be defined!" >&2
    exit 1
fi

mkdir -p third_party/boost/preprocessor/include
ln -sf $PREFIX/include/boost third_party/boost/preprocessor/include/

mkdir -p third_party/dlpack/include/
ln -sf $PREFIX/include/dlpack third_party/dlpack/include/

mkdir -p third_party/cutlass/include/
ln -sf $PREFIX/include/cute    third_party/cutlass/include/
ln -sf $PREFIX/include/cutlass third_party/cutlass/include/

export CXXFLAGS="$CXXFLAGS -isystem $PREFIX/include/opencv4"

sed -i.bak "s/@DALI_INSTALL_REQUIRES_NVJPEG2K@//g" dali/python/setup.py.in
sed -i.bak "s/@DALI_INSTALL_REQUIRES_NVTIFF@//g" dali/python/setup.py.in
sed -i.bak "s/@DALI_INSTALL_REQUIRES_NVIMGCODEC@//g" dali/python/setup.py.in

mkdir -p build
cd build

DALI_LINKING_ARGS=(
  -DLINK_DRIVER=OFF
# Continue to dlopen nvimgcodec so that it can be optionally installed
  -DWITH_DYNAMIC_NVIMGCODEC=ON
  -DNVIMGCODEC_DEFAULT_INSTALL_PATH=${PREFIX}
# Enable all dynamic (dlopen) linkages because it lets us install DALI without CUDA
  -DWITH_DYNAMIC_CUDA_TOOLKIT=ON
# FFTS (third-party) needs to be available in order for cuFFT dlopen to work
  -DWITH_DYNAMIC_CUFFT=ON
  -DWITH_DYNAMIC_NPP=ON
  -DWITH_DYNAMIC_NVJPEG=ON
  -DSTATIC_LIBS=OFF
  # BLD: Use CUDA target include directory to support cross-compiling
  -DCUDAToolkit_TARGET_DIR="${CUDATOOLKIT_PREFIX_PATH}/${targetsDir}"
)

# Debug with fewer archs for shorter build times
# export CUDAARCHS="50"

# https://docs.nvidia.com/deeplearning/dali/user-guide/docs/compilation.html#optional-cmake-build-parameters
cmake ${CMAKE_ARGS} \
  -GNinja \
  -DBUILD_PYTHON=ON \
  -DPYTHON_VERSIONS=${PY_VER} \
  -DBUILD_AWSSDK=ON \
  -DBUILD_BENCHMARK=OFF \
  -DBUILD_CFITSIO=ON \
  -DBUILD_CUFILE=ON \
  -DBUILD_CVCUDA=OFF \
  -DBUILD_FFMPEG=OFF \
  -DBUILD_FFTS=ON \
  -DBUILD_JPEG_TURBO=ON \
  -DBUILD_LIBSND=ON \
  -DBUILD_LIBTAR=ON \
  -DBUILD_LIBTIFF=ON \
  -DBUILD_LMDB=ON \
  -DBUILD_NVDEC=OFF \
  -DBUILD_NVIMAGECODEC=ON \
  -DBUILD_NVJPEG=ON \
  -DBUILD_NVJPEG2K=ON \
  -DBUILD_NVML=OFF \
  -DBUILD_NVOF=OFF \
  -DBUILD_NVTX=OFF \
  -DBUILD_OPENCV=ON \
  -DBUILD_TEST=OFF \
  -DBUILD_WITH_ASAN=OFF \
  -DBUILD_WITH_LSAN=OFF \
  -DBUILD_WITH_UBSAN=OFF \
  -DCUDA_TARGET_ARCHS="$CUDAARCHS" \
  -DFFMPEG_ROOT_DIR=$PREFIX \
  "${DALI_LINKING_ARGS[@]}" \
  $SRC_DIR

cmake --build .
# FIXME: C-API is probably being shipped in python site-packages
# cmake --install . --strip -v

cd dali/python
${PYTHON} -m pip install . -v

rm ${SP_DIR}/nvidia/dali/include/boost -rf
rm ${PREFIX}/lib/gdk* -rf

# When cross-compiling, the python modules are named incorrectly, so we have to
# fix the name.
if [[ "$target_platform" != "$build_platform" ]]; then
  for file in "${SP_DIR}"/nvidia/dali/*cpython-*-x86_64-linux-gnu.so; do
    newname="${file/x86_64/aarch64}"
    mv "$file" "$newname"
    echo "Renamed: $file → $newname"
  done
fi

# Just double checking that binaries target correct arch
file ${SP_DIR}/nvidia/dali/*.so
