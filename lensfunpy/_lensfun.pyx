# cython: c_string_type=unicode, c_string_encoding=utf8
# cython: embedsignature=True

from libc.stdint cimport uintptr_t
from cpython.mem cimport PyMem_Malloc, PyMem_Free

import os
import glob
from enum import Enum, IntEnum
from collections import namedtuple

import numpy as np
cimport numpy as np
np.import_array()

# We cannot use Cython's C++ support here, as lensfun.h exposes functions
# in an 'extern "C"' block, which is not supported yet. Therefore, lensfun's
# C interface is used.

DTYPE = np.float32
ctypedef np.float32_t DTYPE_t

# added in 0.3.2 to lfError enum
# we need to handle it, so we define it manually here
LF_NO_DATABASE = 2

cdef extern from "lensfun.h":   
    int LF_VERSION_MAJOR
    int LF_VERSION_MINOR
    int LF_VERSION_MICRO
    int LF_VERSION_BUGFIX

    int RED
    int GREEN
    int BLUE
    int LF_CR_3(int a, int b, int c)

    ctypedef char *lfMLstr
    
    enum lfError:
        LF_NO_ERROR
        LF_WRONG_FORMAT
        # LF_NO_DATABASE (=2) available in >= 0.3.2
        
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
        LF_FISHEYE_ORTHOGRAPHIC
        LF_FISHEYE_STEREOGRAPHIC
        LF_FISHEYE_EQUISOLID
        LF_FISHEYE_THOBY
        
    enum lfDistortionModel:
        LF_DIST_MODEL_NONE
        LF_DIST_MODEL_POLY3
        LF_DIST_MODEL_POLY5
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
        float CenterX
        float CenterY
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
    int lf_modifier_apply_color_modification (lfModifier *modifier, void *pixels, float x, float y, int width, int height, int comp_role, int row_stride)
    
cdef extern from "back_compat.h":
    int lf_lens_interpolate_distortion_ (const lfLens *lens, float focal, lfLensCalibDistortion *res)
    int lf_lens_interpolate_tca_ (const lfLens *lens, float focal, lfLensCalibTCA *res)
    int lf_lens_interpolate_vignetting_ (const lfLens *lens, float focal, float aperture, float distance, lfLensCalibVignetting *res)

ctypedef fused img_dtypes:
    unsigned char
    unsigned int
    unsigned long
    unsigned long long
    float
    double

lensfun_version = (LF_VERSION_MAJOR, LF_VERSION_MINOR, LF_VERSION_MICRO, LF_VERSION_BUGFIX)

class ModifyFlags(IntEnum):
    TCA=LF_MODIFY_TCA
    VIGNETTING=LF_MODIFY_VIGNETTING
    DISTORTION=LF_MODIFY_DISTORTION
    GEOMETRY=LF_MODIFY_GEOMETRY
    SCALE=LF_MODIFY_SCALE
    ALL=LF_MODIFY_ALL

class LensType(Enum):
    UNKNOWN=LF_UNKNOWN
    RECTILINEAR=LF_RECTILINEAR
    FISHEYE=LF_FISHEYE
    PANORAMIC=LF_PANORAMIC
    EQUIRECTANGULAR=LF_EQUIRECTANGULAR
    FISHEYE_ORTHOGRAPHIC=LF_FISHEYE_ORTHOGRAPHIC
    FISHEYE_STEREOGRAPHIC=LF_FISHEYE_STEREOGRAPHIC
    FISHEYE_EQUISOLID=LF_FISHEYE_EQUISOLID
    FISHEYE_THOBY=LF_FISHEYE_THOBY

class DistortionModel(Enum):
    NONE=LF_DIST_MODEL_NONE
    POLY3=LF_DIST_MODEL_POLY3
    POLY5=LF_DIST_MODEL_POLY5
    PTLENS=LF_DIST_MODEL_PTLENS

