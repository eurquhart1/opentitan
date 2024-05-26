#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <immintrin.h> // Include for AVX/AVX2 intrinsics
#include <stdbool.h>
#include <inttypes.h> // For PRIx16

#define KYBER_Q 3329
#define QINV 62209 // q^-1 mod 2^16 (32-bit representationi)

__m256i qinv32vec;
__m256i kyberq32vec;
__m256i masklow16, maskupp16, mask_low_4_els, mask_upp_8_els, mask_low_2_els, mask_upp_12_els;

/* 
 * Instructions for running:
 * ~/opentitan/hw/ip/otbn/dv/otbnsim/test$ gcc -march=native kyber_ntt_simd.c -o kyber_ntt_simd
 * ~/opentitan/hw/ip/otbn/dv/otbnsim/test$ ./kyber_ntt_simd
 */

const int16_t zetas[128] = {
  -1044,  -758,  -359, -1517,  1493,  1422,   287,   202,
   -171,   622,  1577,   182,   962, -1202, -1474,  1468,
    573, -1325,   264,   383,  -829,  1458, -1602,  -130,
   -681,  1017,   732,   608, -1542,   411,  -205, -1571,
   1223,   652,  -552,  1015, -1293,  1491,  -282, -1544,
    516,    -8,  -320,  -666, -1618, -1162,   126,  1469,
   -853,   -90,  -271,   830,   107, -1421,  -247,  -951,
   -398,   961, -1508,  -725,   448, -1065,   677, -1275,
  -1103,   430,   555,   843, -1251,   871,  1550,   105,
    422,   587,   177,  -235,  -291,  -460,  1574,  1653,
   -246,   778,  1159,  -147,  -777,  1483,  -602,  1119,
  -1590,   644,  -872,   349,   418,   329,  -156,   -75,
    817,  1097,   603,   610,  1322, -1285, -1465,   384,
  -1215,  -136,  1218, -1335,  -874,   220, -1187, -1659,
  -1185, -1530, -1278,   794, -1510,  -854,  -870,   478,
   -108,  -308,   996,   991,   958, -1460,  1522,  1628
};

int16_t montgomery_reduce(int32_t a)
{
  int16_t t;

  t = (int16_t)a*QINV;
  t = (a - (int32_t)t*KYBER_Q) >> 16;
  return t;
}

static int16_t fqmul(int16_t a, int16_t b) {
  return montgomery_reduce((int32_t)a*b);
}

int16_t* ntt_simd(int16_t r[256]) {
  unsigned int len, start, j, k;
  int16_t t, zeta;

  k = 1;
  for(len = 128; len >= 2; len >>= 1) {
    for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k++];
      for(j = start; j < start + len; j++) {
        t = fqmul(zeta, r[j + len]);
        r[j + len] = r[j] - t;
        r[j] = r[j] + t;
      }
    }
  }
  return r;
}
