lensfunpy
=========

.. image:: https://travis-ci.org/letmaik/lensfunpy.svg?branch=master
    :target: https://travis-ci.org/letmaik/lensfunpy
    :alt: Linux Build Status
    
.. image:: https://travis-ci.org/letmaik/lensfunpy.svg?branch=master
    :target: https://travis-ci.org/letmaik/lensfunpy
    :alt: Mac Build Status
    
.. image:: https://ci.appveyor.com/api/projects/status/qg6tssjvx5xjb3xd?svg=true
    :target: https://ci.appveyor.com/project/letmaik/lensfunpy
    :alt: Windows Build Status

lensfunpy is an easy-to-use Python wrapper for the lensfun_ library.

`API Documentation <http://pythonhosted.org/lensfunpy/api/>`_

Sample code
-----------

How to find cameras and lenses:

.. code-block:: python

    import lensfunpy

    cam_maker = 'NIKON CORPORATION'
    cam_model = 'NIKON D3S'
    lens_maker = 'Nikon'
    lens_model = 'Nikkor 28mm f/2.8D AF'

    db = lensfunpy.Database()
    cam = db.find_cameras(cam_maker, cam_model)[0]
    lens = db.find_lenses(cam, lens_maker, lens_model)[0]
    
    print(cam)
    # Camera(Maker: NIKON CORPORATION; Model: NIKON D3S; Variant: ; 
    #        Mount: Nikon F AF; Crop Factor: 1.0; Score: 0)
    
    print(lens)
    # Lens(Maker: Nikon; Model: Nikkor 28mm f/2.8D AF; Type: RECTILINEAR;
    #      Focal: 28.0-28.0; Aperture: 2.79999995232-2.79999995232; 
    #      Crop factor: 1.0; Score: 110)    

How to correct lens distortion:

.. code-block:: python

    import cv2 # OpenCV library
    
    focal_length = 28.0
    aperture = 1.4
    distance = 10
    image_path = '/path/to/image.tiff'
    undistorted_image_path = '/path/to/image_undist.tiff'
    
    im = cv2.imread(image_path)
    height, width = im.shape[0], im.shape[1]
    
    mod = lensfunpy.Modifier(lens, cam.crop_factor, width, height)
    mod.initialize(focal_length, aperture, distance)
    
    undist_coords = mod.apply_geometry_distortion()
    im_undistorted = cv2.remap(im, undist_coords, None, cv2.INTER_LANCZOS4)
    cv2.imwrite(undistorted_image_path, im_undistorted)
    
It is also possible to apply the correction via `SciPy <http://www.scipy.org>`_ instead of OpenCV.
The `lensfunpy.util <http://pythonhosted.org/lensfunpy/api/lensfunpy.util.html>`_ module
contains convenience functions for RGB images which handle both OpenCV and SciPy.

NumPy Dependency
----------------

Before installing lensfunpy, you need to have *numpy* installed.
You can check your numpy version with ``pip freeze``.

The minimum supported numpy version depends on your Python version:

========== =========
Python     numpy
---------- ---------
2.7        >= 1.7
3.4        >= 1.8
3.5 - 3.6  >= 1.11
========== =========

You can install numpy with ``pip install numpy``.

Installation on Windows and Mac OS X
------------------------------------

Binaries are provided for Python 2.7, 3.4, 3.5, and 3.6 for both 32 and 64 bit.
These can be installed with a simple ``pip install lensfunpy``
(or ``pip install --use-wheel lensfunpy`` if using pip < 1.5).

Installation on Linux
---------------------

You need to have the lensfun_ library installed to use this wrapper.

On Ubuntu, you can get (an outdated) version with:

.. code-block:: sh

    sudo apt-get install liblensfun0 liblensfun-dev
    
Or install the latest developer version from the GIT repository:

.. code-block:: sh

    git clone git://git.code.sf.net/p/lensfun/code lensfun
    cd lensfun
    cmake .
    sudo make install
    
After that, it's the usual ``pip install lensfunpy``.
    
If you get the error "ImportError: liblensfun.so.0: cannot open shared object file: No such file or directory"
when trying to use lensfunpy, then do the following:

.. code-block:: sh

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/99local.conf
    sudo ldconfig

The lensfun library is installed in ``/usr/local/lib`` when compiled from source, and apparently this folder is not searched
for libraries by default in some Linux distributions. Note that on some systems the installation path may be slightly different, such as ``/usr/local/lib/x86_64-linux-gnu``.


.. _lensfun: http://lensfun.sourceforge.net
