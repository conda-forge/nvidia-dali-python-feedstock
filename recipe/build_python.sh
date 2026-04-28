#!/bin/bash
set -ex

[[ ${target_platform} == "linux-64" ]]      && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
# https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html?highlight=tegra#cross-compilation
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type:-"sbsa"} == "sbsa" ]]   && targetsDir="targets/sbsa-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type:-"sbsa"} == "tegra" ]]  && targetsDir="targets/aarch64-linux"

if [ -z "${targetsDir+x}" ]; then
    echo "target_platform: ${target_platform} is unknown! targetsDir must be defined!" >&2
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

# Remove pip-install-time requirements that conda manages separately
sed -i "s/@DALI_INSTALL_REQUIRES_NVCOMP@//g"      dali/python/setup.py.in
sed -i "s/@DALI_INSTALL_REQUIRES_NVIMGCODEC@//g"  dali/python/setup.py.in
sed -i "s/@DALI_INSTALL_REQUIRES_NVJPEG2K@//g"    dali/python/setup.py.in
sed -i "s/@DALI_INSTALL_REQUIRES_NVTIFF@//g"      dali/python/setup.py.in

mkdir -p build_python
cd build_python

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
  -DWITH_DYNAMIC_NVCOMP=ON
  -DWITH_DYNAMIC_NVJPEG=ON
  -DSTATIC_LIBS=OFF
  # BLD: Use CUDA target include directory to support cross-compiling
  -DCUDAToolkit_TARGET_DIR="${PREFIX}/${targetsDir}"
)

# Debug with fewer archs for shorter build times
# export CUDAARCHS="50"
if [[ "${arm_variant_type:-}" == "tegra" ]]; then
  export CUDAARCHS="87-real;101f-real;101-virtual"
else
  export CUDAARCHS="all-major"
fi

# https://docs.nvidia.com/deeplearning/dali/user-guide/docs/compilation.html#optional-cmake-build-parameters
# -DCUDA_TARGET_ARCHS="$CUDAARCHS" \
cmake ${CMAKE_ARGS} \
  -GNinja \
  -DBUILD_PYTHON=ON \
  -DPREBUILD_DALI_LIBS=ON \
  -DPYTHON_VERSIONS=${PY_VER} \
  -DBUILD_AWSSDK=ON \
  -DBUILD_BENCHMARK=OFF \
  -DBUILD_CFITSIO=ON \
  -DBUILD_CUFILE=ON \
  -DBUILD_CVCUDA=OFF \
  -DBUILD_FFMPEG=ON \
  -DBUILD_FFTS=ON \
  -DBUILD_JPEG_TURBO=ON \
  -DBUILD_LIBSND=ON \
  -DBUILD_LIBTAR=ON \
  -DBUILD_LIBTIFF=ON \
  -DBUILD_LMDB=ON \
  -DBUILD_NVCOMP=$( [[ "${arm_variant_type:-}" == "tegra" ]] && echo "OFF" || echo "ON" ) \
  -DBUILD_NVDEC=ON \
  -DBUILD_NVIMAGECODEC=ON \
  -DBUILD_NVJPEG=ON \
  -DBUILD_NVJPEG2K=ON \
  -DBUILD_NVML=ON \
  -DBUILD_NVOF=ON \
  -DBUILD_NVTX=ON \
  -DBUILD_OPENCV=ON \
  -DBUILD_TEST=OFF \
  -DBUILD_WITH_ASAN=OFF \
  -DBUILD_WITH_LSAN=OFF \
  -DBUILD_WITH_UBSAN=OFF \
  -DUSE_PREBUILD_PYBIND11=ON \
  -DFFMPEG_ROOT_DIR=$PREFIX \
  -DNVCOMP_ROOT_DIR=$PREFIX \
  "${DALI_LINKING_ARGS[@]}" \
  $SRC_DIR

# Build the python bindings
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "" ]]; then
    echo "Building for the same platform, building dali_python_generate_stubs"
    cmake --build . -t dali_python python_function_plugin copy_post_build_target dali_python_generate_stubs install_headers
  else
    echo "Cross-compiling, skipping dali_python_generate_stubs as it requires running the python interpreter and importing DALI"
    cmake --build . -t dali_python python_function_plugin copy_post_build_target install_headers
fi

cd dali/python
${PYTHON} -m pip install .

# libdali owns the native headers; keep them out of the Python output.
rm -rf "${SP_DIR}"/nvidia/dali/include
rm -rf "${PREFIX}"/lib/gdk*

# When cross-compiling, Python extension modules are named for the build arch;
# rename them to match the target arch.
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "" ]]; then
  build_arch="${build_platform/linux-/}"
  target_arch="${target_platform/linux-/}"
  for file in "${SP_DIR}"/nvidia/dali/*cpython-*-"${build_arch}"-linux-gnu.so; do
    [[ -e "$file" ]] || continue
    newname="${file/${build_arch}/${target_arch}}"
    mv "$file" "$newname"
    echo "Renamed: $file -> $newname"
  done
fi

# Sanity-check that binaries target the correct architecture
so_files=("${SP_DIR}"/nvidia/dali/*.so)
if [[ ${#so_files[@]} -gt 0 && -e "${so_files[0]}" ]]; then
    file "${so_files[@]}"
fi
