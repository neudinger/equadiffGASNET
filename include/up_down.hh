#ifndef UP_DOWN_HH
#define UP_DOWN_HH

#define DOWN(iProc,nProc) ((iProc + nProc + 1) % nProc)
#define UP(iProc,nProc) ((iProc + nProc - 1) % nProc)

#endif