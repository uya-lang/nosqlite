/* 主机测试用 CMSIS-NN arm_convolve_HWC_q7_basic 桩：1×1、stride=1、padding=0、方形特征图。
 * 真机链接 CMSIS-NN 时替换为本库实现即可。 */
#include <stdint.h>

#define ARM_MATH_SUCCESS 0
#define ARM_MATH_ARGUMENT_ERROR (-1)

int32_t arm_convolve_HWC_q7_basic(
    const int8_t *Im_in,
    uint16_t dim_im_in,
    uint16_t ch_im_in,
    const int8_t *wt,
    uint16_t ch_im_out,
    uint16_t dim_kernel,
    uint16_t padding,
    uint16_t stride,
    const int8_t *bias,
    uint16_t bias_shift,
    uint16_t out_shift,
    int8_t *Im_out,
    uint16_t dim_im_out,
    int16_t *bufferA,
    int8_t *bufferB)
{
    (void)bufferA;
    (void)bufferB;
    if (dim_kernel != 1U || padding != 0U || stride != 1U) {
        return ARM_MATH_ARGUMENT_ERROR;
    }
    if (dim_im_in != dim_im_out) {
        return ARM_MATH_ARGUMENT_ERROR;
    }
    const uint32_t dim = (uint32_t)dim_im_in;
    const uint32_t chi = (uint32_t)ch_im_in;
    const uint32_t cho = (uint32_t)ch_im_out;
    for (uint32_t y = 0; y < dim; y++) {
        for (uint32_t x = 0; x < dim; x++) {
            for (uint32_t co = 0; co < cho; co++) {
                int32_t acc = ((int32_t)bias[co]) << bias_shift;
                for (uint32_t ci = 0; ci < chi; ci++) {
                    uint32_t in_idx = (y * dim + x) * chi + ci;
                    uint32_t w_idx = co * chi + ci;
                    acc += (int32_t)Im_in[in_idx] * (int32_t)wt[w_idx];
                }
                acc >>= out_shift;
                if (acc > 127) {
                    acc = 127;
                }
                if (acc < -128) {
                    acc = -128;
                }
                uint32_t oidx = (y * dim + x) * cho + co;
                Im_out[oidx] = (int8_t)acc;
            }
        }
    }
    return ARM_MATH_SUCCESS;
}
