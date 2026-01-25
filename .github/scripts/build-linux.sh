#!/bin/bash
set -e -x

cd /io

source .github/scripts/retry.sh

# List python versions
ls /opt/python

# Compute PYBIN from PYTHON_VERSION (e.g., "3.14" -> "cp314-cp314")
PYVER_NO_DOT=${PYTHON_VERSION//./}
PYBIN="/opt/python/cp${PYVER_NO_DOT}-cp${PYVER_NO_DOT}/bin"

if [ ! -d "$PYBIN" ]; then
    echo "Python version $PYTHON_VERSION not found at $PYBIN"
    exit 1
fi

# Install liblensfun
pushd external/lensfun
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=off -DINSTALL_HELPER_SCRIPTS=off -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .
make
make install -j$(nproc)
echo "/usr/local/lib64" | tee /etc/ld.so.conf.d/99local.conf
ldconfig
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
popd

# Install numpy/scipy deps
retry dnf install -y lapack-devel blas-devel

# Upgrade pip and prefer binary packages
${PYBIN}/python -m pip install --upgrade pip
export PIP_PREFER_BINARY=1

# install compile-time dependencies
retry ${PYBIN}/pip install numpy==${NUMPY_VERSION} cython

# List installed packages
${PYBIN}/pip freeze

# Build lensfunpy wheel
rm -rf wheelhouse
retry ${PYBIN}/pip wheel . -w wheelhouse

# Bundle external shared libraries into wheel
auditwheel repair wheelhouse/lensfunpy*.whl -w wheelhouse

# Install package and test
${PYBIN}/pip install lensfunpy --no-index -f wheelhouse

retry ${PYBIN}/pip install -r dev-requirements.txt
retry ${PYBIN}/pip install -U numpy # scipy should trigger an update, but that doesn't happen

pushd $HOME
${PYBIN}/pytest --verbosity=3 -s /io/test
popd

# Move wheel to dist/ folder for easier deployment
mkdir -p dist
mv wheelhouse/lensfunpy*manylinux*.whl dist/
