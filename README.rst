lensfunpy
=========

.. image:: https://travis-ci.org/neothemachine/lensfunpy.svg?branch=master
    :target: https://travis-ci.org/neothemachine/lensfunpy
    :alt: Build Status
    
.. image:: https://ci.appveyor.com/api/projects/status/qg6tssjvx5xjb3xd/branch/master
    :target: https://ci.appveyor.com/project/neothemachine/lensfunpy/branch/master
    :alt: Build Status

lensfunpy is an easy-to-use Python wrapper for the lensfun_ library.

Sample code
-----------

How to find cameras and lenses:

.. code-block:: python

    import lensfunpy

    camMaker = 'NIKON CORPORATION'
    camModel = 'NIKON D3S'
    lensMaker = 'Nikon'
    lensModel = 'Nikkor 28mm f/2.8D AF'

    db = lensfunpy.Database()
    cam = db.findCameras(camMaker, camModel)[0]
    lens = db.findLenses(cam, lensMaker, lensModel)[0]
    
    print cam
    # Camera(Maker: NIKON CORPORATION; Model: NIKON D3S; Variant: ; 
    #        Mount: Nikon F AF; Crop Factor: 1.0; Score: 0)
    
    print lens
    # Lens(Maker: Nikon; Model: Nikkor 28mm f/2.8D AF; Type: RECTILINEAR;
    #      Focal: 28.0-28.0; Aperture: 2.79999995232-2.79999995232; 
    #      Crop factor: 1.0; Score: 110)    

How to correct lens distortion:

.. code-block:: python

    import cv2 # OpenCV library
    
    focalLength = 28.0
    aperture = 1.4
    distance = 10
    imagePath = '/path/to/image.tiff'
    undistortedImagePath = '/path/to/image_undist.tiff'
    
    im = cv2.imread(imagePath)
    height, width = im.shape[0], im.shape[1]
    
    mod = lensfunpy.Modifier(lens, cam.CropFactor, width, height)
    mod.initialize(focalLength, aperture, distance)
    
    undistCoords = mod.applyGeometryDistortion()
    imUndistorted = cv2.remap(im, undistCoords, None, cv2.INTER_LANCZOS4)
    cv2.imwrite(undistortedImagePath, imUndistorted)
    
Installation on Linux
---------------------

You need to have the lensfun_ library installed to use this wrapper.

On Ubuntu, you can get (an outdated) version with:

.. code-block:: sh

    sudo apt-get install liblensfun0 liblensfun-dev
    
Or install the latest developer version from the SVN repository:

.. code-block:: sh

    git clone git://git.code.sf.net/p/lensfun/code lensfun
    cd lensfun
    ./configure
    sudo make install
    
After that, it's the usual ``pip install lensfunpy``.
    
If you get the error "ImportError: liblensfun.so.0: cannot open shared object file: No such file or directory"
when trying to use lensfunpy, then do the following:

.. code-block:: sh

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/99local.conf
    sudo ldconfig

The lensfun library is installed in /usr/local/lib and apparently this folder is not searched
for libraries by default in some Linux distributions.

Installation on Windows
-----------------------

Binaries are provided for Python 2.7, 3.3 and 3.4 for both 32 and 64 bit.
These can be installed with a simple ``pip install --use-wheel lensfunpy`` 
(or just ``pip install lensfunpy`` if using pip >= 1.5).

Binaries for other Python versions are currently not produced but if there is a need
then this is possible as well. In that case, just contact me.


.. _lensfun: http://lensfun.sourceforge.net
