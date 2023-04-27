#ifndef SUCCESS_OR_DIE_HH
#define SUCCESS_OR_DIE_HH

#include <GASPI.h>
#include <cstdlib>
#include <iostream>
#include <array>

// #define xstr(s) str(s)
// #define str(s) #s

static constexpr const std::array GASPI_ERROR_MSG{
    "GASPI_SUCCESS",
    "GASPI_TIMEOUT",
    "GASPI_ERR_EMFILE",
    "GASPI_ERR_ENV",
    "GASPI_ERR_SN_PORT",
    "GASPI_ERR_CONFIG",
    "GASPI_ERR_NOINIT",
    "GASPI_ERR_INITED",
    "GASPI_ERR_NULLPTR",
    "GASPI_ERR_INV_SEGSIZE",
    "GASPI_ERR_INV_SEG",
    "GASPI_ERR_INV_GROUP",
    "GASPI_ERR_INV_RANK",
    "GASPI_ERR_INV_QUEUE",
    "GASPI_ERR_INV_LOC_OFF",
    "GASPI_ERR_INV_REM_OFF",
    "GASPI_ERR_INV_COMMSIZE",
    "GASPI_ERR_INV_NOTIF_VAL",
    "GASPI_ERR_INV_NOTIF_ID",
    "GASPI_ERR_INV_NUM",
    "GASPI_ERR_INV_SIZE",
    "GASPI_ERR_MANY_SEG",
    "GASPI_ERR_MANY_GRP",
    "GASPI_QUEUE_FULL",
    "GASPI_ERR_UNALIGN_OFF",
    "GASPI_ERR_ACTIVE_COLL",
    "GASPI_ERR_DEVICE",
    "GASPI_ERR_SN",
    "GASPI_ERR_MEMALLOC"};

#define SUCCESS_OR_DIE(f...)                                                                                                \
  {                                                                                                                         \
    const gaspi_return_t gaspi_return = f;                                                                                  \
    const char *err_msg = gaspi_return == GASPI_ERROR ? "GASPI_ERROR" : GASPI_ERROR_MSG[static_cast<size_t>(gaspi_return)]; \
    if (gaspi_return not_eq GASPI_SUCCESS)                                                                                  \
    {                                                                                                                       \
      std::cerr << "Error: '" << #f                                                                                         \
                << "' [" __FILE__ << ":" << __LINE__ << "] \t"                                                              \
                << err_msg << std::endl;                                                                                    \
      exit(EXIT_FAILURE);                                                                                                   \
    }                                                                                                                       \
  }

#endif
