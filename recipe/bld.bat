
mkdir third_party\boost\preprocessor\include
mklink /D third_party\boost\preprocessor\include\boost %PREFIX%\Library\include\boost

mkdir third_party\dlpack\include
mklink /D third_party\dlpack\include\dlpack %PREFIX%\Library\include\dlpack

mkdir third_party\cutlass\include
mklink /D third_party\cutlass\include\cute %PREFIX%\Library\include\cute
mklink /D third_party\cutlass\include\cutlass %PREFIX%\Library\include\cutlass

:: set CXXFLAGS=%CXXFLAGS% -isystem %PREFIX%\include\opencv4

powershell -Command "(Get-Content dali\python\setup.py.in) -replace '@DALI_INSTALL_REQUIRES_NVJPEG2K@', '' | Set-Content dali\python\setup.py.in"
powershell -Command "(Get-Content dali\python\setup.py.in) -replace '@DALI_INSTALL_REQUIRES_NVTIFF@', '' | Set-Content dali\python\setup.py.in"
powershell -Command "(Get-Content dali\python\setup.py.in) -replace '@DALI_INSTALL_REQUIRES_NVIMGCODEC@', '' | Set-Content dali\python\setup.py.in"

mkdir build
cd build

set DALI_LINKING_ARGS=-DLINK_DRIVER=OFF -DWITH_DYNAMIC_NVIMGCODEC=ON -DNVIMGCODEC_DEFAULT_INSTALL_PATH=%PREFIX%\Library -DWITH_DYNAMIC_CUDA_TOOLKIT=OFF -DWITH_DYNAMIC_CUFFT=OFF -DWITH_DYNAMIC_NPP=OFF -DWITH_DYNAMIC_NVJPEG=OFF -DSTATIC_LIBS=OFF

:: FIXME: CMake uses wrong prefix for cufile.h
:: https://docs.nvidia.com/deeplearning/dali/user-guide/docs/compilation.html#optional-cmake-build-parameters
cmake %CMAKE_ARGS% ^
  -GNinja ^
  -DBUILD_PYTHON=ON ^
  -DPYTHON_VERSIONS=%PY_VER% ^
  -DBUILD_BENCHMARK=OFF ^
  -DBUILD_CFITSIO=ON ^
  -DBUILD_CUFILE=OFF ^
  -DBUILD_CVCUDA=OFF ^
  -DBUILD_FFMPEG=OFF ^
  -DBUILD_FFTS=OFF ^
  -DBUILD_JPEG_TURBO=ON ^
  -DBUILD_LIBSND=OFF ^
  -DBUILD_LIBTAR=OFF ^
  -DBUILD_LIBTIFF=ON ^
  -DBUILD_LMDB=OFF ^
  -DBUILD_NVDEC=OFF ^
  -DBUILD_NVIMAGECODEC=ON ^
  -DBUILD_NVJPEG=ON ^
  -DBUILD_NVJPEG2K=ON ^
  -DBUILD_NVML=OFF ^
  -DBUILD_NVOF=OFF ^
  -DBUILD_NVTX=OFF ^
  -DBUILD_OPENCV=ON ^
  -DBUILD_TEST=OFF ^
  -DBUILD_WITH_ASAN=OFF ^
  -DBUILD_WITH_LSAN=OFF ^
  -DBUILD_WITH_UBSAN=OFF ^
  -DCUDA_TARGET_ARCHS=%CUDAARCHS% ^
  -DFFMPEG_ROOT_DIR=%PREFIX% ^
  %DALI_LINKING_ARGS% ^
  %SRC_DIR%

cmake --build . -j 4

cd dali\python
%PYTHON% -m pip install .

rmdir /S /Q %SP_DIR%\nvidia\dali\include\boost
