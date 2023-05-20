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
#include "common/subpixel-color.h"

#define EPSILON 0.000001

#define INPUT(color) decode_gamma(color, PARAM_COLOR_CONTRAST)
#define INPUT_B(color) apply_brightness(INPUT(color), PARAM_COLOR_BRIGHTNESS)
#define INPUT_C(color) apply_brightness(INPUT(color), PARAM_COLOR_BRIGHTNESS + INPUT_BRIGHTNESS_COMPENSATION)
#define OUTPUT(color) encode_gamma(apply_saturation(color, PARAM_COLOR_SATURATION), PARAM_COLOR_CONTRAST)

vec2 vec2o(vec2 v)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? v.xy
        : v.yx;
}

vec2 vec2o(float x, float y)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(x, y)
        : vec2(y, x);
}

vec2 vec2ox(vec2 v, float f)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(v.x, f)
        : vec2(f, v.y);
}

vec2 vec2oy(vec2 v, float f)
{
    return INPUT_SCREEN_ORIENTATION == 0.0
        ? vec2(f, v.y)
        : vec2(v.x, f);
}

vec2 apply_cubic_lens_distortion(vec2 tex_coord)
{
    float amount = PARAM_CRT_CURVATURE_AMOUNT;

    // center coordinates
    tex_coord -= 0.5;

    // compute cubic distortion factor
    float c = tex_coord.x * tex_coord.x + tex_coord.y * tex_coord.y;
    float f = 1.0 + c * (amount * sqrt(c));

    // fit screen bounds
    f /= 1.0 + amount * 0.125;

    // apply cubic distortion factor
    tex_coord *= f;

    // un-center coordinates
    tex_coord += 0.5;

    return tex_coord;
}

float get_vignette_factor(vec2 tex_coord)
{
    float amount = PARAM_CRT_VIGNETTE_AMOUNT;

    // center coordinates
    tex_coord -= 0.5;

    // compute vignetting
    float vignette_radius = 1.0 - (amount * 0.25);
    float vignette_length = length(tex_coord);
    float vignette_blur = (amount * 0.125) + 0.375;
    float vignette = smoothstep(vignette_radius, vignette_radius - vignette_blur, vignette_length);

    return clamp(vignette, 0.0, 1.0);
}

float get_round_corner_factor(vec2 tex_coord)
{
    return smooth_round_box(
        tex_coord,
        global.OutputSize.xy,
        vec2(1.0),
        PARAM_CRT_CORNER_RAIDUS,
        PARAM_CRT_CORNER_SMOOTHNESS);
}

vec3 limit_color(vec3 color)
{
    // allow colors > 1
    float color_limit = mix(
        1.0,
        INPUT_MAXIMUM_COLOR,
        // for beam width > 1
        max(0.0, (PARAM_BEAM_WIDTH - 1.0))
        // when strength in range [0.5, 1.0]
        * min(1.0, PARAM_SCANLINES_STRENGTH * 2.0));

    // limit max. brightens
    return min(color, vec3(color_limit));
}

vec3 get_half_scanlines_factor(vec3 color, float position)
{
    float min_width = INPUT_BEAM_PROFILE.x;
    float max_width = INPUT_BEAM_PROFILE.y;
    float slope = INPUT_BEAM_PROFILE.z;
    float strength = INPUT_BEAM_PROFILE.w;

    // limit max. color
    color = limit_color(color);

    // limit color burn
    vec3 width_limit = mix(
        // max. color value for all channel
        vec3(max_color(color)),
        // no limit
        color,
        PARAM_SCANLINES_COLOR_BURN);

    // apply min./max. width
    vec3 width = mix(
        vec3(min_width),
        vec3(max_width),
        width_limit);

    // apply strength and slope
    vec3 factor = position / (width + EPSILON);
    factor = exp(-10.0 * strength * pow(factor, vec3(slope)));

    return factor;
}

vec3 get_half_beam_color(sampler2D source, vec2 tex_coord, vec2 delta_x, vec2 delta_y, vec4 beam_filter, float anti_ringing)
{
    // get spline bases
    vec3 x = INPUT_C(texture(source, tex_coord -       delta_x - delta_y).xyz);
    vec3 y = INPUT_C(texture(source, tex_coord                 - delta_y).xyz);
    vec3 z = INPUT_C(texture(source, tex_coord +       delta_x - delta_y).xyz);
    vec3 w = INPUT_C(texture(source, tex_coord + 2.0 * delta_x - delta_y).xyz);

    // get color from spline
    vec3 color = mat4x3(x, y, z, w) * beam_filter;

    // apply anti-ringing
    vec3 color_step = step(0.0, (x - y) * (z - w));
    vec3 color_clamp = clamp(color, min(y, z), max(y, z));
    color = mix(color, color_clamp, color_step * anti_ringing);

    return color;
}

