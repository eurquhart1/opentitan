// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_TEST_FRAMEWORK_UJSON_OTTF_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_TEST_FRAMEWORK_UJSON_OTTF_H_
#include <stdint.h>

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/ujson/ujson.h"
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initializes and returns a ujson context linked to the OTTF console.
 *
 * @return An initialized ujson_t context.
 */
ujson_t ujson_ottf_console(void);

/**
 * Add a CRC to the response.
 * Should not be used directly.
 * It is used by other macros such as `RESP_ERR`.
 *
 * @param uj_ctx_ A `ujson_t` representing the IO context.
 */
#define RESP_CRC(uj_ctx_)                         \
  ({                                              \
    uint32_t crc = ujson_crc32_finish(uj_ctx_);   \
    TRY(ujson_putbuf(uj_ctx_, " CRC:", 5));       \
    TRY(ujson_serialize_uint32_t(uj_ctx_, &crc)); \
    TRY(ujson_putbuf(uj_ctx_, "\n", 1));          \
    OK_STATUS();                                  \
  })

/**
 * Respond with an OK result and JSON encoded data.
 *
 * @param responder_ A ujson serializer function for `data_`.
 * @param uj_ctx_ A `ujson_t` representing the IO context.
 * @param data_ A pointer to the data to send.
 */
#define RESP_OK(responder_, uj_ctx_, data_)    \
  ({                                           \
    TRY(ujson_putbuf(uj_ctx_, "RESP_OK:", 8)); \
    ujson_crc32_reset(uj_ctx_);                \
    TRY(responder_(uj_ctx_, data_));           \
    RESP_CRC(uj_ctx_);                         \
    OK_STATUS();                               \
  })

/**
 * Respond with an OK result and JSON encoded OK_STATUS object.
 *
 * @param uj_ctx_ A `ujson_t` representing the IO context.
 * @param args... An optional integer to be reported in the status.
 */
#define RESP_OK_STATUS(uj_ctx_, ...)                  \
  ({                                                  \
    status_t sts = OK_STATUS(__VA_ARGS__);            \
    RESP_OK(ujson_serialize_status_t, uj_ctx_, &sts); \
    sts;                                              \
  })

/**
 * Respond with an ERR result and JSON encoded `status_t`.
 *
 * @param uj_ctx_ A `ujson_t` representing the IO context.
 * @param expr_ An expression of type `status_t`.
 */
#define RESP_ERR(uj_ctx_, expr_)                    \
  do {                                              \
    status_t sts = expr_;                           \
    if (!status_ok(sts)) {                          \
      TRY(ujson_putbuf(uj_ctx_, "RESP_ERR:", 9));   \
      TRY(ujson_serialize_status_t(uj_ctx_, &sts)); \
      RESP_CRC(uj_ctx_);                            \
    }                                               \
  } while (0)

#ifdef __cplusplus
}
#endif
#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_TEST_FRAMEWORK_UJSON_OTTF_H_
