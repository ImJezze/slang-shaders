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
    vec4 PhosphorPassSize;
    uint FrameCount;
} global;

layout (push_constant) uniform Push
{
    float GLOBAL_MASTER;
    float SCREEN_SCALE;
    float SCREEN_OFFSET;
    float SCREEN_ORIENTATION;
    float COLOR_BRIGHTNESS;
    float COLOR_COMPENSATION;
    float COLOR_OVERFLOW;
    float COLOR_CONTRAST;
    float SCANLINES_STRENGTH;
    float BEAM_WIDTH;
    float BEAM_SHAPE;
    float BEAM_SHARPNESS;
    float BEAM_FILTER;
    float SCANLINES_COLOR_BURN;
    float MASK_INTENSITY;
    float MASK_SIZE;
    float MASK_TYPE;
    float MASK_COLOR_COUNT;
    float MASK_COLOR_BLEED;
    float CRT_CURVATURE_AMOUNT;
    float CRT_VIGNETTE_AMOUNT;
    float CRT_CORNER_RAIDUS;
    float CRT_CORNER_SMOOTHNESS;
} param;

// Global parameters
#pragma parameter GLOBAL_MASTER "· ¹Global > Master  (0-None .. 1-Full)" 1.0 0.0 1.0 0.05

// Color parameters
#pragma parameter COLOR_CONTRAST "·  Color > Contrast¹  (-Lower / +Higher)" 0.25 -2.0 2.0 0.05
#pragma parameter COLOR_BRIGHTNESS "   Color > Brightnes¹  (-Darken / +Lighten)" 0.0 -1.0 2.0 0.05
#pragma parameter COLOR_OVERFLOW "   Color > Brightnes Overflow  (0-None .. 1-Full)" 0.5 0.0 2.0 0.25
#pragma parameter COLOR_COMPENSATION "  ²Color > Brightnes Compensation  (0-Off, 1-On)" 1.0 0.0 1.0 1.0

// Scanline/beam parameters
#pragma parameter SCANLINES_STRENGTH "·  Scanlines > Strength¹²  (0-None .. 1-Full)" 0.5 0.0 1.0 0.05
#pragma parameter BEAM_WIDTH "   Scanlines > Beam Width  (0-Uniform .. 1-Varying / 2-Merging)" 1.25 0.0 2.0 0.25
#pragma parameter BEAM_SHAPE "   Scanlines > Beam Shape  (0-Sharp .. 1-Smooth)" 0.5 0.0 1.0 0.25
#pragma parameter BEAM_FILTER "   Scanlines > Beam Filter  (1-Hermite, 2-Hyllian, 3-Catrom)" 1.0 1.0 3.0 1.0
#pragma parameter BEAM_SHARPNESS "   Scanlines > Beam Filter Sharpness  (0-None, 2x, 4x, 8x)" 0.0 0.0 3.0 1.0
#pragma parameter SCANLINES_COLOR_BURN "   Scanlines > Color Burn  (0-None .. 1-Full)" 0.5 0.0 1.0 0.25

// Mask parameters
#pragma parameter MASK_INTENSITY "·  Mask > Intensity¹²  (-Darken / +Lighten)" 0.5 -1.0 1.0 0.05
#pragma parameter MASK_TYPE "   Mask > Type²  (0-Off, 1-Aperture, 2-Slot, 3-Shadow)" 1.0 0.0 3.0 1.0
#pragma parameter MASK_COLOR_COUNT "   Mask > Color Count²  (0-Mono, 1-BY, 2-MG, 3-RGB, 4-RGBK)" 3.0 0.0 4.0 1.0
#pragma parameter MASK_COLOR_BLEED "   Mask > Color Bleed  (0-None .. 1-Full)" 0.5 0.0 1.0 0.25
#pragma parameter MASK_SIZE "   Mask > Size  (-Down / 0-Auto / +Up)" 0.0 -4.0 4.0 1.0

// CRT parameters
#pragma parameter CRT_CURVATURE_AMOUNT "·  CRT > Curvature¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_VIGNETTE_AMOUNT "   CRT > Vignette¹  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05
#pragma parameter CRT_CORNER_RAIDUS "   CRT > Corner Radius¹  (0-None .. 25%)" 0.0 0.0 0.25 0.01
#pragma parameter CRT_CORNER_SMOOTHNESS "   CRT > Corner Smoothness  (0-None .. 1-Full)" 0.0 0.0 1.0 0.05

// Screen parameters
#pragma parameter SCREEN_ORIENTATION "·  Screen > Orientation  (0-Auto, 1-Horizontal, 2-Vertical)" 0.0 0.0 2.0 1.0
#pragma parameter SCREEN_SCALE "   Screen > Scale  (-Down / 0-Auto / +Up)" 0.0 -4.0 4.0 0.25
#pragma parameter SCREEN_OFFSET "   Screen > Shift  (-Negative / +Positive)" 0.0 -2.0 2.0 1.0

#pragma parameter INFO1 "¹ Reduces marked effects" 0.0 0.0 0.0 0.0
#pragma parameter INFO2 "² Compensates marked effect's brightness changes" 0.0 0.0 0.0 0.0

