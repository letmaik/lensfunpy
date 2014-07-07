from libc.stdint cimport uintptr_t
from cpython.mem cimport PyMem_Malloc, PyMem_Free

import numpy as np
from collections import namedtuple
cimport numpy as np
np.import_array()

# We cannot use Cython's C++ support here, as lensfun.h exposes functions
# in an 'extern "C"' block, which is not supported yet. Therefore, lensfun's
# C interface is used.

DTYPE = np.float32
ctypedef np.float32_t DTYPE_t

cdef extern from "lensfun.h":
    ctypedef int LF_VERSION
    ctypedef char *lfMLstr
    
    enum lfError:
        LF_NO_ERROR
        LF_WRONG_FORMAT
        
    enum lfPixelFormat:
        LF_PF_U8
        LF_PF_U16
        LF_PF_U32
        LF_PF_F32
        LF_PF_F64
        
    enum lfLensType:
        LF_UNKNOWN
        LF_RECTILINEAR
        LF_FISHEYE
        LF_PANORAMIC
        LF_EQUIRECTANGULAR
        
    enum lfDistortionModel:
        LF_DIST_MODEL_NONE
        LF_DIST_MODEL_POLY3
        LF_DIST_MODEL_POLY5
        LF_DIST_MODEL_FOV1
        LF_DIST_MODEL_PTLENS
    struct lfLensCalibDistortion:
        lfDistortionModel Model
        float Focal
        float Terms [3]
        
    enum lfTCAModel:
        LF_TCA_MODEL_NONE
        LF_TCA_MODEL_LINEAR
        LF_TCA_MODEL_POLY3
    struct lfLensCalibTCA:
        lfTCAModel Model
        float Focal
        float Terms [6]
        
    enum lfVignettingModel:
        LF_VIGNETTING_MODEL_NONE
        LF_VIGNETTING_MODEL_PA
    struct lfLensCalibVignetting:
        lfVignettingModel Model
        float Focal
        float Aperture
        float Distance
        float Terms [3]
        
    struct lfDatabase:
        pass
    
    struct lfCamera:
        lfMLstr Maker
        lfMLstr Model
        lfMLstr Variant
        char* Mount
        float CropFactor
        int Score
        
    struct lfMount:
        lfMLstr Name
        char **Compat # A list of compatible mounts
        
    struct lfLens:
        # general lens data
        lfMLstr Maker
        lfMLstr Model
        lfLensType Type
        char **Mounts
        float MinFocal
        float MaxFocal
        float MinAperture
        float MaxAperture
        
        # calibration data
        float CropFactor
        # AspectRatio added in 0.2.9, but there's no easy way to include this conditionally (limitation of Cython)
        # float AspectRatio
        float CenterX
        float CenterY
        float RedCCI
        float GreenCCI
        float BlueCCI
        lfLensCalibDistortion **CalibDistortion
        lfLensCalibTCA **CalibTCA
        lfLensCalibVignetting **CalibVignetting
        
        int Score
        
    struct lfModifier:
        pass
    enum:
        LF_SEARCH_LOOSE
    enum:
        LF_MODIFY_TCA
        LF_MODIFY_VIGNETTING
        LF_MODIFY_CCI
        LF_MODIFY_DISTORTION
        LF_MODIFY_GEOMETRY
        LF_MODIFY_SCALE
        LF_MODIFY_ALL
    
    void lf_free (void *data)
    
    lfDatabase *lf_db_new ()
    void lf_db_destroy (lfDatabase *db)
    lfError lf_db_load (lfDatabase *db)
    lfError lf_db_load_file (lfDatabase *db, const char *filename)
    lfError lf_db_load_data (lfDatabase *db, const char *errcontext, const char *data, size_t data_size)
    const lfCamera *const *lf_db_get_cameras (const lfDatabase *db)
    const lfLens *const *lf_db_get_lenses (const lfDatabase *db)
    const lfMount *const *lf_db_get_mounts (const lfDatabase *db)
    const lfCamera **lf_db_find_cameras (const lfDatabase *db, const char *maker, const char *model)
    const lfCamera **lf_db_find_cameras_ext (const lfDatabase *db, const char *maker, const char *model, int sflags)
    const lfLens **lf_db_find_lenses_hd (const lfDatabase *db, const lfCamera *camera, const char *maker, const char *lens, int sflags)
    const lfMount *lf_db_find_mount (const lfDatabase *db, const char *mount)
    
    lfModifier *lf_modifier_new (const lfLens *lens, float crop, int width, int height)
    void lf_modifier_destroy (lfModifier *modifier)
    int lf_modifier_initialize (lfModifier *modifier, const lfLens *lens, lfPixelFormat format,
                                float focal, float aperture, float distance, float scale,
                                lfLensType targeom, int flags, int reverse)
    int lf_modifier_apply_geometry_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)
    int lf_modifier_apply_subpixel_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)
    int lf_modifier_apply_subpixel_geometry_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)
    
    int lf_lens_interpolate_distortion (const lfLens *lens, float focal, lfLensCalibDistortion *res)
    int lf_lens_interpolate_tca (const lfLens *lens, float focal, lfLensCalibTCA *res)
    int lf_lens_interpolate_vignetting (const lfLens *lens, float focal, float aperture, float distance, lfLensCalibVignetting *res)

