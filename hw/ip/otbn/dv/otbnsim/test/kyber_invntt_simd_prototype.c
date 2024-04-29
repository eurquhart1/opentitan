#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <immintrin.h> // Include for AVX/AVX2 intrinsics
#include <stdbool.h>
#include <inttypes.h> // For PRIx16

#define KYBER_Q 3329
#define QINV 62209 // q^-1 mod 2^16 (32-bit representation)
const int16_t v = ((1 << 26) + KYBER_Q / 2) / KYBER_Q;

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
  return montgomery_reduce_simd(inp);
}

__m256i simd_multiply_add_shift(__m256i v, __m256i a) {
    // Split the input vector into two parts to handle each 128-bit lane as 32-bit integers
    __m128i a_lo = _mm256_extractf128_si256(a, 0);
    __m128i a_hi = _mm256_extractf128_si256(a, 1);

    // Extend 16-bit integers to 32-bit
    __m256i a_lo_32 = _mm256_cvtepi16_epi32(a_lo);
    __m256i a_hi_32 = _mm256_cvtepi16_epi32(a_hi);

    // extend v
    __m128i v_lo = _mm256_extractf128_si256(v, 0);
    __m256i v_lo_32 = _mm256_cvtepi16_epi32(v_lo);
    
    // Perform the multiplication for low and high parts
    __m256i mul_lo = _mm256_mullo_epi32(a_lo_32, v_lo_32);
    __m256i mul_hi = _mm256_mullo_epi32(a_hi_32, v_lo_32);

    // Add (1 << 25) and shift right
    __m256i bias = _mm256_set1_epi32(1 << 25);
    __m256i sum_lo = _mm256_add_epi32(mul_lo, bias);
    __m256i sum_hi = _mm256_add_epi32(mul_hi, bias);

    sum_lo = _mm256_srai_epi32(sum_lo, 26);
    sum_hi = _mm256_srai_epi32(sum_hi, 26);

    // Pack results back to 16-bit
    __m128i sum_lo_16 = _mm256_cvtepi32_epi16(sum_lo);
    __m128i sum_hi_16 = _mm256_cvtepi32_epi16(sum_hi);

    return _mm256_set_m128i(sum_hi_16, sum_lo_16);
}

__m256i barrett_reduce_simd(__m256i a) {
  // broadcast constants into 32-bit lanes
    __m256i kyberq_vec = _mm256_set1_epi16(KYBER_Q);
    __m256i v_vec = _mm256_set1_epi16(v);
    __m256i t = simd_multiply_add_shift(v_vec, a);
    __m256i t_mul_q = _mm256_mullo_epi16(t, kyberq_vec);
    __m256i result = _mm256_sub_epi16(a, t_mul_q);
    return result;
}

