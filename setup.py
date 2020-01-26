from setuptools import setup, Extension, find_packages
import subprocess
import errno
import re
import os
import shutil
import sys
import zipfile
from urllib.request import urlretrieve

import numpy
from Cython.Build import cythonize
   
isWindows = os.name == 'nt'
isMac = sys.platform == 'darwin'
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

if isWindows or isMac:
    cmake_build = os.path.abspath('external/lensfun/build')
    install_dir = os.path.join(cmake_build, 'install')
    
    include_dirs += [os.path.join(install_dir, 'include', 'lensfun')]
    library_dirs += [os.path.join(install_dir, 'lib')]
else:
    use_pkg_config()
    
# this must be after use_pkg_config()!
include_dirs += [numpy.get_include()]

# for version_helper.h
include_dirs += [os.path.abspath('lensfunpy')]

def clone_submodules():
    if not os.path.exists('external/lensfun/README.md'):
        print('lensfun git submodule not cloned yet, will invoke "git submodule update --init" now')
        if os.system('git submodule update --init') != 0:
            raise Exception('git failed')

def windows_lensfun_compile():
    clone_submodules()

    cwd = os.getcwd()
    
    # Download cmake to build lensfun
    cmake_version = '3.13.4'
    cmake_url = 'https://github.com/Kitware/CMake/releases/download/v{v}/cmake-{v}-win32-x86.zip'.format(v=cmake_version)
    cmake = os.path.abspath('external/cmake-{}-win32-x86/bin/cmake.exe'.format(cmake_version))

    # Download vcpkg to build dependencies of lensfun
    vcpkg_commit = 'd82f37b4bfc1422d4601fbb63cbd553c925f7014'
    vcpkg_url = 'https://github.com/Microsoft/vcpkg/archive/{}.zip'.format(vcpkg_commit)
    vcpkg_dir = os.path.abspath('external/vcpkg-{}'.format(vcpkg_commit))
    vcpkg_bootstrap = os.path.join(vcpkg_dir, 'bootstrap-vcpkg.bat')
    vcpkg = os.path.join(vcpkg_dir, 'vcpkg.exe')
    
    files = [(cmake_url, 'external', cmake),
             (vcpkg_url, 'external', vcpkg_bootstrap)]

    for url, extractdir, extractcheck in files:
        if not os.path.exists(extractcheck):
            path = 'external/' + os.path.basename(url)
            if not os.path.exists(path):
                print('Downloading', url)
                try:
                    urlretrieve(url, path)
                except:
                    # repeat once in case of network issues
                    urlretrieve(url, path)
        
            with zipfile.ZipFile(path) as z:
                print('Extracting', path, 'into', extractdir)
                z.extractall(extractdir)
                
            if not os.path.exists(path):
                raise RuntimeError(path + ' not found!')

    # Bootstrap vcpkg
    os.chdir(vcpkg_dir)
    if not os.path.exists(vcpkg):
        code = os.system(vcpkg_bootstrap)
        if code != 0:
            sys.exit(code) 

    # lensfun depends on glib2, so let's build it with vcpkg
    vcpkg_arch = 'x64' if is64Bit else 'x86'
    vcpkg_triplet = '{}-windows'.format(vcpkg_arch)
    code = os.system(vcpkg + ' install glib:' + vcpkg_triplet)
    if code != 0:
        sys.exit(code)
    vcpkg_install_dir = os.path.join(vcpkg_dir, 'installed', vcpkg_triplet)
    
    # configure and compile lensfun
    if not os.path.exists(cmake_build):
        os.mkdir(cmake_build)
    os.chdir(cmake_build)
    cmds = [cmake + ' .. -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release ' +\
                    '-DBUILD_TESTS=off -DINSTALL_HELPER_SCRIPTS=off ' +\
                    '-DCMAKE_TOOLCHAIN_FILE={}/scripts/buildsystems/vcpkg.cmake '.format(vcpkg_dir) +\
                    '-DGLIB2_BASE_DIR={} -DCMAKE_INSTALL_PREFIX=install'.format(vcpkg_install_dir),
            cmake + ' --build .',
            cmake + ' --build . --target install',
            ]
    for cmd in cmds:
        print(cmd)
        code = os.system(cmd)
        if code != 0:
            sys.exit(code) 
    os.chdir(cwd)
    
    # bundle runtime dlls
    vcpkg_bin_dir = os.path.join(vcpkg_install_dir, 'bin')

    dll_runtime_libs = [('lensfun.dll', os.path.join(install_dir, 'bin')),
                        ('glib-2.dll', vcpkg_bin_dir),
                        # dependencies of glib
                        ('pcre.dll', vcpkg_bin_dir),
                        ('libiconv.dll', vcpkg_bin_dir),
                        ('libcharset.dll', vcpkg_bin_dir),
                        ('libintl.dll', vcpkg_bin_dir),
                        ]
    
    for filename, folder in dll_runtime_libs:
        src = os.path.join(folder, filename)
        dest = 'lensfunpy/' + filename
        print('copying', src, '->', dest)
        shutil.copyfile(src, dest)


