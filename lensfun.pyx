from libc.stdint cimport uintptr_t

import numpy as np
cimport numpy as np
np.import_array()

# We cannot use Cython's C++ support here, as lensfun.h exposes functions
# in an 'extern "C"' block, which is not supported yet. Therefore, lensfun's
# C interface is used.

# see gimplensfun for how to use lensfun and how to use EXIF info
# it also includes it's own image.cpp functionality

DTYPE = np.float32
ctypedef np.float32_t DTYPE_t

cdef extern from "lensfun.h":
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
    struct lfDatabase:
        pass
    struct lfCamera:
        lfMLstr Maker
        lfMLstr Model
        lfMLstr Variant
        float CropFactor
        int Score
    struct lfLens:
        lfMLstr Maker
        lfMLstr Model
        float MinFocal
        float MaxFocal
        float MinAperture
        float MaxAperture
        int Score
    struct lfModifier:
        pass
    void lf_free (void *data)
    lfDatabase *lf_db_new ()
    void lf_db_destroy (lfDatabase *db)
    lfError lf_db_load (lfDatabase *db)
    lfError lf_db_load_file (lfDatabase *db, const char *filename)
    const lfCamera **lf_db_find_cameras (const lfDatabase *db, const char *maker, const char *model)
    const lfCamera **lf_db_find_cameras_ext (const lfDatabase *db, const char *maker, const char *model, int sflags)
    const lfLens **lf_db_find_lenses_hd (const lfDatabase *db, const lfCamera *camera, const char *maker, const char *lens, int sflags)
    lfModifier *lf_modifier_new (const lfLens *lens, float crop, int width, int height)
    void lf_modifier_destroy (lfModifier *modifier)
    int lf_modifier_initialize (lfModifier *modifier, const lfLens *lens, lfPixelFormat format,
                                float focal, float aperture, float distance, float scale,
                                lfLensType targeom, int flags, int reverse)
    int lf_modifier_apply_geometry_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)
    int lf_modifier_apply_subpixel_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)
    int lf_modifier_apply_subpixel_geometry_distortion (lfModifier *modifier, float xu, float yu, int width, int height, float *res)

def enum(**enums):
    return type('Enum', (), enums)

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

cdef class Database:

    cdef lfDatabase* lf

    def __cinit__(self):
        self.lf = lf_db_new()
            
    def __init__(self, filenames = None):
        if filenames is not None:
            for filename in filenames:
                err = lf_db_load_file(self.lf, filename)
        else:
            err = lf_db_load(self.lf)
        
    def __dealloc__(self):
        lf_db_destroy(self.lf)
        
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
            lfCams = lf_db_find_cameras_ext (self.lf, cmaker, cmodel, LF_SEARCH_LOOSE)
        else:
            lfCams = lf_db_find_cameras (self.lf, maker, model)
        if lfCams == NULL:
            return []
        cams = []
        cdef int i = 0
        while lfCams[i] is not NULL:
            cams.append(Camera(<uintptr_t>lfCams[i]))
            i += 1
        lf_free(lfCams)
        return cams
    
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
        if lfLenses == NULL:
            return []
        lenses = []
        cdef int i = 0
        while lfLenses[i] is not NULL:
            lenses.append(Lens(<uintptr_t>lfLenses[i]))
            i += 1            
        lf_free(lfLenses)
        return lenses       

# TODO Camera and Lens objects could hold a reference to the Database object they came from
#      so that the Database (and its Camera and Lens objects) is only deallocated when
#      no queried objects are alive anymore, otherwise there might be unexpected behaviours
# -> write unit test which triggers this      
    
cdef class Camera:

    cdef lfCamera* lf

    def __cinit__(self, uintptr_t lfCam):
        self.lf = <lfCamera*> lfCam
    
    property Maker:
        def __get__(self):
            return self.lf.Maker
    
    property Model:
        def __get__(self):
            return self.lf.Model
        
    property Variant:
        def __get__(self):
            return '' if self.lf.Variant is NULL else self.lf.Variant
        
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
                        self.CropFactor == other.CropFactor)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return ('Camera(Maker: ' + self.Maker + '; Model: ' + self.Model +
            '; Variant: ' + self.Variant + '; Crop Factor: ' + str(self.CropFactor) +
            '; Score: ' + str(self.Score) + ')')

cdef class Lens:

    cdef lfLens* lf 

    def __cinit__(self, uintptr_t lfLen):
        self.lf = <lfLens*> lfLen
        
    property Maker:
        def __get__(self):
            return self.lf.Maker
    
    property Model:
        def __get__(self):
            return self.lf.Model
        
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
                        self.MaxAperture == other.MaxAperture)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return ('Lens(Maker: ' + self.Maker + '; Model: ' + self.Model +
            '; Focal: ' + str(self.MinFocal) + '-' + str(self.MaxFocal) +
            '; Aperture: ' + str(self.MinAperture) + '-' + str(self.MaxAperture) +
            '; Score: ' + str(self.Score) + ')')

cdef class Modifier:

    cdef Lens lens
    cdef float crop
    cdef int width, height
    cdef lfModifier* lf

    def __cinit__(self, Lens lens not None, float crop, int width, int height):
        self.lens = lens
        self.crop = crop
        self.width = width
        self.height = height
        self.lf = lf_modifier_new (lens.lf, crop, width, height)
        
    def __dealloc__(self):
        lf_free(self.lf)

    def initialize(self, float focal, float aperture, float distance = 1.0, float scale = 0.0, 
                   lfLensType targeom = LF_RECTILINEAR, int flags = LF_MODIFY_ALL, bint reverse = 0):
        lf_modifier_initialize (self.lf, self.lens.lf, LF_PF_U8,
                                focal, aperture, distance, scale,
                                targeom, flags, reverse)

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
        