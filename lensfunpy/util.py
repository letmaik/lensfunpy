from __future__ import print_function, division, absolute_import

import numpy as np

from scipy.ndimage.interpolation import map_coordinates
try:
    import cv2
except ImportError:
    cv2 = None
    print('OpenCV not available, will use scipy for remapping distorted images')

def remapOpenCv(im, undistCoords):
    return cv2.remap(im, undistCoords, None, cv2.INTER_LANCZOS4)

def remapScipy(im, undistCoords):   
    height, width = im.shape[0], im.shape[1]
    
    # switch to y,x order
    undistCoords = undistCoords[:,:,::-1]

    # make it (h, w, 3, 3)
    coords = np.empty((height, width, 3, 3))
    coords_channel = np.zeros((height, width, 3))
    coords_channel[:,:,:2] = undistCoords
    coords[:,:,0] = coords_channel
    coords[:,:,1] = coords_channel
    coords[:,:,1,2] = 1
    coords[:,:,2] = coords_channel
    coords[:,:,2,2] = 2
    undistCoords = coords
    
    # (3, h, w, 3)
    undistCoords = np.rollaxis(undistCoords, 3)
        
    return map_coordinates(im, undistCoords, order=1)

remap = remapOpenCv if cv2 else remapScipy