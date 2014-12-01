from __future__ import print_function, division, absolute_import

import numpy as np

from scipy.ndimage.interpolation import map_coordinates
try:
    import cv2
except ImportError:
    cv2 = None
    print('OpenCV not available, will use scipy for remapping images')

def remapOpenCv(im, coords):
    """
    Remap an image using OpenCV. See :func:`remap` for parameters.
    """
    # required for older OpenCV versions
    im = np.require(im, im.dtype, 'C')
    return cv2.remap(im, coords, None, cv2.INTER_LANCZOS4)

def remapScipy(im, coords):
    """
    Remap an image using SciPy. See :func:`remap` for parameters.
    """
    height, width = im.shape[0], im.shape[1]
    
    # switch to y,x order
    coords = coords[:,:,::-1]

    # make it (h, w, 3, 3)
    coords_channels = np.empty((height, width, 3, 3))
    coords_channel = np.zeros((height, width, 3))
    coords_channel[:,:,:2] = coords
    coords_channels[:,:,0] = coords_channel
    coords_channels[:,:,1] = coords_channel
    coords_channels[:,:,1,2] = 1
    coords_channels[:,:,2] = coords_channel
    coords_channels[:,:,2,2] = 2
    coords = coords_channels
    
    # (3, h, w, 3)
    coords = np.rollaxis(coords, 3)
        
    return map_coordinates(im, coords, order=1)

def remap(im, coords):
    """
    Remap an RGB image using the given target coordinate array.
    
    If available, OpenCV is used (faster), otherwise SciPy.
    
    :type im: ndarray of shape (h,w,3)
    :param im: RGB image to be remapped
    :type coords: ndarray of shape (h,w,2)
    :param coords: target coordinates in x,y order for each pixel
    :return: remapped RGB image
    :rtype: ndarray of shape (h,w,3)
    """
    if cv2:
        return remapOpenCv(im, coords)
    else:
        return remapScipy(im, coords)
    