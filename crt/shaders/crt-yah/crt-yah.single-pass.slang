#version 450

/*    
    Yah! - Yet Another Hyllian
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
    float CRT_CURVATURE_AMOUNT;
    float CRT_VIGNETTE_AMOUNT;
    float CRT_NOISE_AMOUNT;
    float CRT_CORNER_RAIDUS;
    float CRT_CORNER_SMOOTHNESS;
} param;

// Global parameters
#pragma parameter GLOBAL_MASTER "·  Global > ¹Master  (0-None .. 1-Full / 2-More)" 1.0 0.0 2.0 0.05

// Color parameters
#pragma parameter COLOR_PROFILE "·  Color > Profile¹  (-NTSC / +Trinitron)" 0.0 -1.0 1.0 0.25
#pragma parameter COLOR_TEMPERATUE "   Color > Temperature¹  (-D55 / D65 / +D75)" 0.0 -1.0 1.0 0.1
#pragma parameter COLOR_SATURATION "   Color > Saturation¹  (0-Low .. 2-High)" 1.0 0.0 2.0 0.05
#pragma parameter COLOR_CONTRAST "   Color > Contrast¹  (-Lower / +Higher)" 0.5 -1.0 1.0 0.05
#pragma parameter COLOR_BRIGHTNESS "   Color > Brightnes¹  (-Darken / +Lighten)" 0.25 -1.0 1.0 0.05
#pragma parameter COLOR_OVERFLOW "   Color > Brightnes Overflow¹  (0-None .. 1-Full / 2-More)" 0.5 0.0 2.0 0.25
#pragma parameter COLOR_COMPENSATION "   Color > ²Brightnes Compensation  (0-Off, 1-On)" 1.0 0.0 1.0 1.0

// Scanline/beam parameters
#pragma parameter SCANLINES_STRENGTH "·  Scanlines > Strength¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter SCANLINES_OFFSET "   Scanlines > Offset  (-with / +without Jitter)" -0.25 -2.0 2.0 0.25
#pragma parameter BEAM_WIDTH_MIN "   Scanlines > Beam Min. Width  (less-Shrink .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter BEAM_WIDTH_MAX "   Scanlines > Beam Max. Width  (1-Full .. more-Grow)" 1.25 1.0 2.0 0.05
#pragma parameter BEAM_SHAPE "   Scanlines > Beam Shape²  (0-Sharp .. 1-Smooth)" 1.0 0.0 1.0 0.25
#pragma parameter BEAM_FILTER "   Scanlines > Beam Filter  (-1-Blocky .. 1-Blurry)" 0.0 -1.0 1.0 0.05
#pragma parameter SCANLINES_COLOR_BURN "   Scanlines > Color Burn¹  (0-None .. 1-Full)" 1.0 0.0 1.0 0.25

// Mask parameters
#pragma parameter MASK_INTENSITY "·  Mask > Intensity¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_OPACITY "   Mask > Opacity²  (0-Opaque .. 1-Clear)" 0.0 0.0 1.0 0.05
#pragma parameter MASK_TYPE "   Mask > Type²  (0-Off, 1-Aperture, 2-Slot, 3-Shadow)" 1.0 0.0 3.0 1.0
#pragma parameter MASK_COLOR_COUNT "   Mask > Sub-Pixel²  (0-Mono, 1-MG, 2-MGK, 3-RGB, 4-RGBK)" 3.0 0.0 4.0 1.0
#pragma parameter MASK_COLOR_BLEED "   Mask > Color Bleed¹  (0-None .. 1-Full)" 0.5 0.0 1.0 0.25
#pragma parameter MASK_SIZE "   Mask > Size  (-Down / 0-Auto / +Up)" 0.0 -2.0 2.0 1.0

// CRT parameters
#pragma parameter CRT_CURVATURE_AMOUNT "·  CRT > Curvature¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_VIGNETTE_AMOUNT "   CRT > Vignette¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_NOISE_AMOUNT "   CRT > Noise¹  (0-None .. 1-Full)" 0.25 0.0 1.0 0.05
#pragma parameter CRT_CORNER_RAIDUS "   CRT > Corner Radius¹  (0-None .. 25%)" 0.0 0.0 0.25 0.01
#pragma parameter CRT_CORNER_SMOOTHNESS "   CRT > Corner Smoothness  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

// Screen parameters
#pragma parameter SCREEN_ORIENTATION "·  Screen > Orientation  (0-Auto, 1-Horizontal, 2-Vertical)" 0.0 0.0 2.0 1.0
#pragma parameter SCREEN_SCALE "   Screen > Scale  (-Down / 0-Auto / +Up)" 0.0 -2.0 2.0 1.0

#pragma parameter INFO1 "¹ Reduces marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO2 "² Compensates brightness changes of marked effects" 0.0 0.0 0.0 0.0

float mix_master(float value, float off_value, float min_value, float max_value)
{
    return param.GLOBAL_MASTER > 1.0
        ? mix(
            value,
            clamp(
                (value - off_value * 0.5) * param.GLOBAL_MASTER,
                min(value, min_value),
                max(value, max_value)),
            (param.GLOBAL_MASTER - 1.0) * 0.75)
        : mix(
            off_value,
            value,
            param.GLOBAL_MASTER);
}

// required by crt-yah.fs.h
#define PARAM_SCREEN_ORIENTATION param.SCREEN_ORIENTATION
#define PARAM_SCREEN_SCALE param.SCREEN_SCALE
#define PARAM_COLOR_FLOOR max(PARAM_SCANLINES_STRENGTH, PARAM_MASK_INTENSITY) * (1.0 / 256.0)
#define PARAM_COLOR_COMPENSATION param.COLOR_COMPENSATION
#define PARAM_COLOR_BRIGHTNESS mix_master(param.COLOR_BRIGHTNESS, 0.0, -1.0, 1.0)
#define PARAM_COLOR_OVERFLOW mix_master(param.COLOR_OVERFLOW, 0.0, 0.0, 2.0)
#define PARAM_COLOR_CONTRAST mix_master(param.COLOR_CONTRAST, 0.0, -1.0, 1.0)
#define PARAM_COLOR_SATURATION mix_master(param.COLOR_SATURATION, 1.0, 0.0, 2.0)
#define PARAM_COLOR_TEMPERATUE mix_master(param.COLOR_TEMPERATUE, 0.0, -1.0, 1.0)
#define PARAM_COLOR_PROFILE mix_master(param.COLOR_PROFILE, 0.0, -1.0, 1.0)
#define PARAM_MASK_INTENSITY mix_master(param.MASK_INTENSITY, 0.0, 0.0, 1.0)
#define PARAM_MASK_OPACITY param.MASK_OPACITY
#define PARAM_MASK_SIZE param.MASK_SIZE
#define PARAM_MASK_TYPE param.MASK_TYPE
#define PARAM_MASK_COLOR_COUNT param.MASK_COLOR_COUNT
#define PARAM_MASK_COLOR_BLEED mix_master(param.MASK_COLOR_BLEED, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_STRENGTH mix_master(param.SCANLINES_STRENGTH, 0.0, 0.0, 1.0)
#define PARAM_SCANLINES_OFFSET mix_master(param.SCANLINES_OFFSET, 0.0, -2.0, 2.0)
#define PARAM_SCANLINES_COLOR_BURN mix_master(param.SCANLINES_COLOR_BURN, 0.0, 0.0, 1.0)
#define PARAM_BEAM_WIDTH_MIN param.BEAM_WIDTH_MIN
#define PARAM_BEAM_WIDTH_MAX param.BEAM_WIDTH_MAX
#define PARAM_BEAM_SHAPE param.BEAM_SHAPE
#define PARAM_BEAM_FILTER mix_master(param.BEAM_FILTER, 0.0, -1.0, 1.0)
#define PARAM_CRT_CURVATURE_AMOUNT mix_master(param.CRT_CURVATURE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_VIGNETTE_AMOUNT mix_master(param.CRT_VIGNETTE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_NOISE_AMOUNT mix_master(param.CRT_NOISE_AMOUNT, 0.0, 0.0, 1.0)
#define PARAM_CRT_CORNER_RAIDUS mix_master(param.CRT_CORNER_RAIDUS, 0.0, 0.0, 0.25)
#define PARAM_CRT_CORNER_SMOOTHNESS param.CRT_CORNER_SMOOTHNESS
#define PARAM_HALATION_INTENSITY 0.0 // unused for single-pass 

#include "common/utilities.h"

#define INPUT(color)                       \
    apply_floor(                           \
        decode_gamma(color),               \
        PARAM_COLOR_FLOOR)
#define OUTPUT(color)                      \
    encode_gamma(                          \
        apply_saturation(                  \
            apply_brightness(              \
                apply_contrast(            \
                    color,                 \
                    PARAM_COLOR_CONTRAST), \
                PARAM_COLOR_BRIGHTNESS),   \
            PARAM_COLOR_SATURATION))

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

#include "crt-yah.vs.h"

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

// required by crt-yah.fs.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_BRIGHTNESS_COMPENSATION BrightnessCompensation
#define INPUT_SUBPIXEL_SIZE SubpixelSize
#define INPUT_SUBPIXEL_SMOOTHNESS SubpixelSmoothness
#define INPUT_BEAM_FILTER BeamFilter
#define INPUT_BEAM_PROFILE BeamProfile

#include "crt-yah.fs.h"

void main()
{
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);
    vec2 tex_coord_curved_sharpend = apply_sharp_bilinear_filtering(tex_coord_curved);

    vec3 raw_color = get_raw_color(Source, tex_coord_curved_sharpend);
    vec3 scanlines_color = get_scanlines_color(Source, tex_coord_curved);

    vec3 color = blend_colors(raw_color, scanlines_color);
    float color_luma = get_luminance(color);

    color = apply_noise(color, color_luma, tex_coord); // use un-curved coordinates to avoid Moire-artefacts
    color = apply_mask(color, color_luma, tex_coord);  // use un-curved coordinates to avoid Moire-artefacts
    color = apply_color_overflow(color);
    color = apply_brightness_compensation(color, color_luma);

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color), 1.0);
}
