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

cmake ${CMAKE_ARGS} \
  -GNinja \
  -DBUILD_PYTHON=ON \
  -DBUILD_FFTS=OFF \
  -DBUILD_CVCUDA=OFF \
  -DBUILD_JPEG_TURBO=ON \
  -DBUILD_LIBTIFF=ON \
  -DBUILD_CFITSIO=ON \
  -DBUILD_BENCHMARK=OFF \
  -DBUILD_TEST=OFF \
  -DBUILD_OPENCV=ON \
  -DBUILD_LMDB=OFF \
  -DBUILD_LIBSND=OFF \
  -DBUILD_LIBTAR=OFF \
  -DBUILD_FFMPEG=OFF \
  -DBUILD_NVDEC=OFF \
  -DBUILD_NVIMAGECODEC=ON \
  -DWITH_DYNAMIC_CUFFT=ON \
  -DWITH_DYNAMIC_NPP=ON \
  -DWITH_DYNAMIC_NVIMGCODEC=ON \
  -DWITH_DYNAMIC_NVJPEG=ON \
  -DBUILD_NVML=OFF \
  -DBUILD_NVTX=OFF \
  -DPYTHON_VERSIONS=${PY_VER} \
  ..

cmake --build .
# FIXME: C-API is probably being shipped in python site-packages
# cmake --install . --strip -v

cd dali/python
${PYTHON} -m pip install .

rm ${SP_DIR}/nvidia/dali/include/boost -rf