def enum(**enums):
    return type('Enum', (), enums)

def enumKey(enu, val):
    # cython doesn't like tuple unpacking in lambdas ("Expected ')', found ','")
    #return filter(lambda (k,v): v == val, enu.__dict__.items())[0][0]
    return filter(lambda item: item[1] == val, enu.__dict__.items())[0][0]

ModifyFlags = enum(
                   TCA=LF_MODIFY_TCA,
                   VIGNETTING=LF_MODIFY_VIGNETTING,
                   CCI=LF_MODIFY_CCI,
                   DISTORTION=LF_MODIFY_DISTORTION,
                   GEOMETRY=LF_MODIFY_GEOMETRY,
                   SCALE=LF_MODIFY_SCALE,
                   ALL=LF_MODIFY_ALL
                   )

LensType = enum(
                UNKNOWN=LF_UNKNOWN,
                RECTILINEAR=LF_RECTILINEAR,
                FISHEYE=LF_FISHEYE,
                PANORAMIC=LF_PANORAMIC,
                EQUIRECTANGULAR=LF_EQUIRECTANGULAR
                )

DistortionModel = enum(
                       NONE=LF_DIST_MODEL_NONE,
                       POLY3=LF_DIST_MODEL_POLY3,
                       POLY5=LF_DIST_MODEL_POLY5,
                       FOV1=LF_DIST_MODEL_FOV1,
                       PTLENS=LF_DIST_MODEL_PTLENS
                       )

LensCalibDistortion = namedtuple('LensCalibDistortion', ['Model', 'Focal', 'Terms'])

TCAModel = enum(
                NONE=LF_TCA_MODEL_NONE,
                LINEAR=LF_TCA_MODEL_LINEAR,
                POLY3=LF_TCA_MODEL_POLY3
                )

LensCalibTCA = namedtuple('LensCalibTCA', ['Model', 'Focal', 'Terms'])

VignettingModel = enum(
                       NONE=LF_VIGNETTING_MODEL_NONE,
                       PA=LF_VIGNETTING_MODEL_PA
                       )

LensCalibVignetting = namedtuple('LensCalibVignetting', ['Model', 'Focal', 'Aperture', 'Distance', 'Terms'])