LensCalibDistortion = namedtuple('LensCalibDistortion', ['model', 'focal', 'terms'])

class TCAModel(Enum):
    NONE=LF_TCA_MODEL_NONE
    LINEAR=LF_TCA_MODEL_LINEAR
    POLY3=LF_TCA_MODEL_POLY3

LensCalibTCA = namedtuple('LensCalibTCA', ['model', 'focal', 'terms'])

class VignettingModel(Enum):
    NONE=LF_VIGNETTING_MODEL_NONE
    PA=LF_VIGNETTING_MODEL_PA

LensCalibVignetting = namedtuple('LensCalibVignetting', ['model', 'focal', 'aperture', 'distance', 'terms'])

cdef class Database:
    """
    The main entry point to use lensfunpy's functionality.
    """

    cdef lfDatabase* lf

    def __cinit__(self):
        self.lf = lf_db_new()

    def __init__(self, paths=None, xml=None, load_common=True, load_bundled=True):
        """Database.__init__(paths=None, xml=None, load_common=True, load_bundled=True)
        
        :type paths: iterable of str
        :param paths: XML files to load 
        :param str xml: load data from XML string
        :param bool load_common: whether to load the system/user database files
        :param bool load_bundled: whether to load the bundled database files
        """
        if paths is None:
            paths = []

        if load_bundled:
            root = os.path.abspath(os.path.dirname(__file__))
            xml_glob = os.path.join(root, 'db_files', '*.xml')
            paths += glob.glob(xml_glob)

        for path in paths:
            handleError(lf_db_load_file(self.lf, _chars(path)))

        if xml:
            xml = _chars(xml.strip()) # stripping as lensfun is very strict here
            handleError(lf_db_load_data(self.lf, 'XML', xml, len(xml)))

        if load_common:
            code = lf_db_load(self.lf)
            if code == LF_NO_DATABASE:
                # no global db files were found (could be loaded)
                # ignore this since we bundle db files
                pass
            else:
                handleError(code)

    def __dealloc__(self):
        lf_db_destroy(self.lf)
    
    property cameras:
        """
        All loaded cameras.
        
        :rtype: list of :class:`lensfunpy.Camera` instances
        """
        def __get__(self):
            cdef const lfCamera *const * lfCams
            lfCams = lf_db_get_cameras(self.lf)
            cams = self._convertCams(<const lfCamera **>lfCams)
            # NOTE: lfCams must not be lf_free'd! it points to an internal list (not a copy!)
            return cams
        
    def find_cameras(self, maker=None, model=None, loose_search=False):
        """
        
        :param str maker: return cameras from the given manufacturer
        :param str model: return cameras matching the given model
        :param bool loose_search:
        :rtype: list of :class:`lensfunpy.Camera` instances
        """
        cdef const lfCamera ** lfCams
        cdef char* cmaker
        cdef char* cmodel
        if maker is None:
            cmaker = NULL
        else:
            # direct assignment to cmaker is NOT possible (as the C string is tied to the lifetime of the Python string)
            maker = _chars(maker)
            cmaker = maker
        if model is None:
            cmodel = NULL
        else:
            model = _chars(model)
            cmodel = model
        if loose_search:
            lfCams = lf_db_find_cameras_ext(self.lf, cmaker, cmodel, LF_SEARCH_LOOSE)
        else:
            lfCams = lf_db_find_cameras(self.lf, cmaker, cmodel)
        cams = self._convertCams(lfCams)
        lf_free(lfCams)
        return cams
    
    property mounts:
        """
        All loaded mounts.
        
        :rtype: list of :class:`lensfunpy.Mount` instances
        """
        def __get__(self):
            cdef const lfMount *const * lfMounts
            lfMounts = lf_db_get_mounts(self.lf)
            mounts = self._convertMounts(<const lfMount **>lfMounts)
            # NOTE: lfMounts must not be lf_free'd! it points to an internal list (not a copy!)
            return mounts
        
    def find_mount(self, name):
        """
        
        :param str name:
        :rtype: :class:`lensfunpy.Mount` instance
        """
        cdef const lfMount * lfMoun
        lfMoun = lf_db_find_mount(self.lf, _chars(name))
        return Mount(<uintptr_t>lfMoun, self)
    
    property lenses:
        """
        All loaded lenses.
        
        :rtype: list of :class:`lensfunpy.Lens` instances
        """
        def __get__(self):
            cdef const lfLens *const * lfLenses
            lfLenses = lf_db_get_lenses(self.lf)
            lenses = self._convertLenses(<const lfLens **>lfLenses)
            # NOTE: lfLenses must not be lf_free'd! it points to an internal list (not a copy!)
            return lenses
    
    def find_lenses(self, Camera camera not None, maker=None, lens=None, loose_search=False):
        """
        
        :param lensfunpy.Camera camera: 
        :param str maker:
        :param str lens:
        :param bool loose_search:
        :rtype: list of :class:`lensfunpy.Lens` instances
        """
        cdef const lfLens ** lfLenses
        cdef char* cmaker
        cdef char* clens
        if maker is None:
            cmaker = NULL
        else:
            maker = _chars(maker)
            cmaker = maker
        if lens is None:
            clens = NULL
        else:
            lens = _chars(lens)
            clens = lens
        lfLenses = lf_db_find_lenses_hd(self.lf, camera.lf, cmaker, clens, LF_SEARCH_LOOSE if loose_search else 0)
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
    
    property maker:
        """
        The camera manufacturer.
        
        :rtype: str
        """
        def __get__(self):
            return self.lf.Maker
    
    property model:
        """
        The camera model.
        
        :rtype: str
        """
        def __get__(self):
            return self.lf.Model
        
    property variant:
        """
        The camera variant.
        
        :rtype: str|None
        """
        def __get__(self):
            return None if self.lf.Variant is NULL else self.lf.Variant
        
    property mount:
        """
        The camera mount.
        
        :rtype: str|None
        """
        def __get__(self):
            return None if self.lf.Mount is NULL else self.lf.Mount
        
    property crop_factor:
        """
        The crop factor of the camera sensor.
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.CropFactor

    property score:
        """
        Search score. 
        
        :rtype: int
        """
        def __get__(self):
            return self.lf.Score
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Camera):
            if op == 2: # __eq__
                return (self.maker == other.maker and
                        self.model == other.model and
                        self.variant == other.variant and
                        self.mount == other.mount and
                        self.crop_factor == other.crop_factor)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        variant = '; Variant: ' + self.variant if self.variant else ''
        mount = '; Mount: ' + self.mount if self.mount else ''
        return ('Camera(Maker: ' + self.maker + '; Model: ' + self.model +
            variant + mount + 
            '; Crop Factor: ' + str(self.crop_factor) +
            '; Score: ' + str(self.score) + ')')

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
        
    property name:
        """
        The mount name.
        
        :rtype: str
        """
        def __get__(self):
            return self.lf.Name
        
    property compat:
        """
        The mounts that are compatible to this one.
        
        :return: names of compatible mounts
        :rtype: list of str
        """
        def __get__(self):
            return _convertStringList(self.lf.Compat)
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Mount):
            if op == 2: # __eq__
                return self.name == other.name
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        return 'Mount(Name: ' + self.name + '; Compat: ' + str(self.compat) + ')'

cdef class Lens:

    cdef lfLens* lf
    cdef Database db

    def __cinit__(self, uintptr_t lfLen, Database db):
        self.lf = <lfLens*> lfLen
        self.db = db
        
    property maker:
        """
        The lens manufacturer.
        
        :rtype: str
        """
        def __get__(self):
            return self.lf.Maker
    
    property model:
        """
        The lens model.
        
        :rtype: str
        """
        def __get__(self):
            return self.lf.Model
        
    property type:
        """
        The lens type.
        
        :rtype: :class:`lensfunpy.LensType` instance
        """
        def __get__(self):
            try:
                return next(t for t in LensType if t.value == self.lf.Type)
            except StopIteration:
                raise NotImplementedError("Unknown lens type ({}), please report an issue for lensfunpy".format(self.lf.Type))
        
    property mounts:
        """
        Compatible mounts.
        
        :rtype: list of :class:`lensfunpy.Mount` instances
        """
        def __get__(self):
            return _convertStringList(self.lf.Mounts)                
        
    property min_focal:
        """
        Minimum focal length.
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.MinFocal
        
    property max_focal:
        """
        Maximum focal length.
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.MaxFocal
        
    property min_aperture:
        """
        Minimum aperture. Returns None if unknown.
        
        :rtype: float|None
        """
        def __get__(self):
            val = self.lf.MinAperture
            return val if val != 0.0 else None
        
    property max_aperture:
        """
        Maximum aperture. Returns None if unknown.
        
        :rtype: float|None
        """
        def __get__(self):
            val = self.lf.MaxAperture
            return val if val != 0.0 else None
        
    property crop_factor:
        """
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.CropFactor

    property center_x:
        """
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.CenterX
        
    property center_y:
        """
        
        :rtype: float
        """
        def __get__(self):
            return self.lf.CenterY

    property calib_distortion:
        """
        
        :rtype: list of :class:`lensfunpy.LensCalibDistortion` instances
        """
        def __get__(self):
            return _convertCalibsDistortion(self.lf.CalibDistortion)

    property calib_tca:
        """
        
        :rtype: list of :class:`lensfunpy.LensCalibTCA` instances
        """
        def __get__(self):
            return _convertCalibsTCA(self.lf.CalibTCA)

    property calib_vignetting:
        """
        
        :rtype: list of :class:`lensfunpy.LensCalibTCA` instances
        """
        def __get__(self):
            return _convertCalibsVignetting(self.lf.CalibVignetting)
        
    def interpolate_distortion(self, float focal):
        """
        
        :rtype: lensfunpy.LensCalibDistortion
        """
        cdef lfLensCalibDistortion* res = <lfLensCalibDistortion*>PyMem_Malloc(sizeof(lfLensCalibDistortion))
        if lf_lens_interpolate_distortion_(self.lf, focal, res):
            calib = _convertCalibDistortion(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
    
    def interpolate_tca(self, float focal):
        """
        
        :rtype: lensfunpy.LensCalibTCA
        """
        cdef lfLensCalibTCA* res = <lfLensCalibTCA*>PyMem_Malloc(sizeof(lfLensCalibTCA))
        if lf_lens_interpolate_tca_(self.lf, focal, res):
            calib = _convertCalibTCA(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
    
    def interpolate_vignetting(self, float focal, float aperture, float distance):
        """
        
        :rtype: lensfunpy.LensCalibVignetting
        """
        cdef lfLensCalibVignetting* res = <lfLensCalibVignetting*>PyMem_Malloc(sizeof(lfLensCalibVignetting))
        if lf_lens_interpolate_vignetting_(self.lf, focal, aperture, distance, res):
            calib = _convertCalibVignetting(res)
        else:
            calib = None
        PyMem_Free(res)
        return calib
                            
    property score:
        """
        Search score. 
        
        :rtype: int
        """
        def __get__(self):
            return self.lf.Score
        
    def __richcmp__(self, other, int op):
        if isinstance(other, Lens):
            if op == 2: # __eq__
                return (self.maker == other.maker and
                        self.model == other.model and
                        self.min_focal == other.min_focal and
                        self.max_focal == other.max_focal and
                        self.min_aperture == other.min_aperture and
                        self.max_aperture == other.max_aperture and
                        self.crop_factor == other.crop_factor)
            else:
                return NotImplemented
        else:
            return NotImplemented
        
    def __repr__(self):
        min_ap = self.min_aperture if self.min_aperture is not None else 'unknown'
        max_ap = self.max_aperture if self.max_aperture is not None else 'unknown'
        return ('Lens(Maker: ' + self.maker + '; Model: ' + self.model +
                '; Type: ' + self.type.name + 
                '; Focal: ' + str(self.min_focal) + '-' + str(self.max_focal) +
                '; Aperture: ' + str(self.min_aperture) + '-' + str(self.max_aperture) +
                '; Crop factor: ' + str(self.crop_factor) + '; Score: ' + str(self.score) + ')')

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
    dist_model = next(m for m in DistortionModel if m.value == lfCalib.Model)
    calib = LensCalibDistortion(dist_model, lfCalib.Focal,
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
    tca_model = next(m for m in TCAModel if m.value == lfCalib.Model)
    calib = LensCalibTCA(tca_model, lfCalib.Focal, 
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
    vign_model = next(m for m in VignettingModel if m.value == lfCalib.Model)
    calib = LensCalibVignetting(vign_model, lfCalib.Focal, lfCalib.Aperture, lfCalib.Distance,
                                [lfCalib.Terms[0], lfCalib.Terms[1], lfCalib.Terms[2]])
    return calib

npPixelFormat = dict({np.uint8: LF_PF_U8,
                      np.uint16: LF_PF_U16,
                      np.uint32: LF_PF_U32,
                      np.float32: LF_PF_F32,
                      np.float64: LF_PF_F64
                      })

cdef class Modifier:

    cdef Lens _lens
    cdef float _crop
    cdef int _width, _height
    cdef lfModifier* lf
    
    # values used for initialize
    cdef float _focal
    cdef float _aperture
    cdef float _distance
    cdef float _scale

    def __init__(self, Lens lens not None, float crop, int width, int height):
        """
        :param lensfunpy.Lens: 
        :param float crop: crop factor of ...?
        :param int width: width of image in pixels
        :param int height: height of image in pixels
        """
        self._lens = lens
        self._crop = crop
        self._width = width
        self._height = height
        self.lf = lf_modifier_new(lens.lf, crop, width, height)
        
    def __dealloc__(self):
        lf_modifier_destroy(self.lf)

    def initialize(self, float focal, float aperture, float distance=1000.0, float scale=0.0, 
                   targeom=LensType.RECTILINEAR, pixel_format=np.uint8, 
                   int flags=ModifyFlags.ALL, bint reverse=0):
        """
        :param float focal: The focal length in mm at which the image was taken. 
        :param float aperture: The aperture (f-number) at which the image was taken. 
        :param float distance: The approximative focus distance in meters (distance > 0). 
        :param float scale: An additional scale factor to be applied onto the image (1.0 - no scaling; 0.0 - automatic scaling).
        :param lensfunpy.LensType targeom: Target geometry. If LF_MODIFY_GEOMETRY is set in flags and targeom
                                           is different from lens.type, a geometry conversion will be applied on the image.
        :param pixel_format: Pixel format of the image.
        :param int flags: A set of flags (see :class:`lensfunpy.ModifyFlags`) telling which
                          distortions you want corrected. 
                          A value of `ModifyFlags.ALL` orders correction of everything possible 
                          (will enable all correction models present in lens description).
        :param bool reverse: If this parameter is true, a reverse transform will be prepared. 
                             That is, you take an undistorted image as input and convert it
                             so that it will look as if it would be a shot made with lens.
        """
        lf_modifier_initialize (self.lf, self._lens.lf, npPixelFormat[pixel_format],
                                focal, aperture, distance, scale,
                                targeom.value, flags, reverse)
        self._focal = focal
        self._aperture = aperture
        self._distance = distance
        self._scale = scale
        
    property lens:
        """
        The :class:`lensfunpy.Lens` used when creating the modifier.
        """
        def __get__(self):
            return self._lens
        
    property crop:
        """
        The crop factor used when creating the modifier.
        
        :rtype: float
        """
        def __get__(self):
            return self._crop
        
    property width:
        """
        The image width used when creating the modifier.
        
        :rtype: int
        """
        def __get__(self):
            return self._width
        
    property height:
        """
        The image height used when creating the modifier.
        
        :rtype: int
        """
        def __get__(self):
            return self._height
        
    property focal_length:
        """
        The focal lenght used when initialising the modifier.
        
        :rtype: float
        """
        def __get__(self):
            return self._focal
        
    property aperture:
        """
        The aperture used when initialising the modifier.
        
        :rtype: float
        """
        def __get__(self):
            return self._aperture
        
    property distance:
        """
        The subject distance used when initialising the modifier.
        
        :rtype: float
        """
        def __get__(self):
            return self._distance
        
    property scale:
        """
        The scale used when initialising the modifier.
        
        :rtype: float
        """
        def __get__(self):
            return self._scale

    def apply_geometry_distortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        """
        
        :return: coordinates for geometry distortion correction
        :rtype: ndarray of shape (height, width, 2)
        """
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=3, mode='c'] res = np.empty((height, width, 2), dtype=DTYPE)
        lf_modifier_apply_geometry_distortion(self.lf, xu, yu, width, height, &res[0,0,0])
        return res
    
    def apply_subpixel_distortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        """
        
        :return: per-channel coordinates for subpixel distortion correction
        :rtype: ndarray of shape (height, width, 2, 3)
        """
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=4, mode='c'] res = np.empty((height, width, 2, 3), dtype=DTYPE)
        lf_modifier_apply_subpixel_distortion(self.lf, xu, yu, width, height, &res[0,0,0,0])
        return res

    def apply_subpixel_geometry_distortion(self, float xu = 0, float yu = 0, int width = -1, int height = -1):
        """
        
        :return: per-channel coordinates for combined distortion and subpixel distortion correction
        :rtype: ndarray of shape (height, width, 2, 3)
        """
        width, height = self._widthHeight(width, height)
        cdef np.ndarray[DTYPE_t, ndim=4, mode='c'] res = np.empty((height, width, 2, 3), dtype=DTYPE)
        lf_modifier_apply_subpixel_geometry_distortion(self.lf, xu, yu, width, height, &res[0,0,0,0])
        return res
    
    def apply_color_modification(self, img_dtypes[:,:,::1] img):
        """

        :param ndarray img: Image (h,w,3) for which to apply the vignetting correction, in place.
        :return: true if vignetting correction was applied, otherwise false
        :rtype: bool
        """
        cdef int comp_role = LF_CR_3(RED, GREEN, BLUE)
        
        if img.ndim != 3 or img.shape[0] != self.height or img.shape[1] != self.width or img.shape[2] != 3:
            raise ValueError(f"image must be of shape ({self.height}, {self.width}, 3)")
        
        row_stride = img.shape[1] * 3 * img.itemsize
        return bool(lf_modifier_apply_color_modification(
            self.lf, &img[0,0,0], 0, 0, self.width, self.height, comp_role, row_stride))

    def _widthHeight(self, width, height):
        if width == -1:
            width = self.width
        if height == -1:
            height = self.height
        return width, height

class LensfunError(Exception):
    pass

class XMLFormatError(LensfunError):
    pass

cdef handleError(int code):
    if code < 0:
        raise OSError((-code, os.strerror(-code))) 
    elif code > 0:
        if code == LF_WRONG_FORMAT:
            raise XMLFormatError
        elif code == LF_NO_DATABASE:
            raise LensfunError('Database file(s) could not be loaded')
        else:
            raise LensfunError('Unknown lensfun error (code: {}), please report an issue for lensfunpy'.format(code))

def _chars(s):
    if isinstance(s, unicode):
        # convert unicode to chars
        s = (<unicode>s).encode('UTF-8')
    return s
