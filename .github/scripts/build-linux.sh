#!/bin/bash
set -e -x

cd /io

source .github/scripts/retry.sh

# List python versions
ls /opt/python

if [ $PYTHON_VERSION == "3.7" ]; then
    PYBIN="/opt/python/cp37-cp37m/bin"
elif [ $PYTHON_VERSION == "3.8" ]; then
    PYBIN="/opt/python/cp38-cp38/bin"
elif [ $PYTHON_VERSION == "3.9" ]; then
    PYBIN="/opt/python/cp39-cp39/bin"
elif [ $PYTHON_VERSION == "3.10" ]; then
    PYBIN="/opt/python/cp310-cp310/bin"
elif [ $PYTHON_VERSION == "3.11" ]; then
    PYBIN="/opt/python/cp311-cp311/bin"
else
    echo "Unsupported Python version $PYTHON_VERSION"
    exit 1
fi

# Install liblensfun
pushd external/lensfun
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=off -DINSTALL_HELPER_SCRIPTS=off .
make
make install -j$(nproc)
echo "/usr/local/lib64" | tee /etc/ld.so.conf.d/99local.conf
ldconfig
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
popd

# Install numpy/scipy deps
retry yum install -y lapack-devel blas-devel

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
