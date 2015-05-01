from __future__ import print_function

from setuptools import setup, Extension, find_packages
import numpy
import subprocess
import errno
import re
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
    
if sys.version_info < (2, 7):
    raise NotImplementedError('Minimum supported Python version is 2.7')

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
    cmake_build = os.path.abspath('external/lensfun/cmake_build')
    install_dir = os.path.join(cmake_build, 'install')
    
    include_dirs += [os.path.join(install_dir, 'include', 'lensfun')]
    library_dirs += [os.path.join(install_dir, 'lib')]
else:
    use_pkg_config()
    
if isWindows:
    include_dirs += ['external/stdint']

# this must be after use_pkg_config()!
include_dirs += [numpy.get_include()]

def clone_submodules():
    # check that lensfun git submodule is cloned
    if not os.path.exists('external/lensfun/README'):
        print('lensfun git submodule is not cloned yet, will invoke "git submodule update --init" now')
        if os.system('git submodule update --init') != 0:
            raise Exception('git failed')

def windows_lensfun_compile():
    clone_submodules()
    
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
    cmake = os.path.abspath('external/cmake-3.0.1-win32-x86/bin/cmake.exe')
    
    files = [(glib_libs_url, glib_dir, glib_dir + '/bin/libglib-2.0-0.dll'), 
             (glib_dev_url, glib_dir, glib_dir + '/lib/glib-2.0.lib'),
             (libiconv_url, glib_dir, glib_dir + '/bin/libiconv-2.dll'),
             (gettext_url, glib_dir, glib_dir + '/bin/libintl-8.dll'),
             (cmake_url, 'external', cmake)]
    
    if not is64Bit:
        # the 32bit version of gettext's libintl-8.dll requires pthreadgc2.dll
        pthreads_dir = 'external/pthreads'
        pthreads_url = 'http://mirrors.kernel.org/sourceware/pthreads-win32/pthreads-w32-2-9-1-release.zip'
        files.extend([(pthreads_url, pthreads_dir, pthreads_dir + '/Pre-built.2')])
        
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
    
    # configure and compile lensfun
    cwd = os.getcwd()
    if not os.path.exists(cmake_build):
        os.mkdir(cmake_build)
    os.chdir(cmake_build)
    cmds = [cmake + ' .. -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release ' +\
                    '-DBUILD_TESTS=off -DINSTALL_HELPER_SCRIPTS=off ' +\
                    '-DGLIB2_BASE_DIR=glib-2.0 -DLENSFUN_INSTALL_PREFIX=install',
            'nmake install'
            ]
    for cmd in cmds:
        print(cmd)
        code = os.system(cmd)
        if code != 0:
            sys.exit(code) 
    os.chdir(cwd)
    
    # bundle runtime dlls
    glib_bin_dir = os.path.join(glib_dir, 'bin')
    dll_runtime_libs = [('lensfun.dll', os.path.join(install_dir, 'bin')),
                        ('libglib-2.0-0.dll', glib_bin_dir),
                        ('libiconv-2.dll', glib_bin_dir),
                        ('libintl-8.dll', glib_bin_dir), # gettext
                        ]
    if not is64Bit:
        dll_runtime_libs.extend([
            ('pthreadGC2.dll', os.path.join(pthreads_dir, 'Pre-built.2', 'dll', 'x86'))
            ])
    
    for filename, folder in dll_runtime_libs:
        src = os.path.join(folder, filename)
        dest = 'lensfunpy/' + filename
        print('copying', src, '->', dest)
        shutil.copyfile(src, dest)
    
    bundle_db_files()
        
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
                    '-DLENSFUN_INSTALL_PREFIX=install ' +\
                    '-DCMAKE_MACOSX_RPATH=0 -DCMAKE_INSTALL_NAME_DIR=' + install_name_dir,
            'make',
            'make install'
            ]
    for cmd in cmds:
        print(cmd)
        code = os.system(cmd)
        if code != 0:
            sys.exit(code)
    os.chdir(cwd)
    
    bundle_db_files()
    
def bundle_db_files():
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
needsCompile = any(s in cmdline for s in ['install', 'bdist', 'build_ext', 'nosetests'])
if isWindows and needsCompile:
    windows_lensfun_compile()
    package_data['lensfunpy'] = ['db_files/*.xml',
                                 '*.dll']

elif isMac and needsCompile:
    mac_lensfun_compile()
    package_data['lensfunpy'] = ['db_files/*.xml']
        
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

pyx_path = '_lensfun.pyx'
c_path = '_lensfun.c'
if not os.path.exists(pyx_path):
    # we are running from a source dist which doesn't include the .pyx
    use_cython = False
else:
    try:
        from Cython.Build import cythonize
    except ImportError:
        use_cython = False
    else:
        use_cython = True

source_path = pyx_path if use_cython else c_path

extensions = [Extension("lensfunpy._lensfun",
              include_dirs=include_dirs,
              sources=[source_path],
              libraries=libraries,
              library_dirs=library_dirs,
              extra_compile_args=extra_compile_args,
              extra_link_args=extra_link_args,
             )]

if use_cython:
    extensions = cythonize(extensions)

# version handling from https://stackoverflow.com/a/7071358
VERSIONFILE="lensfunpy/_version.py"
verstrline = open(VERSIONFILE, "rt").read()
VSRE = r"^__version__ = ['\"]([^'\"]*)['\"]"
mo = re.search(VSRE, verstrline, re.M)
if mo:
    verstr = mo.group(1)
else:
    raise RuntimeError("Unable to find version string in %s." % (VERSIONFILE,))

setup(
      name = 'lensfunpy',
      version = verstr,
      description = 'Python wrapper for the lensfun library',
      long_description = open('README.rst').read(),
      author = 'Maik Riechert',
      author_email = 'maik.riechert@arcor.de',
      url = 'https://github.com/neothemachine/lensfunpy',
      classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Cython',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.3',
        'Programming Language :: Python :: 3.4',
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
      install_requires=['enum34'],
)
