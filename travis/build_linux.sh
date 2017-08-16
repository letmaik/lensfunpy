#!/bin/bash
set -e -x

bash --version

cd /io

source travis/travis_retry.sh

# List python versions
ls /opt/python

PYBINS=(
  "/opt/python/cp27-cp27mu/bin"
  "/opt/python/cp34-cp34m/bin"
  "/opt/python/cp35-cp35m/bin"
  "/opt/python/cp36-cp36m/bin"
  )

# Install build tools
travis_retry yum install -y cmake28 # CentOS cmake is 2.6, we need >= 2.8 which is available from EPEL as cmake28
ln -s /usr/bin/cmake28 /usr/bin/cmake

# Install liblensfun
pushd external/lensfun
cmake . -DBUILD_TESTS=off
make install
echo "/usr/local/lib" | tee /etc/ld.so.conf.d/99local.conf
ldconfig
popd

# Install numpy/scipy deps
travis_retry yum install -y lapack-devel blas-devel

# Build lensfunpy wheels
for PYBIN in ${PYBINS[@]}; do
    case ${PYBIN} in
        *27*) NUMPY_VERSION="1.7.2";;
        *34*) NUMPY_VERSION="1.8.*";;
        *35*) NUMPY_VERSION="1.9.*";;
        *36*) NUMPY_VERSION="1.11.*";;
    esac

    # install compile-time dependencies
    travis_retry ${PYBIN}/pip install numpy==${NUMPY_VERSION} cython

    travis_retry ${PYBIN}/pip wheel . -w wheelhouse -v
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/lensfunpy*.whl; do
    auditwheel repair $whl -w wheelhouse
done

# Build sdist
${PYBINS[0]}/python setup.py sdist

# Install packages and test
for PYBIN in ${PYBINS[@]}; do
    ${PYBIN}/pip install lensfunpy --no-index -f wheelhouse

    travis_retry ${PYBIN}/pip install -r dev-requirements.txt
    travis_retry ${PYBIN}/pip install numpy -U # scipy should trigger an update, but that doesn't happen

    (cd $HOME; ${PYBIN}/nosetests --verbosity=3 --nocapture /io/test)
done

# Move wheels to dist/ folder for easier deployment
mv wheelhouse/lensfunpy*manylinux1*.whl dist/

# deploy if git tag
# make first python available so that the deploy script can use twine
export PATH=${PYBINS[0]}:$PATH
travis/deploy_pypi.sh