cdef class Database:

    cdef lfDatabase* lf

    def __cinit__(self):
        self.lf = lf_db_new()
            
    def __init__(self, filenames=None, xml=None, loadAll=True):
        if filenames:
            for filename in filenames:
                err = lf_db_load_file(self.lf, filename)
        if xml:
            err = lf_db_load_data(self.lf, 'XML', xml, len(xml))
        
        if (not filenames and not xml) or loadAll:
            err = lf_db_load(self.lf)
        
    def __dealloc__(self):
        lf_db_destroy(self.lf)
        
    def getCameras(self):
        cdef const lfCamera *const * lfCams
        lfCams = lf_db_get_cameras(self.lf)
        cams = self._convertCams(<const lfCamera **>lfCams)
        # NOTE: lfCams must not be lf_free'd! it points to an internal list (not a copy!)
        return cams
        
    def findCameras(self, maker, model, looseSearch = False):
        cdef const lfCamera ** lfCams
        cdef char* cmaker
        cdef char* cmodel
        if maker is None:
            cmaker = NULL
        else:
            cmaker = maker
        if model is None:
            cmodel = NULL
        else:
            cmodel = model
        if looseSearch:
            lfCams = lf_db_find_cameras_ext(self.lf, cmaker, cmodel, LF_SEARCH_LOOSE)
        else:
            lfCams = lf_db_find_cameras(self.lf, maker, model)
        cams = self._convertCams(lfCams)
        lf_free(lfCams)
        return cams
    
    def getMounts(self):
        cdef const lfMount *const * lfMounts
        lfMounts = lf_db_get_mounts(self.lf)
        mounts = self._convertMounts(<const lfMount **>lfMounts)
        # NOTE: lfMounts must not be lf_free'd! it points to an internal list (not a copy!)
        return mounts
        
    def findMount(self, name):
        cdef const lfMount * lfMoun
        lfMoun = lf_db_find_mount(self.lf, name)
        return Mount(<uintptr_t>lfMoun, self)
    
    def getLenses(self):
        cdef const lfLens *const * lfLenses
        lfLenses = lf_db_get_lenses(self.lf)
        lenses = self._convertLenses(<const lfLens **>lfLenses)
        # NOTE: lfLenses must not be lf_free'd! it points to an internal list (not a copy!)
        return lenses
    
    def findLenses(self, Camera camera not None, maker, lens, looseSearch = False):
        cdef const lfLens ** lfLenses
        cdef char* cmaker
        cdef char* clens
        if maker is None:
            cmaker = NULL
        else:
            cmaker = maker
        if lens is None:
            clens = NULL
        else:
            clens = lens
        lfLenses = lf_db_find_lenses_hd(self.lf, camera.lf, cmaker, clens, LF_SEARCH_LOOSE if looseSearch else 0)
        lenses = self._convertLenses(lfLenses)
        lf_free(lfLenses)
        return lenses
    
    cdef _convertCams(self, const lfCamera ** lfCams):
        if lfCams == NULL:
            return []
        cams = []
        cdef int i = 0
        while lfCams[i] is not NULL:
            cams.append(Camera(<uintptr_t>lfCams[i], self))
            i += 1
        return cams
    
    cdef _convertMounts(self, const lfMount ** lfMounts):
        if lfMounts == NULL:
            return []
        mounts = []
        cdef int i = 0
        while lfMounts[i] is not NULL:
            mounts.append(Mount(<uintptr_t>lfMounts[i], self))
            i += 1
        return mounts
    
    cdef _convertLenses(self, const lfLens ** lfLenses):
        if lfLenses == NULL:
            return []
        lenses = []
        cdef int i = 0
        while lfLenses[i] is not NULL:
            lenses.append(Lens(<uintptr_t>lfLenses[i], self))
            i += 1
        return lenses   

cdef class Camera:

    cdef lfCamera* lf
    cdef Database db

    def __cinit__(self, uintptr_t lfCam, Database db):
        self.lf = <lfCamera*> lfCam
        self.db = db
    
    property Maker:
        def __get__(self):
            return self.lf.Maker
    
    property Model:
        def __get__(self):
            return self.lf.Model
        
    property Variant:
        def __get__(self):
            return '' if self.lf.Variant is NULL else self.lf.Variant
        
    property Mount:
        def __get__(self):
            return '' if self.lf.Mount is NULL else self.lf.Mount
        
    property CropFactor:
        def __get__(self):
            return self.lf.CropFactor

    property Score:
        def __get__(self):
            return self.lf.Score
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Camera):
            if op == 2: # __eq__
                return (self.Maker == other.Maker and
                        self.Model == other.Model and
                        self.Variant == other.Variant and
                        self.Mount == other.Mount and
                        self.CropFactor == other.CropFactor)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return ('Camera(Maker: ' + self.Maker + '; Model: ' + self.Model +
            '; Variant: ' + self.Variant + '; Mount: ' + self.Mount + 
            '; Crop Factor: ' + str(self.CropFactor) +
            '; Score: ' + str(self.Score) + ')')

cdef _convertStringList(char** strings):
    if strings == NULL:
        return []
    result = []
    cdef int i = 0
    while strings[i] is not NULL:
        result.append(strings[i])
        i += 1
    return result