vec3 get_color(sampler2D source, vec2 tex_coord)
{
    vec3 color = INPUT_C(texture(source, tex_coord).xyz);
    if (PARAM_SCANLINES_STRENGTH == 0.0)
    {
        return color;
    }

    float beam_sharpness = PARAM_BEAM_SHARPNESS + 1.0;

    vec2 tex_size = global.OriginalSize.xy;

    // apply scanlines sharpness
    tex_size *= vec2o(beam_sharpness, 1.0);

    // apply scanlines scale
    tex_size /= vec2o(1.0, INPUT_SCREEN_MULTIPLE);

    // apply half pixel offset (align to pixel corner)
    vec2 pc = tex_coord;
    pc *= tex_size;
    pc += vec2(0.5, 0.5);

    // apply half texel offset (scaling depended - required for NTSC phase-2 modulation)
    vec2 tc = floor(pc);
    tc += vec2o(-0.5, 0.5 / max(1.0, INPUT_SCREEN_MULTIPLE));

    if (INPUT_SCREEN_MULTIPLE > 1.0)
    {
        // apply factional offset if screen is down-scaled
        float scanlines_offset = PARAM_SCREEN_OFFSET / INPUT_SCREEN_MULTIPLE;
        tc += vec2o(0.0, scanlines_offset);
    }

    // pixel to texture coordinates
    tc /= tex_size;

    vec2 tex_delta = vec2(1.0) / tex_size;
    vec2 dx = vec2ox(tex_delta, 0.0);
    vec2 dy = vec2oy(tex_delta, 0.0);

    vec2 pcf = vec2o(fract(pc));

    // apply filtering
    vec4 beam_filter = vec4(pcf.x * pcf.x * pcf.x, pcf.x * pcf.x, pcf.x, 1.0)
        * INPUT_BEAM_FILTER;
    float anti_ringing =
        // for Catmull-Rom filter
        PARAM_BEAM_FILTER == 3 ? 1.0 :
        // for Hyllian filter
        PARAM_BEAM_FILTER == 2 ? 0.5 :
        // for Hermite filter
        PARAM_BEAM_FILTER == 1 ? 0.0 : 0.0;

    vec3 color0 = get_half_beam_color(source, tc, dx, dy, beam_filter, anti_ringing);
    vec3 color1 = get_half_beam_color(source, tc, dx, vec2(0.0), beam_filter, anti_ringing);

    // apply scanlines
    vec3 factor0 = get_half_scanlines_factor(color0, pcf.y);
    vec3 factor1 = get_half_scanlines_factor(color1, 1.0 - pcf.y);

    // merged raw color with scanlines for strength < 0.125
    float merge_limit = min(1.0, PARAM_SCANLINES_STRENGTH * 8);
    color = mix(
        color,
        color0 * factor0 + color1 * factor1,
        merge_limit);

    return color;
}

vec3 apply_mask(vec3 color, vec2 tex_coord)
{
    if (PARAM_MASK_TYPE == 0.0)
    {
        return color;
    }

    vec2 pix_coord = vec2o(tex_coord.xy * global.OutputSize.xy);

    vec3 subpixel_color = get_subpixel_color(
        pix_coord,
        int(INPUT_SUBPIXEL_SIZE),
        int(PARAM_MASK_TYPE),
        int(PARAM_MASK_COLOR_COUNT),
        1.0,
        INPUT_SUBPIXEL_SMOOTHNESS);

    // apply color bleed to neighbor sub-pixel
    subpixel_color += get_luminance(subpixel_color) * PARAM_MASK_COLOR_BLEED;

    return color * get_subpixel_weight(subpixel_color, PARAM_MASK_INTENSITY);
}

vec3 apply_color_overflow(vec3 color)
{
    // limit color overflow
    float overflow_limit = max(0.0, PARAM_COLOR_OVERFLOW - 1.0);
    vec3 color_limit = 
        // equal 1.0, if overflow is in range of [0.0, 1.0]
        vec3(1.0)
        // below 1.0, if overflow is > 2.0
        - vec3(overflow_limit) * LumaC;

    // apply color overflow for colors > limit squared
    vec3 color_overflow = max(vec3(0.0), color * color - color_limit * color_limit) * PARAM_COLOR_OVERFLOW;

    color.r += LumaR * LumaG * color_overflow.g;
    color.r += LumaR * LumaB * color_overflow.b;
    color.g += LumaG * LumaR * color_overflow.r;
    color.g += LumaG * LumaB * color_overflow.b;
    color.b += LumaB * LumaR * color_overflow.r;
    color.b += LumaB * LumaG * color_overflow.g;

    return color;
}

vec3 apply_halation(vec3 color, sampler2D source, vec2 tex_coord)
{
    vec3 halation = INPUT_B(texture(source, tex_coord).xyz);

    return mix(
        // either take the maximum of color and half halation
        max(color, halation / 2.0 * PARAM_HALATION_INTENSITY),
        // or add half the difference between color and halation
        color + abs(halation - color) / 2.0 * PARAM_HALATION_INTENSITY,
        // depending on the intensity
        PARAM_HALATION_INTENSITY);
}
