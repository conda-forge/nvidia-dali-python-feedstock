#!/bin/bash

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
# Disable all dynamic (dlopen) linkages because we have patched the static links away
  -DWITH_DYNAMIC_CUDA_TOOLKIT=OFF
  -DWITH_DYNAMIC_CUFFT=OFF
  -DWITH_DYNAMIC_NPP=OFF
  -DWITH_DYNAMIC_NVJPEG=OFF
  -DSTATIC_LIBS=OFF
)

# https://docs.nvidia.com/deeplearning/dali/user-guide/docs/compilation.html#optional-cmake-build-parameters
cmake ${CMAKE_ARGS} \
  -GNinja \
  -DBUILD_PYTHON=ON \
  -DPYTHON_VERSIONS=${PY_VER} \
  -DBUILD_BENCHMARK=OFF \
  -DBUILD_CFITSIO=ON \
  -DBUILD_CUFILE=ON \
  -DBUILD_CVCUDA=OFF \
  -DBUILD_FFMPEG=OFF \
  -DBUILD_FFTS=OFF \
  -DBUILD_JPEG_TURBO=ON \
  -DBUILD_LIBSND=OFF \
  -DBUILD_LIBTAR=OFF \
  -DBUILD_LIBTIFF=ON \
  -DBUILD_LMDB=OFF \
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
${PYTHON} -m pip install .

rm ${SP_DIR}/nvidia/dali/include/boost -rf
