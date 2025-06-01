#version 450

/*
    Based on CRT shader by Hyllian
    Modified by Jezze
*/

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
    uint FrameCount;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float SCREEN_SCALE;
    float SCREEN_ORIENTATION;
    float COLOR_BRIGHTNESS;
    float COLOR_COMPENSATION;
    float COLOR_SATURATION;
    float COLOR_OVERFLOW;
    float COLOR_CONTRAST;
    float COLOR_PROFILE;
    float COLOR_TEMPERATUE;
    float SCANLINES_STRENGTH;
    float SCANLINES_OFFSET;
    float BEAM_WIDTH_MIN;
    float BEAM_WIDTH_MAX;
    float BEAM_SHAPE;
    float BEAM_FILTER;
    float SCANLINES_COLOR_BURN;
    float MASK_INTENSITY;
    float MASK_OPACITY;
    float MASK_SIZE;
    float MASK_TYPE;
    float MASK_COLOR_COUNT;
    float MASK_COLOR_BLEED;
    float HALATION_INTENSITY;
    float HALATION_DIFFUSION;
    float CRT_CURVATURE_AMOUNT;
    float CRT_VIGNETTE_AMOUNT;
    float CRT_NOISE_AMOUNT;
    float CRT_CORNER_RAIDUS;
    float CRT_CORNER_SMOOTHNESS;
} param;

#include "common/parameters.h"
#include "common/utilities.h"

#define INPUT(color) decode_gamma(color)
#define OUTPUT(color)                          \
    encode_gamma(                              \
        apply_temperature(                     \
            apply_saturation(                  \
                apply_brightness(              \
                    apply_contrast(            \
                        color,                 \
                        PARAM_COLOR_CONTRAST), \
                    PARAM_COLOR_BRIGHTNESS),   \
                PARAM_COLOR_SATURATION),       \
            PARAM_COLOR_TEMPERATUE))

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float ScreenOrientation;
layout(location = 2) out float ScreenMultiple;
layout(location = 3) out float SubpixelSize;
layout(location = 4) out float SubpixelSmoothness;
layout(location = 5) out float BrightnessCompensation;
layout(location = 6) out vec4 BeamProfile;
layout(location = 7) out mat4x4 BeamFilter;

#include "crt-hyllian-next-vs.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    ScreenOrientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    ScreenMultiple = get_multiple_stepwise(global.OriginalSize.xy, ScreenOrientation, -PARAM_SCREEN_SCALE);
    SubpixelSize = get_subpixel_size(ScreenMultiple);
    SubpixelSmoothness = get_subpixel_smoothness(SubpixelSize);
    BrightnessCompensation = get_brightness_compensation();
    BeamProfile = get_beam_profile();
    BeamFilter = get_beam_filter();
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float ScreenOrientation;
layout(location = 2) in float ScreenMultiple;
layout(location = 3) in float SubpixelSize;
layout(location = 4) in float SubpixelSmoothness;
layout(location = 5) in float BrightnessCompensation;
layout(location = 6) in vec4 BeamProfile;
layout(location = 7) in mat4x4 BeamFilter;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D LutPass;

// required by crt-hyllian-next-fs.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_BRIGHTNESS_COMPENSATION BrightnessCompensation
#define INPUT_SUBPIXEL_SIZE SubpixelSize
#define INPUT_SUBPIXEL_SMOOTHNESS SubpixelSmoothness
#define INPUT_BEAM_FILTER BeamFilter
#define INPUT_BEAM_PROFILE BeamProfile

#include "crt-hyllian-next-fs.h"

#define HalationSource Source
#define TextureSource LutPass

void main()
{
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);
    vec2 tex_coord_curved_sharpend = apply_sharp_bilinear_filtering(tex_coord_curved);

    vec3 raw_color = get_raw_color(TextureSource, tex_coord_curved_sharpend);
    vec3 scanlines_color = get_scanlines_color(TextureSource, tex_coord_curved);

    vec3 color = blend_colors(raw_color, scanlines_color);
    float color_luma = get_luminance(color);

    color = apply_mask(color, color_luma, tex_coord); // use un-curved coordinates to avoid Moire-artefacts
    color = apply_noise(color, tex_coord); // use un-curved coordinates to avoid Moire-artefacts
    color = apply_color_overflow(color);
    color = apply_halation(color, HalationSource, tex_coord_curved); // apply after mask & color overflow
    color = apply_brightness_compensation(color, color_luma);

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color), 1.0);
}
