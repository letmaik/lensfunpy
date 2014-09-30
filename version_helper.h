#include "lensfun.h"

/*
The version constants were introduced in 0.2.6. 
As Ubuntu 12.04 has 0.2.5 and we want to support it we have to define
the version ourselves. We use 0.2.5 as a fixed version, even though
the actual version may be lower than that.
*/
#ifndef LF_VERSION_MAJOR
#define LF_VERSION_MAJOR	0
#define LF_VERSION_MINOR	2
#define LF_VERSION_MICRO	5
#define LF_VERSION_BUGFIX	0
#endif