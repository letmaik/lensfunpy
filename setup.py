from setuptools import setup, Extension, find_packages
import numpy
import subprocess
import errno
import os
import shutil
import sys
import urllib
import zipfile

isWindows = os.name == 'nt'
is64Bit = sys.maxsize > 2**32

if isWindows:
    # download glib2 and cmake to compile lensfun
    glib_dir = 'external/lensfun/glib-2.0'
    glib_arch = 'win64' if is64Bit else 'win32'
    glib_libs_url = 'http://win32builder.gnome.org/packages/3.6/glib_2.34.3-1_{}.zip'.format(glib_arch)
    glib_dev_url = 'http://win32builder.gnome.org/packages/3.6/glib-dev_2.34.3-1_{}.zip'.format(glib_arch)
    # the cmake zip contains a cmake-3.0.1-win32-x86 folder when extracted
    cmake_url = 'http://www.cmake.org/files/v3.0/cmake-3.0.1-win32-x86.zip'
    cmake = os.path.abspath('external/cmake-3.0.1-win32-x86/bin/cmake')
    files = [(glib_libs_url, 'glib_2.34.3-1.zip', glib_dir), 
                  (glib_dev_url, 'glib-dev_2.34.3-1.zip', glib_dir),
                  (cmake_url, 'cmake-3.0.1-win32-x86.zip', 'external')]
    for url, path, extractdir in files:
        if os.path.exists(path):
            continue
        print 'Downloading {}'.format(url)
        urllib.urlretrieve(url, path)
        with zipfile.ZipFile(path) as z:
            z.extractall(extractdir)
            
    # configure and compile lensfun
    cwd = os.getcwd()
    cmake_build = 'external/lensfun/cmake_build'
    if not os.path.exists(cmake_build):
        os.mkdir(cmake_build)
    os.chdir(cmake_build)
    # -DBUILD_STATIC=on
    cmds = [cmake + ' .. -DGLIB2_BASE_DIR=glib-2.0 -DBUILD_TESTS=off -DLENSFUN_INSTALL_PREFIX= ',
            'dir',
            'nmake /F ' + os.path.join(cmake_build, 'Makefile')
            ]
    for cmd in cmds:
        print cmd
        if os.system(cmd) != 0:
            sys.exit()   
    os.chdir(cwd)
    
    lensfunh_dir = os.path.join(cmake_build)
    lensfunlib_dir = os.path.join(cmake_build, 'libs', 'lensfun')

# adapted from cffi's setup.py
# the following may be overridden if pkg-config exists
libraries = ['lensfun']
include_dirs = []
library_dirs = []
extra_compile_args = []
extra_link_args = []

def _ask_pkg_config(resultlist, option, result_prefix='', sysroot=False):
    pkg_config = os.environ.get('PKG_CONFIG','pkg-config')
    try:
        p = subprocess.Popen([pkg_config, option, 'lensfun'],
                             stdout=subprocess.PIPE)
    except OSError as e:
        if e.errno != errno.ENOENT:
            raise
    else:
        t = p.stdout.read().decode().strip()
        if p.wait() == 0:
            res = t.split()
            # '-I/usr/...' -> '/usr/...'
            for x in res:
                assert x.startswith(result_prefix)
            res = [x[len(result_prefix):] for x in res]
#            print 'PKG_CONFIG:', option, res
            #
            sysroot = sysroot and os.environ.get('PKG_CONFIG_SYSROOT_DIR', '')
            if sysroot:
                # old versions of pkg-config don't support this env var,
                # so here we emulate its effect if needed
                res = [path if path.startswith(sysroot)
                            else sysroot + path
                         for path in res]
            #
            resultlist[:] = res

def use_pkg_config():
    _ask_pkg_config(include_dirs,       '--cflags-only-I', '-I', sysroot=True)
    _ask_pkg_config(extra_compile_args, '--cflags-only-other')
    _ask_pkg_config(library_dirs,       '--libs-only-L', '-L', sysroot=True)
    _ask_pkg_config(extra_link_args,    '--libs-only-other')
    _ask_pkg_config(libraries,          '--libs-only-l', '-l')

if isWindows:
    include_dirs += ['external/stdint', 
                     lensfunh_dir]
    library_dirs += [lensfunlib_dir]
else:
    use_pkg_config()

include_dirs += [numpy.get_include()]

try:
    from Cython.Build import cythonize
except ImportError:
    use_cython = False
else:
    use_cython = True

ext = '.pyx' if use_cython else '.c'

extensions = [Extension("lensfunpy._lensfun",
              include_dirs=include_dirs,
              sources=['_lensfun' + ext],
              libraries=libraries,
              library_dirs=library_dirs,
              extra_compile_args=extra_compile_args,
              extra_link_args=extra_link_args,
             )]

if use_cython:    
    extensions = cythonize(extensions)

def read(fname):
    with open(fname) as fp:
        content = fp.read()
    return content

if isWindows:
    shutil.copyfile('external/lensfun/cmake_build/libs/lensfun/lensfun.dll', 'lensfunpy/lensfun.dll')
    package_data = {'lensfunpy': ['lensfun.dll']}
else:
    package_data = {}

setup(
      name = 'lensfunpy',
      version = '0.12.0',
      description = 'Python wrapper for the lensfun library',
      long_description = read('README.rst'),
      author = 'Maik Riechert',
      author_email = 'maik.riechert@arcor.de',
      url = 'https://github.com/neothemachine/lensfunpy',
      classifiers=(
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Cython',
        'Programming Language :: Python',
        'Topic :: Multimedia :: Graphics',
        'Topic :: Software Development :: Libraries',
      ),
      packages = find_packages(),
      ext_modules = extensions,
      package_data = package_data,
      # FIXME data files get installed in python root
      data_files = [('', ['_lensfun.pyx', 'README.rst'])],
)
