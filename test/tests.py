from __future__ import division, print_function

import numpy as np
import lensfunpy as lensfun
import gc
from numpy.testing.utils import assert_equal

# the following strings were taken from the lensfun xml files
cam_maker = u'NIKON CORPORATION'
cam_model = u'NIKON D3S'
lens_maker = u'Nikon'
lens_model = u'Nikkor 28mm f/2.8D AF'
# Note regarding u-prefix:
# As lensfunpy returns unicode strings we declare the above
# as unicocd strings as well to make comparison in unit tests easier.
# (Python 2 would default to byte, Python 3 to unicode and comparing byte
#  with unicode fails without en/decoding)

def testDatabaseLoading():
    db = lensfun.Database()
       
    cams = db.find_cameras(cam_maker, cam_model)
    assert_equal(len(cams), 1)
    cam = cams[0]
    assert_equal(cam.maker.lower(), cam_maker.lower())
    assert_equal(cam.model.lower(), cam_model.lower())
    assert len(str(cam)) > 0
    
    lenses = db.find_lenses(cam, lens_maker, lens_model)
    assert_equal(len(lenses), 1)
    lens = lenses[0]
    assert_equal(lens.maker.lower(), lens_maker.lower())
    assert len(str(lens)) > 0
    
    if lensfun.lensfun_version >= (0,3):
        # lens names were "streamlined" in lensfun 0.3
        assert_equal(lens.model.lower(), u'nikon af nikkor 28mm f/2.8d')
    else:
        assert_equal(lens.model.lower(), lens_model.lower())
    
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
    db = lensfun.Database(xml=xml, load_common=False, load_bundled=False)
    
    assert_equal(len(db.cameras), 1)
    assert_equal(len(db.lenses), 1)
    assert_equal(len(db.mounts), 1)
    
    cam = db.find_cameras(cam_maker, cam_model)[0]
    lens = db.find_lenses(cam, lens_maker, lens_model)[0]
    
    assert_equal(cam.maker.lower(), cam_maker.lower())
    assert_equal(cam.model.lower(), cam_model.lower())
    assert_equal(lens.maker.lower(), lens_maker.lower())
    assert_equal(lens.model.lower(), lens_model.lower())
    
def testModifier():
    db = lensfun.Database()
    cam = db.find_cameras(cam_maker, cam_model)[0]
    lens = db.find_lenses(cam, lens_maker, lens_model)[0]
    
    focal_length = 28.0
    aperture = 1.4
    distance = 10
    width = 4256
    height = 2832
    
    mod = lensfun.Modifier(lens, cam.crop_factor, width, height)
    mod.initialize(focal_length, aperture, distance)
        
    undistCoords = mod.apply_geometry_distortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    
    # check if coordinates were actually transformed
    y, x = np.mgrid[0:undistCoords.shape[0], 0:undistCoords.shape[1]]
    coords = np.dstack((x,y))
    assert np.any(undistCoords != coords)
    
    undistCoords = mod.apply_subpixel_distortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    assert np.any(undistCoords[:,:,0] != coords)
    
    undistCoords = mod.apply_subpixel_geometry_distortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    assert np.any(undistCoords[:,:,0] != coords)
    
def testDeallocationBug():
    db = lensfun.Database()
    cam = db.find_cameras(cam_maker, cam_model)[0]
    lens = db.find_lenses(cam, lens_maker, lens_model)[0]
    
    # By garbage collecting the database object, its queried objects
    # were deallocated as well, which is not what we want.
    # Now, all queried objects hold a reference to the Database object
    # they came from. This way, the Database object is only deallocated
    # when all queried objects were garbage collected.
    del db
    gc.collect()
    
    assert_equal(cam.maker.lower(), cam_maker.lower())
    assert_equal(lens.maker.lower(), lens_maker.lower())

def testXmlFormatException():
    try:
        lensfun.Database(xml='garbage')
    except lensfun.XMLFormatError:
        pass
    else:
        assert False

def testNewLensType():
    # https://github.com/letmaik/lensfunpy/issues/10
    # lensfun added new lens types which were not supported yet by lensfunpy.
    # This test accesses one such lens type and was raising an exception previously.
    db = lensfun.Database()
    cam = db.find_cameras('NIKON CORPORATION', 'NIKON D3S')[0]
    lenses = db.find_lenses(cam, 'Sigma', 'Sigma 8mm f/3.5 EX DG circular fisheye')
    if lenses: # newer lens, only run test if lens actually exists
        assert_equal(lenses[0].type, lensfun.LensType.FISHEYE_EQUISOLID)
    else:
        print('Skipping testNewLensType as lens not found')

# TODO lensfun's find* functions modify the score directly in the original db objects
#  -> another invocation of find* will overwrite the old scores
