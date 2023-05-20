#version 450

/*
    Based on Deconverge shader by Jezze
    Ported from MAME
*/

#pragma name LutPass

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
    float SCREEN_OFFSET;
    float SCREEN_ORIENTATION;
    float COLOR_PROFILE;
} param;

#include "crt-hyllian-next.parameters"
#include "common/colorspace-srgb.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLutNtsc;
layout(set = 0, binding = 4) uniform sampler2D SamplerLutTrinitron;

vec3 apply_lut(vec3 color, sampler2D lut_sampler)
{
    float lut_size = textureSize(lut_sampler, 0).y;

    float red = (color.r * (lut_size - 1.0) + 0.5) / (lut_size * lut_size);
    float green = (color.g * (lut_size - 1.0) + 0.5) / lut_size;
    float blue1 = (floor(color.b * (lut_size - 1.0)) / lut_size) + red;

    return texture(lut_sampler, vec2(blue1, green)).rgb;
}

void main()
{
    vec3 color = texture(Source, TexCoord).rgb;

    vec3 ntsc_color = apply_lut(color, SamplerLutNtsc);
    vec3 trinitron_color = apply_lut(color, SamplerLutTrinitron);

    color = PARAM_COLOR_PROFILE < 0.0
        ? mix(color, ntsc_color, -PARAM_COLOR_PROFILE)
        : mix(color, trinitron_color, PARAM_COLOR_PROFILE);

    FragColor = vec4(color, 1.0);
}
