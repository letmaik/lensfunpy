from __future__ import absolute_import

import os

if os.name == 'nt':
    from ctypes import cdll
    dllpath = os.path.join(os.path.dirname(__file__), 'lensfun.dll')
    cdll.LoadLibrary(dllpath)

import lensfunpy._lensfun
globals().update(lensfunpy._lensfun)