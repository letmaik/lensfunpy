#!/bin/bash
set -e -x

source .github/scripts/retry.sh

CHECK_SHA256=.github/scripts/check_sha256.sh

brew install pkg-config meson

# General note:
# Apple guarantees forward, but not backward ABI compatibility unless
# the deployment target is set for the oldest supported OS. 
# (https://trac.macports.org/ticket/54332#comment:2)

# Used by CMake, clang, and Python's distutils
export MACOSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION

# The Python variant to install, see exception below.
export PYTHON_INSTALLER_MACOS_VERSION=$MACOS_MIN_VERSION

# Install Python
# Note: The GitHub Actions supplied Python versions are not used
# as they are built without MACOSX_DEPLOYMENT_TARGET/-mmacosx-version-min
# being set to an older target for widest wheel compatibility.
# Instead we install python.org binaries which are built with 10.6/10.9 target
# and hence provide wider compatibility for the wheels we create.
# See https://github.com/actions/setup-python/issues/26.
git clone https://github.com/multi-build/multibuild.git
pushd multibuild
set +x # reduce noise
source osx_utils.sh
get_macpython_environment $PYTHON_VERSION venv $PYTHON_INSTALLER_MACOS_VERSION
source venv/bin/activate
set -x
popd

# Install dependencies
retry pip install numpy==$NUMPY_VERSION cython wheel delocate setuptools packaging

# List installed packages
pip freeze

# Shared library dependencies are built from source to respect MACOSX_DEPLOYMENT_TARGET.
# Bottles from Homebrew cannot be used as they always have a target that
# matches the host OS. Unfortunately, building from source with Homebrew
# is also not an option as the MACOSX_DEPLOYMENT_TARGET env var cannot
# be forwarded to the build (Homebrew cleans the environment).
# See https://discourse.brew.sh/t/it-is-possible-to-build-packages-that-are-compatible-with-older-macos-versions/4421

LIB_INSTALL_PREFIX=$(pwd)/external/libs
export CMAKE_PREFIX_PATH=$LIB_INSTALL_PREFIX
export PKG_CONFIG_PATH=$LIB_INSTALL_PREFIX/lib/pkgconfig
export LIBRARY_PATH=$LIB_INSTALL_PREFIX/lib
export PATH=$LIB_INSTALL_PREFIX/bin:$PATH

# Install libffi (glib dependency)
curl -L --retry 3 -o libffi.tar.gz https://sourceware.org/pub/libffi/libffi-3.4.3.tar.gz
$CHECK_SHA256 libffi.tar.gz 4416dd92b6ae8fcb5b10421e711c4d3cb31203d77521a77d85d0102311e6c3b8
tar xzf libffi.tar.gz
pushd libffi-3.4.3
./configure --prefix=$LIB_INSTALL_PREFIX --disable-debug
make install -j
popd

# Install gettext (glib dependency)
curl -L --retry 3 -o gettext.tar.xz https://ftp.gnu.org/gnu/gettext/gettext-0.22.4.tar.xz
$CHECK_SHA256 gettext.tar.xz 29217f1816ee2e777fa9a01f9956a14139c0c23cc1b20368f06b2888e8a34116
tar xzf gettext.tar.xz
pushd gettext-0.22.4
./configure --prefix=$LIB_INSTALL_PREFIX \
    --disable-debug \
    --disable-java --disable-csharp \
    --without-git --without-cvs --without-xz
make -j
make install
popd

# Install packaging into system python (used by meson in glib build)
python3 -m pip install packaging

# Install glib (lensfun dependency)
curl -L --retry 3 -o glib.tar.xz https://download.gnome.org/sources/glib/2.79/glib-2.79.1.tar.xz
$CHECK_SHA256 glib.tar.xz b3764dd6e29b664085921dd4dd6ba2430fc19760ab6857ecfa3ebd4e8c1d114c
tar xzf glib.tar.xz
pushd glib-2.79.1
mkdir build
cd build
meson --prefix=$LIB_INSTALL_PREFIX \
  -Dselinux=disabled \
  -Ddtrace=false \
  -Dman=false \
  -Dgtk_doc=false \
  ..
ninja install
popd

ls -al $LIB_INSTALL_PREFIX/lib
ls -al $LIB_INSTALL_PREFIX/lib/pkgconfig

# By default, wheels are tagged with the architecture of the Python
# installation, which would produce universal2 even if only building
# for x86_64. The following line overrides that behavior.
export _PYTHON_HOST_PLATFORM="macosx-${MACOS_MIN_VERSION}-${PYTHON_ARCH}"

export CC=clang
export CXX=clang++
export CFLAGS="-arch ${PYTHON_ARCH}"
export CXXFLAGS=$CFLAGS
export LDFLAGS=$CFLAGS
export ARCHFLAGS=$CFLAGS

# Build wheel
python setup.py bdist_wheel

# List direct and indirect library dependencies
mkdir tmp_wheel
pushd tmp_wheel
unzip ../dist/*.whl
python ../.github/scripts/otooltree.py lensfunpy/*.so
popd
rm -rf tmp_wheel

delocate-listdeps --all dist/*.whl # lists direct library dependencies
delocate-wheel --require-archs=${PYTHON_ARCH} dist/*.whl # copies library dependencies into wheel
delocate-listdeps --all dist/*.whl # verify

# Dump target versions of dependend libraries.
# Currently, delocate does not support checking those.
# See https://github.com/matthew-brett/delocate/issues/56.
set +x # reduce noise
echo "Dumping LC_VERSION_MIN_MACOSX (pre-10.14) & LC_BUILD_VERSION"
mkdir tmp_wheel
pushd tmp_wheel
unzip ../dist/*.whl
echo lensfunpy/*.so
otool -l lensfunpy/*.so | grep -A 3 LC_VERSION_MIN_MACOSX || true
otool -l lensfunpy/*.so | grep -A 4 LC_BUILD_VERSION || true
for file in lensfunpy/.dylibs/*.dylib; do
    echo $file
    otool -l $file | grep -A 3 LC_VERSION_MIN_MACOSX || true
    otool -l $file | grep -A 4 LC_BUILD_VERSION || true
done
popd
set -x

# Install lensfunpy
pip install dist/*.whl

# Test installed lensfunpy
retry pip install numpy -U # scipy should trigger an update, but that doesn't happen
retry pip install -r dev-requirements.txt
# make sure it's working without any required libraries installed
rm -rf $LIB_INSTALL_PREFIX
mkdir tmp_for_test
pushd tmp_for_test
pytest --verbosity=3 -s ../test
popd