cdef class Mount:
    
    cdef lfMount* lf
    cdef Database db
    
    def __cinit__(self, uintptr_t lfMoun, Database db):
        self.lf = <lfMount*> lfMoun
        self.db = db
        
    property Name:
        def __get__(self):
            return self.lf.Name
        
    property Compat:
        def __get__(self):
            return _convertStringList(self.lf.Compat)
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Mount):
            if op == 2: # __eq__
                return self.Name == other.Name
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return 'Mount(Name: ' + self.Name + '; Compat: ' + str(self.Compat) + ')'

cdef class Lens:

    cdef lfLens* lf
    cdef Database db

    def __cinit__(self, uintptr_t lfLen, Database db):
        self.lf = <lfLens*> lfLen
        self.db = db
        
    property Maker:
        def __get__(self):
            return self.lf.Maker
    
    property Model:
        def __get__(self):
            return self.lf.Model
        
    property Type:
        def __get__(self):
            return self.lf.Type
        
    property Mounts:
        def __get__(self):
            return _convertStringList(self.lf.Mounts)                
        
    property MinFocal:
        def __get__(self):
            return self.lf.MinFocal
        
    property MaxFocal:
        def __get__(self):
            return self.lf.MaxFocal
        
    property MinAperture:
        def __get__(self):
            return self.lf.MinAperture
        
    property MaxAperture:
        def __get__(self):
            return self.lf.MaxAperture
        
    property CropFactor:
        def __get__(self):
            return self.lf.CropFactor

