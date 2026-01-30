"""Type stubs for lensfunpy._lensfun Cython module"""
from __future__ import annotations

from enum import Enum, IntEnum
from typing import Optional, List, Tuple, NamedTuple, Any
import numpy as np
from numpy.typing import NDArray

# Module-level version
lensfun_version: Tuple[int, int, int, int]

# Named tuples for calibration data
class LensCalibDistortion(NamedTuple):
    model: DistortionModel
    focal: float
    terms: List[float]

class LensCalibTCA(NamedTuple):
    model: TCAModel
    focal: float
    terms: List[float]

class LensCalibVignetting(NamedTuple):
    model: VignettingModel
    focal: float
    aperture: float
    distance: float
    terms: List[float]

# Enums
class ModifyFlags(IntEnum):
    """
    Flags for controlling which corrections to apply.
    """
    TCA: int
    VIGNETTING: int
    DISTORTION: int
    GEOMETRY: int
    SCALE: int
    ALL: int

class LensType(Enum):
    """
    Lens projection types.
    """
    UNKNOWN: int
    RECTILINEAR: int
    FISHEYE: int
    PANORAMIC: int
    EQUIRECTANGULAR: int
    FISHEYE_ORTHOGRAPHIC: int
    FISHEYE_STEREOGRAPHIC: int
    FISHEYE_EQUISOLID: int
    FISHEYE_THOBY: int

class DistortionModel(Enum):
    """
    Distortion model types.
    """
    NONE: int
    POLY3: int
    POLY5: int
    PTLENS: int

class TCAModel(Enum):
    """
    Transverse Chromatic Aberration model types.
    """
    NONE: int
    LINEAR: int
    POLY3: int

class VignettingModel(Enum):
    """
    Vignetting model types.
    """
    NONE: int
    PA: int

# Exceptions
class LensfunError(Exception):
    """Base exception for lensfunpy errors."""
    ...

class XMLFormatError(LensfunError):
    """Exception raised when XML database format is invalid."""
    ...

# Main classes
class Database:
    """
    The main entry point to use lensfunpy's functionality.
    
    Database instances load lens correction data from XML files and provide
    search functionality for cameras, lenses, and mounts.
    """
    
    def __init__(
        self,
        paths: Optional[List[str]] = None,
        xml: Optional[str] = None,
        load_common: bool = True,
        load_bundled: bool = True
    ) -> None:
        """
        Initialize a lensfun database.
        
        :param paths: XML files to load
        :param xml: load data from XML string
        :param load_common: whether to load the system/user database files
        :param load_bundled: whether to load the bundled database files
        """
        ...
    
    @property
    def cameras(self) -> List[Camera]:
        """
        All loaded cameras.
        
        :return: list of Camera instances
        """
        ...
    
    def find_cameras(
        self,
        maker: Optional[str] = None,
        model: Optional[str] = None,
        loose_search: bool = False
    ) -> List[Camera]:
        """
        Find cameras matching the given criteria.
        
        :param maker: return cameras from the given manufacturer
        :param model: return cameras matching the given model
        :param loose_search: whether to use fuzzy matching
        :return: list of matching Camera instances
        """
        ...
    
    @property
    def mounts(self) -> List[Mount]:
        """
        All loaded mounts.
        
        :return: list of Mount instances
        """
        ...
    
    def find_mount(self, name: str) -> Mount:
        """
        Find a mount by name.
        
        :param name: mount name
        :return: Mount instance
        """
        ...
    
    @property
    def lenses(self) -> List[Lens]:
        """
        All loaded lenses.
        
        :return: list of Lens instances
        """
        ...
    
    def find_lenses(
        self,
        camera: Camera,
        maker: Optional[str] = None,
        lens: Optional[str] = None,
        loose_search: bool = False
    ) -> List[Lens]:
        """
        Find lenses compatible with the given camera.
        
        :param camera: Camera instance to find compatible lenses for
        :param maker: filter by lens manufacturer
        :param lens: filter by lens model
        :param loose_search: whether to use fuzzy matching
        :return: list of matching Lens instances
        """
        ...

