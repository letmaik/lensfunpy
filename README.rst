lensfunpy
=========

.. image:: https://travis-ci.org/neothemachine/lensfunpy.svg?branch=master
    :target: https://travis-ci.org/neothemachine/lensfunpy
    :alt: Build Status

lensfunpy is an easy-to-use Python wrapper for the `lensfun library <http://lensfun.berlios.de>`_.

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
    print lens

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

You need to have the `lensfun library <http://lensfun.berlios.de>`_ installed to use this wrapper.

On Ubuntu, you can get (an outdated) version with:
sudo apt-get install liblensfun0 liblensfun-dev