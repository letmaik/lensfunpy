from __future__ import division

import numpy as np
import lensfun
import gc

# the following string were taken from the lensfun xml files
camMaker = 'NIKON CORPORATION'
camModel = 'NIKON D3S'
lensMaker = 'Nikon'
lensModel = 'Nikkor 28mm f/2.8D AF'

def testDatabaseLoading():
    db = lensfun.Database()
       
    cams = db.findCameras(camMaker, camModel)
    assert len(cams) == 1
    cam = cams[0]
    assert cam.Maker.lower() == camMaker.lower()
    assert cam.Model.lower() == camModel.lower()
    
    lenses = db.findLenses(cam, lensMaker, lensModel)
    assert len(lenses) == 1
    lens = lenses[0]
    assert lens.Maker.lower() == lensMaker.lower()
    assert lens.Model.lower() == lensModel.lower()
    
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
    
    assert len(db.getCameras()) == 1
    assert len(db.getLenses()) == 1
    assert len(db.getMounts()) == 1
    
    cam = db.findCameras(camMaker, camModel)[0]
    lens = db.findLenses(cam, lensMaker, lensModel)[0]
    
    assert cam.Maker.lower() == camMaker.lower()
    assert cam.Model.lower() == camModel.lower()
    assert lens.Maker.lower() == lensMaker.lower()
    assert lens.Model.lower() == lensModel.lower()
    
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
    
    assert cam.Maker.lower() == camMaker.lower()
    assert lens.Maker.lower() == lensMaker.lower()