class Camera:
    """
    Represents a camera with its sensor and mount information.
    """
    
    @property
    def maker(self) -> str:
        """
        The camera manufacturer.
        """
        ...
    
    @property
    def model(self) -> str:
        """
        The camera model.
        """
        ...
    
    @property
    def variant(self) -> Optional[str]:
        """
        The camera variant.
        """
        ...
    
    @property
    def mount(self) -> Optional[str]:
        """
        The camera mount.
        """
        ...
    
    @property
    def crop_factor(self) -> float:
        """
        The crop factor of the camera sensor.
        """
        ...
    
    @property
    def score(self) -> int:
        """
        Search score.
        """
        ...
    
    def __eq__(self, other: object) -> bool: ...
    def __repr__(self) -> str: ...

class Mount:
    """
    Represents a lens mount system.
    """
    
    @property
    def name(self) -> str:
        """
        The mount name.
        """
        ...
    
    @property
    def compat(self) -> List[str]:
        """
        The mounts that are compatible to this one.
        
        :return: names of compatible mounts
        """
        ...
    
    def __eq__(self, other: object) -> bool: ...
    def __repr__(self) -> str: ...

class Lens:
    """
    Represents a lens with its optical characteristics and calibration data.
    """
    
    @property
    def maker(self) -> str:
        """
        The lens manufacturer.
        """
        ...
    
    @property
    def model(self) -> str:
        """
        The lens model.
        """
        ...
    
    @property
    def type(self) -> LensType:
        """
        The lens type.
        """
        ...
    
    @property
    def mounts(self) -> List[str]:
        """
        Compatible mounts.
        """
        ...
    
    @property
    def min_focal(self) -> float:
        """
        Minimum focal length.
        """
        ...
    
    @property
    def max_focal(self) -> float:
        """
        Maximum focal length.
        """
        ...
    
    @property
    def min_aperture(self) -> float:
        """
        Minimum aperture (maximum f-number).
        """
        ...
    
    @property
    def max_aperture(self) -> float:
        """
        Maximum aperture (minimum f-number).
        """
        ...
    
    @property
    def crop_factor(self) -> float:
        """
        The crop factor for which the lens is designed.
        """
        ...
    
    @property
    def center_x(self) -> float:
        """
        X coordinate of optical center.
        """
        ...
    
    @property
    def center_y(self) -> float:
        """
        Y coordinate of optical center.
        """
        ...
    
    @property
    def score(self) -> int:
        """
        Search score.
        """
        ...
    
    @property
    def has_distortion_calibration(self) -> bool:
        """
        Whether distortion calibration data is available.
        """
        ...
    
    @property
    def has_tca_calibration(self) -> bool:
        """
        Whether TCA calibration data is available.
        """
        ...
    
    @property
    def has_vignetting_calibration(self) -> bool:
        """
        Whether vignetting calibration data is available.
        """
        ...
    
    @property
    def distortion_calibrations(self) -> List[LensCalibDistortion]:
        """
        Distortion calibration data.
        """
        ...
    
    @property
    def tca_calibrations(self) -> List[LensCalibTCA]:
        """
        TCA calibration data.
        """
        ...
    
    @property
    def vignetting_calibrations(self) -> List[LensCalibVignetting]:
        """
        Vignetting calibration data.
        """
        ...
    
    def interpolate_distortion(self, focal: float) -> Optional[LensCalibDistortion]:
        """
        Interpolate distortion calibration for the given focal length.
        
        :param focal: focal length in mm
        :return: interpolated calibration data, or None if unavailable
        """
        ...
    
    def interpolate_tca(self, focal: float) -> Optional[LensCalibTCA]:
        """
        Interpolate TCA calibration for the given focal length.
        
        :param focal: focal length in mm
        :return: interpolated calibration data, or None if unavailable
        """
        ...
    
    def interpolate_vignetting(
        self,
        focal: float,
        aperture: float,
        distance: float
    ) -> Optional[LensCalibVignetting]:
        """
        Interpolate vignetting calibration for the given parameters.
        
        :param focal: focal length in mm
        :param aperture: aperture (f-number)
        :param distance: focus distance in meters
        :return: interpolated calibration data, or None if unavailable
        """
        ...
    
    def __eq__(self, other: object) -> bool: ...
    def __repr__(self) -> str: ...

