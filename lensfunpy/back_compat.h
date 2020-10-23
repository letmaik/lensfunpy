#include "lensfun.h"

#define LF_VERSION_0_3_95 0x00035F00
#if (LF_VERSION < LF_VERSION_0_3_95)

#define lf_lens_interpolate_distortion_ lf_lens_interpolate_distortion
#define lf_lens_interpolate_tca_ lf_lens_interpolate_tca
#define lf_lens_interpolate_vignetting_ lf_lens_interpolate_vignetting

#else

#define lf_lens_interpolate_distortion_(lens, focal, res) \
    lf_lens_interpolate_distortion(lens, lens->CropFactor, focal, res)
#define lf_lens_interpolate_tca_(lens, focal, res) \
    lf_lens_interpolate_tca(lens, lens->CropFactor, focal, res)
#define lf_lens_interpolate_vignetting_(lens, focal, aperture, distance, res) \
    lf_lens_interpolate_vignetting(lens, lens->CropFactor, focal, aperture, distance, res)

#endif