def mac_lensfun_compile():
    clone_submodules()
        
    # configure and compile lensfun
    cwd = os.getcwd()
    if not os.path.exists(cmake_build):
        os.mkdir(cmake_build)
    os.chdir(cmake_build)
    install_name_dir = os.path.join(install_dir, 'lib')
    cmds = ['cmake .. -DCMAKE_BUILD_TYPE=Release ' +\
                    '-DBUILD_TESTS=off -DINSTALL_HELPER_SCRIPTS=off ' +\
                    '-DCMAKE_INSTALL_PREFIX=install ' +\
                    '-DCMAKE_INSTALL_NAME_DIR=' + install_name_dir,
            'cmake --build .',
            'cmake --build . --target install',
            ]
    for cmd in cmds:
        print(cmd)
        code = os.system(cmd)
        if code != 0:
            sys.exit(code)
    os.chdir(cwd)

def bundle_db_files():
    import glob
    db_files = 'lensfunpy/db_files'
    if not os.path.exists(db_files):
        os.makedirs(db_files)
    for path in glob.glob('external/lensfun/data/db/*.xml'):
        dest = os.path.join(db_files, os.path.basename(path))
        print('copying', path, '->', dest)
        shutil.copyfile(path, dest)

package_data = {'lensfunpy': []}

# evil hack, check cmd line for relevant commands
# custom cmdclasses didn't work out in this case
cmdline = ''.join(sys.argv[1:])
needsCompile = any(s in cmdline for s in ['install', 'bdist', 'build_ext', 'wheel', 'nosetests'])
if isWindows and needsCompile:
    windows_lensfun_compile()
    package_data['lensfunpy'].append('*.dll')

elif isMac and needsCompile:
    mac_lensfun_compile()

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

if 'sdist' not in cmdline:
    # This assumes that the lensfun version from external/lensfun was used.
    # If that's not the case, the bundled files may fail to load, for example,
    # if lensfunpy was linked against an older lensfun version already on
    # the system (Linux mostly) and the database format changed in an incompatible way.
    # In that case, loading of bundled files can still be disabled
    # with Database(load_bundled=False).
    package_data['lensfunpy'].append('db_files/*.xml')
    bundle_db_files()

# Support for optional Cython line tracing
# run the following to generate a test coverage report:
# $ export LINETRACE=1
# $ python setup.py build_ext --inplace
# $ nosetests --with-coverage --cover-html --cover-package=lensfunpy
compdirectives = {}
macros = []
if (os.environ.get('LINETRACE', False)):
    compdirectives['linetrace'] = True
    macros.append(('CYTHON_TRACE', '1'))

extensions = cythonize([Extension("lensfunpy._lensfun",
              include_dirs=include_dirs,
              sources=[os.path.join('lensfunpy', '_lensfun.pyx')],
              libraries=libraries,
              library_dirs=library_dirs,
              extra_compile_args=extra_compile_args,
              extra_link_args=extra_link_args,
              define_macros=macros
             )],
             compiler_directives=compdirectives)

# make __version__ available (https://stackoverflow.com/a/16084844)
exec(open('lensfunpy/_version.py').read())

setup(
      name = 'lensfunpy',
      version = __version__,
      description = 'Lens distortion correction for Python, a wrapper for lensfun',
      long_description = open('README.rst').read(),
      author = 'Maik Riechert',
      author_email = 'maik.riechert@arcor.de',
      url = 'https://github.com/letmaik/lensfunpy',
      classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Cython',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Operating System :: MacOS',
        'Operating System :: Microsoft :: Windows',
        'Operating System :: POSIX',
        'Operating System :: Unix',
        'Topic :: Multimedia :: Graphics',
        'Topic :: Software Development :: Libraries',
      ],
      packages = find_packages(),
      ext_modules = extensions,
      package_data = package_data,
      install_requires=['numpy']
)