class Modifier:
    """
    Image correction modifier for applying lens distortion corrections.
    """
    
    def __init__(
        self,
        lens: Lens,
        crop: float,
        width: int,
        height: int
    ) -> None:
        """
        Create a modifier for lens correction.
        
        :param lens: Lens to use for correction
        :param crop: crop factor
        :param width: width of image in pixels
        :param height: height of image in pixels
        """
        ...
    
    def initialize(
        self,
        focal: float,
        aperture: float,
        distance: float = 1000.0,
        scale: float = 0.0,
        targeom: LensType = LensType.RECTILINEAR,
        pixel_format: Any = np.uint8,
        flags: int = ModifyFlags.ALL,
        reverse: bool = False
    ) -> None:
        """
        Initialize the modifier with shooting parameters.
        
        :param focal: The focal length in mm at which the image was taken
        :param aperture: The aperture (f-number) at which the image was taken
        :param distance: The approximative focus distance in meters (distance > 0)
        :param scale: An additional scale factor to be applied onto the image (1.0 - no scaling; 0.0 - automatic scaling)
        :param targeom: Target geometry. If LF_MODIFY_GEOMETRY is set in flags and targeom
                       is different from lens.type, a geometry conversion will be applied on the image
        :param pixel_format: Pixel format of the image
        :param flags: A set of flags (see ModifyFlags) telling which distortions you want corrected.
                     A value of ModifyFlags.ALL orders correction of everything possible
        :param reverse: If true, a reverse transform will be prepared (undistorted -> distorted)
        """
        ...
    
    @property
    def lens(self) -> Lens:
        """
        The Lens used when creating the modifier.
        """
        ...
    
    @property
    def crop(self) -> float:
        """
        The crop factor used when creating the modifier.
        """
        ...
    
    @property
    def width(self) -> int:
        """
        The image width used when creating the modifier.
        """
        ...
    
    @property
    def height(self) -> int:
        """
        The image height used when creating the modifier.
        """
        ...
    
    @property
    def focal_length(self) -> float:
        """
        The focal length used when initialising the modifier.
        """
        ...
    
    @property
    def aperture(self) -> float:
        """
        The aperture used when initialising the modifier.
        """
        ...
    
    @property
    def distance(self) -> float:
        """
        The subject distance used when initialising the modifier.
        """
        ...
    
    @property
    def scale(self) -> float:
        """
        The scale used when initialising the modifier.
        """
        ...
    
    def apply_geometry_distortion(
        self,
        xu: float = 0,
        yu: float = 0,
        width: int = -1,
        height: int = -1
    ) -> Optional[NDArray[np.float32]]:
        """
        Apply geometry distortion correction.
        
        :param xu: X coordinate of upper left corner
        :param yu: Y coordinate of upper left corner
        :param width: width of the area to correct (-1 for full image)
        :param height: height of the area to correct (-1 for full image)
        :return: coordinates for geometry distortion correction (height, width, 2),
                or None if calibration data missing
        """
        ...
    
    def apply_subpixel_distortion(
        self,
        xu: float = 0,
        yu: float = 0,
        width: int = -1,
        height: int = -1
    ) -> Optional[NDArray[np.float32]]:
        """
        Apply subpixel distortion correction (for TCA).
        
        :param xu: X coordinate of upper left corner
        :param yu: Y coordinate of upper left corner
        :param width: width of the area to correct (-1 for full image)
        :param height: height of the area to correct (-1 for full image)
        :return: per-channel coordinates for subpixel distortion correction (height, width, 3, 2),
                or None if calibration data missing
        """
        ...
    
    def apply_subpixel_geometry_distortion(
        self,
        xu: float = 0,
        yu: float = 0,
        width: int = -1,
        height: int = -1
    ) -> Optional[NDArray[np.float32]]:
        """
        Apply combined geometry and subpixel distortion correction.
        
        :param xu: X coordinate of upper left corner
        :param yu: Y coordinate of upper left corner
        :param width: width of the area to correct (-1 for full image)
        :param height: height of the area to correct (-1 for full image)
        :return: per-channel coordinates for combined distortion and subpixel distortion correction (height, width, 3, 2),
                or None if calibration data missing
        """
        ...
    
    def apply_color_modification(
        self,
        img: NDArray[Any]
    ) -> bool:
        """
        Apply vignetting correction to an image in place.
        
        :param img: Image (h,w,3) for which to apply the vignetting correction, in place
        :return: true if vignetting correction was applied, otherwise false
        """
        ...
