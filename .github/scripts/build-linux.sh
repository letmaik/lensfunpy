#!/bin/bash
set -e -x

bash --version

cd /io

source .github/scripts/retry.sh

# List python versions
ls /opt/python

if [ $PYTHON_VERSION == "3.5" ]; then
    PYBIN="/opt/python/cp35-cp35m/bin"
elif [ $PYTHON_VERSION == "3.6" ]; then
    PYBIN="/opt/python/cp36-cp36m/bin"
elif [ $PYTHON_VERSION == "3.7" ]; then
    PYBIN="/opt/python/cp37-cp37m/bin"
else
    echo "Unsupported Python version $PYTHON_VERSION"
    exit 1
fi

# Install build tools
retry yum install -y cmake

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
${PYBIN}/nosetests --verbosity=3 --nocapture /io/test
popd

# Move wheel to dist/ folder for easier deployment
mkdir -p dist
mv wheelhouse/lensfunpy*manylinux2010*.whl dist/
