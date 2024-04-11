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

void print_m256i_epi16(__m256i vec) {
    union {
        __m256i v;
        int16_t elems[16];
    } u;

    u.v = vec;

    printf("Elements of __m256i vector:\n");
    for(int i = 0; i < 16; i++) {
        printf("%d ", u.elems[i]);
    }
    printf("\n");
}

void print_m256i_epi32(__m256i vec) {
    union {
        __m256i v;
        int32_t elems[8];
    } u;

    u.v = vec;

    printf("Elements of __m256i vector:\n");
    for(int i = 0; i < 8; i++) {
        printf("%d ", u.elems[i]);
    }
    printf("\n");
}

__m256i montgomery_reduce_simd(__m256i a)
{
  __m256i t;

  t = _mm256_mullo_epi32(a, qinv32vec);
  t = _mm256_slli_epi32(t, 16);   // to mimic cast from 16-bit to 32-bit, ensure sign bit is preserved
  t = _mm256_srai_epi32(t, 16);
  t = _mm256_mullo_epi32(t, kyberq32vec);
  t = _mm256_sub_epi32(a, t);
  t = _mm256_srai_epi32(t, 16); // Shift right arithmetic by 16 bits*/

  return t;
}

static __m256i fqmul_simd(__m256i a, __m256i b) {
  __m256i inp = _mm256_mullo_epi32(a, b);
  __m256i out = montgomery_reduce_simd(inp);
  return out;
}

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

int16_t* ntt_simd(int16_t arr_simd[256]) {
  unsigned int len, start, j, k;
  int16_t zeta;
  __m256i t, tl, tu, rjlennew, rjnew;

  // broadcast constants into 32-bit lanes
  qinv32vec = _mm256_set1_epi32(QINV);
  kyberq32vec = _mm256_set1_epi32(KYBER_Q);

  // create a mask with the low 16 bits of each 32-bit lane set
  masklow16 = _mm256_set1_epi32(0xFFFF);
  mask_low_4_els = _mm256_set_epi64x(0, 0, 0, -1);
  mask_upp_8_els = _mm256_set_epi64x(-1, -1, 0, 0);
  mask_low_2_els = _mm256_set_epi32(0, 0, 0, 0, 0, 0, 0, -1);
  mask_upp_12_els = _mm256_set_epi32(-1, -1, -1, -1, -1, -1, 0, 0);
  rjlennew = _mm256_set_epi64x(0, 0, 0, 0);

  k = 1;
  for(len = 128; len >= 16; len >>= 1) {
    for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=16) {
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);
        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);
        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        _mm256_storeu_si256((__m256i*)&arr_simd[j + len], rjlennew);
        rjnew = _mm256_add_epi16(rj16vec, t);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], rjnew);
      }
    }
  }
  /*len = 128;
  //for(len = 128; len >= 128; len >>= 1) {
    for(start = 0; start < 1; start = j + len) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < 16; j+=16) {
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        _mm256_storeu_si256((__m256i*)&arr_simd[j + len], rjlennew);
        rjnew = _mm256_add_epi16(rj16vec, t);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], rjnew);
      }
    }
  //}*/
  /*len = 8;
  for(j = 0; j < 256; j += 16) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rj16vecnext = _mm256_loadu_si256((__m256i*) & arr_simd[j + 16]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);

        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        rjlennew = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rjlennew), 1);
        rjnew = _mm256_add_epi16(rj16vec, t);
        rjnew = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rjnew), 0);
        __m256i res = _mm256_xor_epi32(rjnew, rjlennew);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
  }*/
  /*int16_t tx;
  len = 128;
  for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k++];
      for(j = 0; j < 128; j++) {
        tx = fqmul(zeta, arr_simd[j + len]);
        arr_simd[j + len] = arr_simd[j] - tx;
        arr_simd[j] = arr_simd[j] + tx;
      }
    }
  /*len = 4;
  for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k++];
      for(j = start; j < start + len; j++) {
        tx = fqmul(zeta, arr_simd[j + len]);
        arr_simd[j + len] = arr_simd[j] - tx;
        arr_simd[j] = arr_simd[j] + tx;
      }
    }
  len = 2;
  for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k++];
      for(j = start; j < start + len; j++) {
        tx = fqmul(zeta, arr_simd[j + len]);
        arr_simd[j + len] = arr_simd[j] - tx;
        arr_simd[j] = arr_simd[j] + tx;
      }
    }
  /*for(start = 0; start < 256; start += 2*len) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=8) {
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        rjlennew = _mm256_and_si256(rjlennew, mask_low_4_els);
        uint64_t scalar = _mm256_extract_epi64(rjlennew, 0);  // move the results into the 4-7th element positions
        rjlennew = _mm256_setzero_si256();
        rjlennew = _mm256_insert_epi64(rjlennew, scalar, 1);
        rjnew = _mm256_add_epi16(rj16vec, t);
        rjnew = _mm256_and_si256(rjnew, mask_low_4_els);
        __m256i res = _mm256_xor_epi32(rjnew, rjlennew);
        __m256i res_offset = _mm256_and_si256(rj16vec, mask_upp_8_els);
        res = _mm256_xor_epi32(res, res_offset);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
      }
  }*/

  /*len = 2;
  for(start = 0; start < 256; start += 2*len) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=4) {
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        uint64_t scalar = _mm256_extract_epi32(rjlennew, 0);  // move the results into the 4-7th element positions
        rjlennew = _mm256_setzero_si256();
        rjlennew = _mm256_insert_epi32(rjlennew, scalar, 1);
        rjnew = _mm256_add_epi16(rj16vec, t);
        rjnew = _mm256_and_si256(rjnew, mask_low_2_els);
        __m256i res = _mm256_xor_epi32(rjnew, rjlennew);
        __m256i res_offset = _mm256_and_si256(rj16vec, mask_upp_12_els);
        res = _mm256_xor_epi32(res, res_offset);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
      }
  }*/
  return arr_simd;
}

