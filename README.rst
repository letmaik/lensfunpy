lensfunpy
=========

.. image:: https://travis-ci.org/neothemachine/lensfunpy.svg?branch=master
    :target: https://travis-ci.org/neothemachine/lensfunpy
    :alt: Build Status

lensfunpy is an easy-to-use Python wrapper for the `lensfun library <http://lensfun.sourceforge.net>`_.

Sample code
-----------

How to find cameras and lenses:

.. code-block:: python

    import lensfun

    camMaker = 'NIKON CORPORATION'
    camModel = 'NIKON D3S'
    lensMaker = 'Nikon'
    lensModel = 'Nikkor 28mm f/2.8D AF'

    db = lensfun.Database()
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
    
    mod = lensfun.Modifier(lens, cam.CropFactor, width, height)
    mod.initialize(focalLength, aperture, distance)
    
    undistCoords = mod.applyGeometryDistortion()
    imUndistorted = cv2.remap(im, undistCoords, None, cv.INTER_LANCZOS4)
    cv2.imwrite(undistortedImagePath, imUndistorted)
    
Installation
------------

You need to have the `lensfun library <http://lensfun.sourceforge.net>`_ installed to use this wrapper.

On Ubuntu, you can get (an outdated) version with:

.. code-block:: sh

    sudo apt-get install liblensfun0 liblensfun-dev
    
Or install the latest developer version from the SVN repository:

.. code-block:: sh

    svn co svn://svn.berlios.de/lensfun/trunk lensfun
    cd lensfun
    ./configure
    sudo make install
    
Troubleshooting
---------------
    
If you get the error "ImportError: liblensfun.so.0: cannot open shared object file: No such file or directory"
when trying to use lensfunpy, then do the following:

.. code-block:: sh

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/99local.conf
    sudo ldconfig

The lensfun library is installed in /usr/local/lib and apparently this folder is not searched
for libraries by default in some Linux distributions.