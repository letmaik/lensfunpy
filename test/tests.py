from __future__ import division, print_function

import numpy as np
import lensfunpy as lensfun
import gc
from numpy.testing.utils import assert_equal

# the following string were taken from the lensfun xml files
camMaker = b'NIKON CORPORATION'
camModel = b'NIKON D3S'
lensMaker = b'Nikon'
lensModel = b'Nikkor 28mm f/2.8D AF'
# Note regarding b-prefix:
# As lensfunpy returns byte strings (not unicode) we declare the above
# as byte strings as well to make comparison in unit tests easier.
# (Python 2 would default to byte, Python 3 to unicode and comparing byte
#  with unicode fails without en/decoding)

# TODO what should lensfunpy really return? unicode? is lensfun data in utf8 or not?

def testDatabaseLoading():
    db = lensfun.Database()
       
    cams = db.findCameras(camMaker, camModel)
    assert_equal(len(cams), 1)
    cam = cams[0]
    assert_equal(cam.Maker.lower(), camMaker.lower())
    assert_equal(cam.Model.lower(), camModel.lower())
    
    lenses = db.findLenses(cam, lensMaker, lensModel)
    assert_equal(len(lenses), 1)
    lens = lenses[0]
    assert_equal(lens.Maker.lower(), lensMaker.lower())
    assert_equal(lens.Model.lower(), lensModel.lower())
    
def testDatabaseXMLLoading():
    xml = """
<lensdatabase>
    <mount>
        <name>Nikon F AF</name>
        <compat>Nikon F</compat>
        <compat>Nikon F AI</compat>
        <compat>Nikon F AI-S</compat>
        <compat>M42</compat>
        <compat>T2</compat>
        <compat>Generic</compat>
    </mount>
    <camera>
        <maker>Nikon Corporation</maker>
        <maker lang="en">Nikon</maker>
        <model>Nikon D3S</model>
        <model lang="en">D3S</model>
        <mount>Nikon F AF</mount>
        <cropfactor>1.0</cropfactor>
    </camera>
    <lens>
        <maker>Nikon</maker>
        <model>Nikkor 28mm f/2.8D AF</model>
        <mount>Nikon F AF</mount>
        <cropfactor>1.0</cropfactor>
        <calibration>
            <distortion model="ptlens" focal="28" a="0" b="0.025773" c="-0.085777" />
        </calibration>
    </lens>
</lensdatabase>
    """
    db = lensfun.Database(xml=xml, loadAll=False)
    
    assert_equal(len(db.getCameras()), 1)
    assert_equal(len(db.getLenses()), 1)
    assert_equal(len(db.getMounts()), 1)
    
    cam = db.findCameras(camMaker, camModel)[0]
    lens = db.findLenses(cam, lensMaker, lensModel)[0]
    
    assert_equal(cam.Maker.lower(), camMaker.lower())
    assert_equal(cam.Model.lower(), camModel.lower())
    assert_equal(lens.Maker.lower(), lensMaker.lower())
    assert_equal(lens.Model.lower(), lensModel.lower())
    
def testModifier():
    db = lensfun.Database()
    cam = db.findCameras(camMaker, camModel)[0]
    lens = db.findLenses(cam, lensMaker, lensModel)[0]
    
    focalLength = 28.0
    aperture = 1.4
    distance = 10
    width = 4256
    height = 2832
    
    mod = lensfun.Modifier(lens, cam.CropFactor, width, height)
    mod.initialize(focalLength, aperture, distance)
        
    undistCoords = mod.applyGeometryDistortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    
    # check if coordinates were actually transformed
    y, x = np.mgrid[0:undistCoords.shape[0], 0:undistCoords.shape[1]]
    coords = np.dstack((x,y))
    assert np.any(undistCoords != coords)
    
    undistCoords = mod.applySubpixelDistortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    assert np.any(undistCoords[:,:,0] != coords)
    
    undistCoords = mod.applySubpixelGeometryDistortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    assert np.any(undistCoords[:,:,0] != coords)
    
def testDeallocationBug():
    db = lensfun.Database()
    cam = db.findCameras(camMaker, camModel)[0]
    lens = db.findLenses(cam, lensMaker, lensModel)[0]
    
    # By garbage collecting the database object, its queried objects
    # were deallocated as well, which is not what we want.
    # Now, all queried objects hold a reference to the Database object
    # they came from. This way, the Database object is only deallocated
    # when all queried objects were garbage collected.
    del db
    gc.collect()
    
    assert_equal(cam.Maker.lower(), camMaker.lower())
    assert_equal(lens.Maker.lower(), lensMaker.lower())
    
# TODO lensfun's find* functions modify the score directly in the original db objects
#  -> another invocation of find* will overwrite the old scores
