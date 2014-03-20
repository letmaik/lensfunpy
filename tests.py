import lensfun

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
    
    undistCoords = mod.applySubpixelDistortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width
    
    undistCoords = mod.applySubpixelGeometryDistortion()
    assert undistCoords.shape[0] == height and undistCoords.shape[1] == width