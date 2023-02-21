/*
    Based on CRT shader by Hyllian
    Modified by Jezze

    Copyright (C) 2011-2023 Hyllian - sergiogdb@gmail.com
    Copyright (C) 2023 Jezze - jezze@gmx.net
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

#include "common/utilities.h"
#include "common/colorspace-srgb.h"

float get_subpixel_size(float screen_multiple)
{
    float pixel_size = global.SourceSize.x < global.SourceSize.y 
        ? global.FinalViewportSize.x / global.SourceSize.x
        : global.FinalViewportSize.y / global.SourceSize.y;

    float subpixel_count = PARAM_MASK_TYPE == 3
        // shadow-mask
        ? 3.0
        // aperture-grille, slot-mask
        : 4.0;

    // auto
    float subpixel_size = pixel_size / subpixel_count * screen_multiple;
    // manual correction
    subpixel_size += PARAM_MASK_SIZE;
    // limit
    subpixel_size = floor(max(1.0, subpixel_size));

    return subpixel_size;
}

float get_subpixel_smoothness(float subpixel_size)
{
    return
        // aperture-grille for size > 1
        PARAM_MASK_TYPE == 1 ? clamp((subpixel_size - 1.0) * 0.5, 0.0, 1.0) :
        // slot-mask for size > 1
        PARAM_MASK_TYPE == 2 ? clamp((subpixel_size - 1.0) * 0.5, 0.0, 1.0) :
        // shadow-mask for size > 2
        PARAM_MASK_TYPE == 3 ? clamp((subpixel_size - 2.0) * 0.25, 0.0, 1.0) : 0.0;
}

float get_brightness_compensation(float subpixel_smoothness)
{
    float brightness_compensation = 0.0;

    if (PARAM_COLOR_COMPENSATION > 0.0)
    {
        // scanlines compensation
        float scanlines_compensation =
            normalized_sigmoid(PARAM_SCANLINES_STRENGTH, 0.25)
            * mix(
                // smarp shape
                0.25,
                // smooth shape
                0.625,
                PARAM_BEAM_SHAPE);

        brightness_compensation += scanlines_compensation;

        if (PARAM_MASK_TYPE > 0.0)
        {
            float mask_type_offset =
                // aperture-grille
                PARAM_MASK_TYPE == 1 ? 0.0 :
                // slot-mask
                PARAM_MASK_TYPE == 2 ? 0.2 :
                // shadow-mask
                PARAM_MASK_TYPE == 3 ? 0.4 : 0.0;

            float mask_color_count_offset =
                // white, black
                PARAM_MASK_COLOR_COUNT == 0 ? -0.4 :
                // yellow, blue
                PARAM_MASK_COLOR_COUNT == 1 ? -0.3 :
                // green, magenta
                PARAM_MASK_COLOR_COUNT == 2 ? -0.2 :
                // red, green, blue
                PARAM_MASK_COLOR_COUNT == 3 ? 0.0 :
                // red, green, blue, black
                PARAM_MASK_COLOR_COUNT == 4 ? 0.2 : 0.0;

            float mask_smoothness_offset = PARAM_MASK_TYPE == 3.0
                // shadow-mask
                ? subpixel_smoothness * 0.5
                // aperture-grille, slot-mask
                : subpixel_smoothness * subpixel_smoothness * 0.5;

            // mask compensation
            float mask_compensation =
                PARAM_MASK_INTENSITY > 0.0
                    // positive mask intensity
                    ? normalized_sigmoid(-PARAM_MASK_INTENSITY, 0.125)
                        * (1.0 - mask_type_offset - mask_color_count_offset - mask_smoothness_offset)
                        * 0.5
                    // negative mask intensity
                    : normalized_sigmoid(-PARAM_MASK_INTENSITY, 0.625)
                        * (1.0 + mask_type_offset + mask_color_count_offset + mask_smoothness_offset)
                        * 1.0;

            // scanlines/mask balance
            mask_compensation += PARAM_MASK_INTENSITY > 0.0
                // positive mask intensity
                ? 0.0
                // negative mask intensity
                : scanlines_compensation * mask_compensation * 2.0;

            brightness_compensation += mask_compensation;
        }
    }

    return brightness_compensation;
}

// Horizontal cubic filter
// Some known filters use these values:
//   B = 0.0, C = 0.0       - Hermite cubic filter
//   B = 1.0, C = 0.0       - Cubic B-Spline filter
//   B = 0.0, C = 0.5       - Catmull-Rom Spline filter
//   B = C = 1.0/3.0        - Mitchell-Netravali cubic filter
//   B = 0.3782, C = 0.3109 - Robidoux filter
//   B = 0.2620, C = 0.3690 - Robidoux Sharp filter
// For more info, see: http://www.imagemagick.org/Usage/img_diagrams/cubic_survey.gif
mat4x4 get_beam_filter()
{
    // Hermite filter
    float b = 0.0;
    float c = 0.0;

    if (PARAM_BEAM_FILTER == 2)
    {
        // Hyllian filter
        b = 0.36;
        c = 0.28;
    }
    else if (PARAM_BEAM_FILTER == 3)
    {
        // Catmull-Rom filter
        b = 0.0;
        c = 0.5;
    }

    return mat4x4(
                    (-b - 6.0 * c) / 6.0,          (3.0 * b + 12.0 * c) / 6.0, (-3.0 * b - 6.0 * c) / 6.0,              b  / 6.0,
        (12.0 - 9.0 * b - 6.0 * c) / 6.0, (-18.0 + 12.0 * b +  6.0 * c) / 6.0,                        0.0, (6.0 - 2.0 * b) / 6.0,
       -(12.0 - 9.0 * b - 6.0 * c) / 6.0, ( 18.0 - 15.0 * b - 12.0 * c) / 6.0,  (3.0 * b + 6.0 * c) / 6.0,              b  / 6.0,
                     (b + 6.0 * c) / 6.0,                           -c,                  0.0,                   0.0
    );
}

vec4 get_beam_profile(float maximum_color)
{
    float beam_min_width = 1.0;
    float beam_max_width = 1.0;
    float beam_slope = 2.0;

    float param_beam_shape_inverted = 1.0 - PARAM_BEAM_SHAPE; 

    // increase beam slope
    beam_slope +=
        2.0
        // increase for sharp shape, no increase for smooth shape
        * (param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH)
        // double increase for sharp shape
        * (param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH + 1.0);

    // reduce min./max. width for sharp shape
    beam_min_width -= param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH / 2.0;
    beam_max_width -= param_beam_shape_inverted * PARAM_SCANLINES_STRENGTH / 2.0;

    // reduce min. width
    beam_min_width /=
        1.0
        // for beam width < 1
        + min(1.0, PARAM_BEAM_WIDTH)
        // when strength in range [0.5, 1.0]
        * min(1.0, PARAM_SCANLINES_STRENGTH * 2.0)
        // half
        / 2.0;

    // increase max. width
    beam_max_width *=
        1.0
        // for beam width > 1
        + max(0.0, PARAM_BEAM_WIDTH - 1.0)
        // when strength in range [0.5, 1.0]
        * min(1.0, PARAM_SCANLINES_STRENGTH * 2.0)
        // the closer max. color is to 1
        * mix(0.0, 1.0, 1.0 / (maximum_color * maximum_color))
        // half
        / 2.0;

    // change stenghth slope to level out at higher values
    float scanlines_strength = normalized_sigmoid(PARAM_SCANLINES_STRENGTH, 0.5);

    // change strength range to [0.25, 1.5]
    scanlines_strength *= 1.25;
    scanlines_strength += 0.25;

    return vec4(beam_min_width, beam_max_width, beam_slope, scanlines_strength);
}
