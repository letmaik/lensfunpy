from __future__ import print_function

from setuptools import setup, Extension, find_packages
import numpy
import subprocess
import errno
import os
import shutil
import sys
import zipfile
try:
    # Python 3
    from urllib.request import urlretrieve
except ImportError:
    # Python 2
    from urllib import urlretrieve

isWindows = os.name == 'nt'
is64Bit = sys.maxsize > 2**32

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

            sysroot = sysroot and os.environ.get('PKG_CONFIG_SYSROOT_DIR', '')
            if sysroot:
                # old versions of pkg-config don't support this env var,
                # so here we emulate its effect if needed
                res = [path if path.startswith(sysroot)
                            else sysroot + path
                         for path in res]
            resultlist[:] = res

def use_pkg_config():
    _ask_pkg_config(include_dirs,       '--cflags-only-I', '-I', sysroot=True)
    _ask_pkg_config(extra_compile_args, '--cflags-only-other')
    _ask_pkg_config(library_dirs,       '--libs-only-L', '-L', sysroot=True)
    _ask_pkg_config(extra_link_args,    '--libs-only-other')
    _ask_pkg_config(libraries,          '--libs-only-l', '-l')

include_dirs += [numpy.get_include()]

if isWindows:
    cmake_build = 'external/lensfun/cmake_build'
    lensfunh_dir = os.path.join(cmake_build)
    lensfunlib_dir = os.path.join(cmake_build, 'libs', 'lensfun')
    
    include_dirs += ['external/stdint', lensfunh_dir]
    library_dirs += [lensfunlib_dir]
else:
    use_pkg_config()

def windows_lensfun_compile():
    # check that lensfun git submodule is cloned
    if not os.path.exists('external/lensfun/README'):
        print('lensfun git submodule is not cloned yet, will invoke "git submodule update --init" now')
        if os.system('git submodule update --init') != 0:
            raise Exception('git failed')
    
    # download glib2 and cmake to compile lensfun
    glib_dir = 'external/lensfun/glib-2.0'
    glib_arch = 'win64' if is64Bit else 'win32'
    glib_libs_url = 'http://win32builder.gnome.org/packages/3.6/glib_2.34.3-1_{}.zip'.format(glib_arch)
    glib_dev_url = 'http://win32builder.gnome.org/packages/3.6/glib-dev_2.34.3-1_{}.zip'.format(glib_arch)
    # lensfun uses glib2 functionality that requires libiconv and gettext as runtime libraries
    libiconv_url = 'http://win32builder.gnome.org/packages/3.6/libiconv_1.13.1-1_{}.zip'.format(glib_arch)
    gettext_url = 'http://win32builder.gnome.org/packages/3.6/gettext_0.18.2.1-1_{}.zip'.format(glib_arch)
    # the cmake zip contains a cmake-3.0.1-win32-x86 folder when extracted
    cmake_url = 'http://www.cmake.org/files/v3.0/cmake-3.0.1-win32-x86.zip'
    cmake = os.path.abspath('external/cmake-3.0.1-win32-x86/bin/cmake')
    files = [(glib_libs_url, 'glib_2.34.3-1.zip', glib_dir), 
             (glib_dev_url, 'glib-dev_2.34.3-1.zip', glib_dir),
             (libiconv_url, 'libiconv_1.13.1-1.zip', glib_dir),
             (gettext_url, 'gettext_0.18.2.1-1.zip', glib_dir),
             (cmake_url, 'cmake-3.0.1-win32-x86.zip', 'external')]
    for url, path, extractdir in files:
        if not os.path.exists(path):
            print('Downloading', url)
            urlretrieve(url, path)
        with zipfile.ZipFile(path) as z:
            print('Extracting', path, 'into', extractdir)
            z.extractall(extractdir)
    
    # configure and compile lensfun
    cwd = os.getcwd()
    if not os.path.exists(cmake_build):
        os.mkdir(cmake_build)
    os.chdir(cmake_build)
    # -DBUILD_STATIC=on
    cmds = [cmake + ' .. -G "NMake Makefiles" -DGLIB2_BASE_DIR=glib-2.0 -DBUILD_TESTS=off -DLENSFUN_INSTALL_PREFIX= ',
            'dir',
            'nmake'
            ]
    for cmd in cmds:
        print(cmd)
        if os.system(cmd) != 0:
            sys.exit()   
    os.chdir(cwd)
    
    # bundle runtime dlls
    glib_bin_dir = os.path.join(glib_dir, 'bin')
    dll_runtime_libs = [('lensfun.dll', 'external/lensfun/cmake_build/libs/lensfun'),
                        ('libglib-2.0-0.dll', glib_bin_dir),
                        ('libiconv-2.dll', glib_bin_dir),
                        ('libintl-8.dll', glib_bin_dir), # gettext
                        ]
    for filename, folder in dll_runtime_libs:
        src = os.path.join(folder, filename)
        dest = 'lensfunpy/' + filename
        print('copying', src, '->', dest)
        shutil.copyfile(src, dest)
    
    # bundle database xmls
    import glob
    db_files = 'lensfunpy/db_files'
    if not os.path.exists(db_files):
        os.makedirs(db_files)
    for path in glob.glob('external/lensfun/data/db/*.xml'):
        dest = os.path.join(db_files, os.path.basename(path))
        print('copying', path, '->', dest)
        shutil.copyfile(path, dest)
    
package_data = {}

# evil hack, check cmd line for relevant commands
# custom cmdclasses didn't work out in this case
cmdline = ''.join(sys.argv[1:])
if isWindows and any(s in cmdline for s in ['bdist', 'build_ext', 'nosetests']):
    windows_lensfun_compile()
        
    package_data['lensfunpy'] = ['db_files/*.xml',
                                 '*.dll']
    
if any(s in cmdline for s in ['clean', 'sdist']):
    # When running sdist after a previous run of bdist or build_ext
    # then even with the 'clean' command the .egg-info folder stays.
    # This folder contains SOURCES.txt which in turn is used by sdist
    # to include package data files, but we don't want .dll's and .xml
    # files in our source distribution. Therefore, to prevent accidents,
    # we help a little...
    egg_info = 'lensfunpy.egg-info'
    print('removing', egg_info)
    shutil.rmtree(egg_info, ignore_errors=True)

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

setup(
      name = 'lensfunpy',
      version = '1.0.0',
      description = 'Python wrapper for the lensfun library',
      long_description = open('README.rst').read(),
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
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Topic :: Multimedia :: Graphics',
        'Topic :: Software Development :: Libraries',
      ),
      packages = find_packages(),
      ext_modules = extensions,
      package_data = package_data,
)