# see cdef extern block
#    IF LF_VERSION >= LF_VERSION_029:
#        property AspectRatio:
#            def __get__(self):
#                return self.lf.AspectRatio

    property CenterX:
        def __get__(self):
            return self.lf.CenterX
        
    property CenterY:
        def __get__(self):
            return self.lf.CenterY
        
    property RedCCI:
        def __get__(self):
            return self.lf.RedCCI

    property GreenCCI:
        def __get__(self):
            return self.lf.GreenCCI
        
    property BlueCCI:
        def __get__(self):
            return self.lf.BlueCCI

    property CalibDistortion:
        def __get__(self):
            return _convertCalibsDistortion(self.lf.CalibDistortion)

    property CalibTCA:
        def __get__(self):
            return _convertCalibsTCA(self.lf.CalibTCA)

    property CalibVignetting:
        def __get__(self):
            return _convertCalibsVignetting(self.lf.CalibVignetting)
        
    def interpolateDistortion(self, float focal):
        cdef lfLensCalibDistortion* res = <lfLensCalibDistortion*>PyMem_Malloc(sizeof(lfLensCalibDistortion))
        if lf_lens_interpolate_distortion(self.lf, focal, res):
            calib = _convertCalibDistortion(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
    
    def interpolateTCA(self, float focal):
        cdef lfLensCalibTCA* res = <lfLensCalibTCA*>PyMem_Malloc(sizeof(lfLensCalibTCA))
        if lf_lens_interpolate_tca(self.lf, focal, res):
            calib = _convertCalibTCA(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
    
    def interpolateVignetting(self, float focal, float aperture, float distance):
        cdef lfLensCalibVignetting* res = <lfLensCalibVignetting*>PyMem_Malloc(sizeof(lfLensCalibVignetting))
        if lf_lens_interpolate_vignetting(self.lf, focal, aperture, distance, res):
            calib = _convertCalibVignetting(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
                            
    property Score:
        def __get__(self):
            return self.lf.Score
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Lens):
            if op == 2: # __eq__
                return (self.Maker == other.Maker and
                        self.Model == other.Model and
                        self.MinFocal == other.MinFocal and
                        self.MaxFocal == other.MaxFocal and
                        self.MinAperture == other.MinAperture and
                        self.MaxAperture == other.MaxAperture and
                        self.CropFactor == other.CropFactor)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return ('Lens(Maker: ' + self.Maker + '; Model: ' + self.Model +
                '; Type: ' + enumKey(LensType, self.Type) + 
                '; Focal: ' + str(self.MinFocal) + '-' + str(self.MaxFocal) +
                '; Aperture: ' + str(self.MinAperture) + '-' + str(self.MaxAperture) +
                '; Crop factor: ' + str(self.CropFactor) + '; Score: ' + str(self.Score) + ')')

cdef _convertCalibsDistortion(lfLensCalibDistortion ** lfCalibs):
    if lfCalibs == NULL:
        return []
    calibs = []
    cdef int i = 0
    while lfCalibs[i] is not NULL:
        calib = _convertCalibDistortion(lfCalibs[i])
        calibs.append(calib)
        i += 1
    return calibs

cdef _convertCalibDistortion(lfLensCalibDistortion * lfCalib):
    calib = LensCalibDistortion(lfCalib.Model, lfCalib.Focal, 
                                [lfCalib.Terms[0], lfCalib.Terms[1], lfCalib.Terms[2]])
    return calib

cdef _convertCalibsTCA(lfLensCalibTCA ** lfCalibs):
    if lfCalibs == NULL:
        return []
    calibs = []
    cdef int i = 0
    while lfCalibs[i] is not NULL:
        calib = _convertCalibTCA(lfCalibs[i])
        calibs.append(calib)
        i += 1
    return calibs

cdef _convertCalibTCA(lfLensCalibTCA * lfCalib):
    calib = LensCalibTCA(lfCalib.Model, lfCalib.Focal, 
                         [lfCalib.Terms[0], lfCalib.Terms[1], lfCalib.Terms[2],
                          lfCalib.Terms[3], lfCalib.Terms[4], lfCalib.Terms[5]])
    return calib

cdef _convertCalibsVignetting(lfLensCalibVignetting ** lfCalibs):
    if lfCalibs == NULL:
        return []
    calibs = []
    cdef int i = 0
    while lfCalibs[i] is not NULL:
        calib = _convertCalibVignetting(lfCalibs[i])
        calibs.append(calib)
        i += 1
    return calibs

cdef _convertCalibVignetting(lfLensCalibVignetting * lfCalib):
    calib = LensCalibVignetting(lfCalib.Model, lfCalib.Focal, lfCalib.Aperture, lfCalib.Distance,
                                [lfCalib.Terms[0], lfCalib.Terms[1], lfCalib.Terms[2]])
    return calib

npPixelFormat = dict({np.uint8: LF_PF_U8,
                      np.uint16: LF_PF_U16,
                      np.uint32: LF_PF_U32,
                      np.float32: LF_PF_F32,
                      np.float64: LF_PF_F64
                      })

cdef class Modifier:

    cdef Lens lens
    cdef float crop
    cdef int width, height
    cdef lfModifier* lf
    
    # values used for initialize
    cdef float focal
    cdef float aperture
    cdef float distance

    def __cinit__(self, Lens lens not None, float crop, int width, int height):
        self.lens = lens
        self.crop = crop
        self.width = width
        self.height = height
        self.lf = lf_modifier_new (lens.lf, crop, width, height)
        
    def __dealloc__(self):
        lf_free(self.lf)

    def initialize(self, float focal, float aperture, float distance = 1.0, float scale = 0.0, 
                   lfLensType targeom = LF_RECTILINEAR, pixelFormat = np.uint8, 
                   int flags = LF_MODIFY_ALL, bint reverse = 0):
        lf_modifier_initialize (self.lf, self.lens.lf, npPixelFormat[pixelFormat],
                                focal, aperture, distance, scale,
                                targeom, flags, reverse)
        self.focal = focal
        self.aperture = aperture
        self.distance = distance
        
    property FocalLength:
        def __get__(self):
            return self.focal
        
    property Aperture:
        def __get__(self):
            return self.aperture
        
    property Distance:
        def __get__(self):
            return self.distance

    def applyGeometryDistortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=3, mode='c'] res = np.empty((height, width, 2), dtype=DTYPE)
        lf_modifier_apply_geometry_distortion(self.lf, xu, yu, width, height, &res[0,0,0])
        return res
    
    def applySubpixelDistortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=4, mode='c'] res = np.empty((height, width, 2, 3), dtype=DTYPE)
        lf_modifier_apply_subpixel_distortion(self.lf, xu, yu, width, height, &res[0,0,0,0])
        return res

    def applySubpixelGeometryDistortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=4, mode='c'] res = np.empty((height, width, 2, 3), dtype=DTYPE)
        lf_modifier_apply_subpixel_geometry_distortion(self.lf, xu, yu, width, height, &res[0,0,0,0])
        return res
    
    def _widthHeight(self, width, height):
        if width == -1:
            width = self.width
        if height == -1:
            height = self.height
        return width, height
        