/*int16_t* ntt_simd(int16_t arr_simd[256]) {
  unsigned int len, start, j, k;
  int16_t zeta;
  __m256i t, tl, tu, rjlennew, rjnew;

  // broadcast constants into 32-bit lanes
  qinv32vec = _mm256_set1_epi32(QINV);
  kyberq32vec = _mm256_set1_epi32(KYBER_Q);

  // create a mask with the low 16 bits of each 32-bit lane set
  masklow16 = _mm256_set1_epi32(0xFFFF);
  mask_low_4_els = _mm256_set_epi64x(0, 0, 0, -1);
  mask_upp_8_els = _mm256_set_epi64x(-1, -1, 0, 0);
  mask_low_2_els = _mm256_set_epi32(0, 0, 0, 0, 0, 0, 0, -1);
  mask_upp_12_els = _mm256_set_epi32(-1, -1, -1, -1, -1, -1, 0, 0);
  rjlennew = _mm256_set_epi64x(0, 0, 0, 0);

  k = 1;
  len = 8;
  for(j = 0; j < 256; j += 16) {
      zeta = zetas[k++];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
        __m256i rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        __m256i rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        __m256i rj16vecnext = _mm256_loadu_si256((__m256i*) & arr_simd[j + 16]);
        __m256i rjlenlow16vec = _mm256_slli_epi32(rjlen16vec, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        __m256i rjlenupp16vec = _mm256_srai_epi32(rjlen16vec, 16);

        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        t = _mm256_xor_epi32(tl, tu);
        
        rjlennew = _mm256_sub_epi16(rj16vec, t);
        rjlennew = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rjlennew), 1);
        rjnew = _mm256_add_epi16(rj16vec, t);
        rjnew = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rjnew), 0);
        __m256i res = _mm256_xor_epi32(rjnew, rjlennew);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
  }
  
  return arr_simd;
}*/