#define PARAM_SCREEN_SCALE param.SCREEN_SCALE
#define PARAM_SCREEN_OFFSET param.SCREEN_OFFSET
#define PARAM_SCREEN_ORIENTATION param.SCREEN_ORIENTATION
#define PARAM_COLOR_BRIGHTNESS \
    mix(0.0, param.COLOR_BRIGHTNESS, param.GLOBAL_MASTER)
#define PARAM_COLOR_OVERFLOW param.COLOR_OVERFLOW
#define PARAM_COLOR_COMPENSATION param.COLOR_COMPENSATION
#define PARAM_COLOR_CONTRAST \
    mix(0.0, param.COLOR_CONTRAST, param.GLOBAL_MASTER)
#define PARAM_MASK_INTENSITY \
    mix(0.0, param.MASK_INTENSITY, param.GLOBAL_MASTER)
#define PARAM_MASK_SIZE param.MASK_SIZE
#define PARAM_MASK_TYPE param.MASK_TYPE
#define PARAM_MASK_COLOR_COUNT param.MASK_COLOR_COUNT
#define PARAM_MASK_COLOR_BLEED param.MASK_COLOR_BLEED
#define PARAM_SCANLINES_STRENGTH \
    mix(0.0, param.SCANLINES_STRENGTH, param.GLOBAL_MASTER)
#define PARAM_BEAM_WIDTH param.BEAM_WIDTH
#define PARAM_BEAM_SHAPE param.BEAM_SHAPE
#define PARAM_BEAM_SHARPNESS param.BEAM_SHARPNESS
#define PARAM_BEAM_FILTER param.BEAM_FILTER
#define PARAM_SCANLINES_COLOR_BURN param.SCANLINES_COLOR_BURN
#define PARAM_CRT_CURVATURE_AMOUNT \
    mix(0.0, param.CRT_CURVATURE_AMOUNT, param.GLOBAL_MASTER)
#define PARAM_CRT_VIGNETTE_AMOUNT \
    mix(0.0, param.CRT_VIGNETTE_AMOUNT, param.GLOBAL_MASTER)
#define PARAM_CRT_CORNER_RAIDUS \
    mix(0.0, param.CRT_CORNER_RAIDUS, param.GLOBAL_MASTER)
#define PARAM_CRT_CORNER_SMOOTHNESS param.CRT_CORNER_SMOOTHNESS
#define PARAM_HALATION_INTENSITY 0.0 // unused here, but required by crt-hyllian-next-fs.h

#include "common/utilities.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float ScreenOrientation;
layout(location = 2) out float ScreenMultiple;
layout(location = 3) out float SubpixelSize;
layout(location = 4) out float SubpixelSmoothness;
layout(location = 5) out float BrightnessCompensation;
layout(location = 6) out float MaximumColor;
layout(location = 7) out vec4 BeamProfile;
layout(location = 8) out mat4x4 BeamFilter;

#include "crt-hyllian-next-vs.h"

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    ScreenOrientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    ScreenMultiple = get_multiple_stepwise(global.OriginalSize.xy, ScreenOrientation, -PARAM_SCREEN_SCALE);
    SubpixelSize = get_subpixel_size(ScreenMultiple);
    SubpixelSmoothness = get_subpixel_smoothness(SubpixelSize);
    BrightnessCompensation = get_brightness_compensation(SubpixelSmoothness);
    MaximumColor = apply_brightness(vec3(1.0), PARAM_COLOR_BRIGHTNESS + BrightnessCompensation).r;
    BeamProfile = get_beam_profile(MaximumColor);
    BeamFilter = get_beam_filter();
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float ScreenOrientation;
layout(location = 2) in float ScreenMultiple;
layout(location = 3) in float SubpixelSize;
layout(location = 4) in float SubpixelSmoothness;
layout(location = 5) in float BrightnessCompensation;
layout(location = 6) in float MaximumColor;
layout(location = 7) in vec4 BeamProfile;
layout(location = 8) in mat4x4 BeamFilter;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

// required by crt-hyllian-next-fs.h
#define INPUT_SCREEN_ORIENTATION ScreenOrientation
#define INPUT_SCREEN_MULTIPLE ScreenMultiple
#define INPUT_BRIGHTNESS_COMPENSATION BrightnessCompensation
#define INPUT_SUBPIXEL_SIZE SubpixelSize
#define INPUT_SUBPIXEL_SMOOTHNESS SubpixelSmoothness
#define INPUT_BEAM_FILTER BeamFilter
#define INPUT_BEAM_PROFILE BeamProfile
#define INPUT_MAXIMUM_COLOR MaximumColor

#include "crt-hyllian-next-fs.h"

void main()
{
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);

    vec3 color = get_color(Source, tex_coord_curved);

    // use the un-curved coordinates for mask (not realistic, but avoids artifacts)
    color = apply_mask(color, tex_coord);
    color = apply_color_overflow(color);

    // clip color to avoid color > 1.0 to affect subsequent effects 
    color = min(vec3(1.0), color);

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color), 1.0);
}