int16_t* invntt_simd(int16_t arr_simd[256]) {
  unsigned int start, len, j, k;
  int16_t t, zeta;
  const int16_t f = 1441; // mont^2/128
  __m256i fvec, tl, tu, rj16vec, rj16vec_new, rjlow16vec, zeta32vec, rjlen16vec, barrett_arg, rjlen16vec_tmp, rjlenlow16vec, rjlenupp16vec, rjlen16vec_new;
  qinv32vec = _mm256_set1_epi32(QINV);
  kyberq32vec = _mm256_set1_epi32(KYBER_Q);
  fvec = _mm256_set1_epi32(f);
  masklow16 = _mm256_set1_epi32(0xFFFF);
  mask_low_4_els = _mm256_set_epi64x(0, 0, 0, -1);
  mask_upp_8_els = _mm256_set_epi64x(-1, -1, 0, 0);
  mask_low_2_els = _mm256_set_epi32(0, 0, 0, 0, 0, 0, 0, -1);
  mask_upp_12_els = _mm256_set_epi32(-1, -1, -1, -1, -1, -1, 0, 0);

  k = 127;
  /*len = 2;
  for(start = 0; start < 256; start += 2*len) {
      zeta = zetas[k--];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=4) {
        rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        barrett_arg = _mm256_add_epi16(rj16vec, rjlen16vec);
        rj16vec_new = barrett_reduce_simd(barrett_arg);
        rjlen16vec_tmp = _mm256_sub_epi16(rjlen16vec, rj16vec);
        
        rjlenlow16vec = _mm256_slli_epi32(rjlen16vec_tmp, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        rjlenupp16vec = _mm256_srai_epi32(rjlen16vec_tmp, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        rjlen16vec_new = _mm256_xor_epi32(tl, tu);
        
        uint64_t scalar = _mm256_extract_epi32(rjlen16vec_new, 0);  // move the results into the 4-7th element positions
        rjlen16vec_new = _mm256_setzero_si256();
        rjlen16vec_new = _mm256_insert_epi32(rjlen16vec_new, scalar, 1);
        rj16vec_new = _mm256_and_si256(rj16vec_new, mask_low_2_els);
        __m256i res = _mm256_xor_epi32(rj16vec_new, rjlen16vec_new);
        __m256i res_offset = _mm256_and_si256(rj16vec, mask_upp_12_els);
        res = _mm256_xor_epi32(res, res_offset);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
      }
  }
  len = 4;
  for(start = 0; start < 256; start += 2*len) {
      zeta = zetas[k--];
      __m256i zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=8) {
        rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        barrett_arg = _mm256_add_epi16(rj16vec, rjlen16vec);
        rj16vec_new = barrett_reduce_simd(barrett_arg);
        rjlen16vec_tmp = _mm256_sub_epi16(rjlen16vec, rj16vec);
        
        rjlenlow16vec = _mm256_slli_epi32(rjlen16vec_tmp, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        rjlenupp16vec = _mm256_srai_epi32(rjlen16vec_tmp, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        rjlen16vec_new = _mm256_xor_epi32(tl, tu);
        
        rjlen16vec_new = _mm256_and_si256(rjlen16vec_new, mask_low_4_els);
        uint64_t scalar = _mm256_extract_epi64(rjlen16vec_new, 0);  // move the results into the 4-7th element positions
        rjlen16vec_new = _mm256_setzero_si256();
        rjlen16vec_new = _mm256_insert_epi64(rjlen16vec_new, scalar, 1);
        rj16vec_new = _mm256_and_si256(rj16vec_new, mask_low_4_els);
        __m256i res = _mm256_xor_epi32(rj16vec_new, rjlen16vec_new);
        __m256i res_offset = _mm256_and_si256(rj16vec, mask_upp_8_els);
        res = _mm256_xor_epi32(res, res_offset);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
      }
  }*/

  len = 8;
  j=0;
  for(start = 0; start < 256; start += 2*len) {
      zeta = zetas[k--];
      zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=16) {
        rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        barrett_arg = _mm256_add_epi16(rj16vec, rjlen16vec);
        rj16vec_new = barrett_reduce_simd(barrett_arg);
        rjlen16vec_tmp = _mm256_sub_epi16(rjlen16vec, rj16vec);

        rjlenlow16vec = _mm256_slli_epi32(rjlen16vec_tmp, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        rjlenupp16vec = _mm256_srai_epi32(rjlen16vec_tmp, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        rjlen16vec_new = _mm256_xor_epi32(tl, tu);
        
        rjlen16vec_new = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rjlen16vec_new), 1);
        rj16vec_new = _mm256_inserti128_si256(_mm256_setzero_si256(), _mm256_castsi256_si128(rj16vec_new), 0);
        __m256i res = _mm256_xor_epi32(rj16vec_new, rjlen16vec_new);
        _mm256_storeu_si256((__m256i*)&arr_simd[j], res);
      }
  }
  /*for(len = 16; len <= 128; len <<= 1) {
    for(start = 0; start < 256; start = j + len) {
      zeta = zetas[k--];
      zeta32vec = _mm256_set1_epi32(zeta);
      for(j = start; j < start + len; j+=16) {
        rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
        rjlen16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j + len]);
        barrett_arg = _mm256_add_epi16(rj16vec, rjlen16vec);
        rj16vec_new = barrett_reduce_simd(barrett_arg);
        rjlen16vec_tmp = _mm256_sub_epi16(rjlen16vec, rj16vec);

        rjlenlow16vec = _mm256_slli_epi32(rjlen16vec_tmp, 16);
        rjlenlow16vec = _mm256_srai_epi32(rjlenlow16vec, 16);
        rjlenupp16vec = _mm256_srai_epi32(rjlen16vec_tmp, 16);
        
        tl = fqmul_simd(zeta32vec, rjlenlow16vec);
        tu = fqmul_simd(zeta32vec, rjlenupp16vec);

        tl = _mm256_and_si256(tl, masklow16);
        tu = _mm256_and_si256(tu, masklow16);

        tu = _mm256_slli_epi32(tu, 16);
        rjlen16vec_new = _mm256_xor_epi32(tl, tu);

        _mm256_storeu_si256((__m256i*)&arr_simd[j], rj16vec_new);
        _mm256_storeu_si256((__m256i*)&arr_simd[j + len], rjlen16vec_new);
      }
    }
  }

  /*for (j=0; j<256; j+=16) {
    rj16vec = _mm256_loadu_si256((__m256i*) & arr_simd[j]);
    
    rjlow16vec = _mm256_slli_epi32(rj16vec, 16);
    rjlow16vec = _mm256_srai_epi32(rjlow16vec, 16);
    __m256i rjupp16vec = _mm256_srai_epi32(rj16vec, 16);
        
    tl = fqmul_simd(rjlow16vec, fvec);
    tu = fqmul_simd(rjupp16vec, fvec);

    tl = _mm256_and_si256(tl, masklow16);
    tu = _mm256_and_si256(tu, masklow16);

    tu = _mm256_slli_epi32(tu, 16);
    __m256i rj16vec_new = _mm256_xor_epi32(tl, tu);

    _mm256_storeu_si256((__m256i*)&arr_simd[j], rj16vec_new);
  }*/
  return arr_simd;
}
