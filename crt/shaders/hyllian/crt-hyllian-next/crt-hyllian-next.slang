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

#include "crt-hyllian-next.parameters"

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
layout(set = 0, binding = 3) uniform sampler2D LutPass;

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

#define TextureSource LutPass 
#define HalationSource Source

void main()
{
    vec2 tex_coord = TexCoord;
    vec2 tex_coord_curved = apply_cubic_lens_distortion(tex_coord);

    vec3 color = get_color(TextureSource, tex_coord_curved);

    // use the un-curved coordinates for mask (not realistic, but avoids artifacts)
    color = apply_mask(color, tex_coord);
    color = apply_color_overflow(color);
    color = apply_halation(color, HalationSource, tex_coord_curved);

    // clip color to avoid color > 1.0 to affect subsequent effects 
    color = min(vec3(1.0), color);

    color *= get_vignette_factor(tex_coord_curved);
    color *= get_round_corner_factor(tex_coord_curved);

    FragColor = vec4(OUTPUT(color), 1.0);
}
