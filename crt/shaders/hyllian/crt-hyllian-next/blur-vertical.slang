#version 450

/*
    Based on Vertical Blur shader by Hunter Kaller
    Modified by Jezze
*/

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OriginalSize;
    vec4 SourceSize;
    vec4 OutputSize;
    vec4 FinalViewportSize;
} global;

#include "crt-hyllian-next.parameters"
#include "common/utilities.h"
#include "common/colorspace-srgb.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out float Diffusion;
layout(location = 2) out float Tabs;
layout(location = 3) out float Multiple;

void main()
{
    gl_Position = global.MVP * Position;
    TexCoord = Coord;

    Diffusion = normalized_sigmoid(PARAM_HALATION_DIFFUSION, -0.5);
    Diffusion = max(0.02, 1.0 - Diffusion);

    Tabs = normalized_sigmoid(PARAM_HALATION_DIFFUSION, 0.5) * 16.0;
    Tabs = max(4.0, round(Tabs));

    Multiple = get_multiple(global.SourceSize.xy);
    Multiple = max(1.0, round(Multiple));

    // normalize multiple based on ratio change with horizontal as reference
    Multiple = Multiple
        // from texture source
        * get_ratio(global.SourceSize.xy, 0)
        // to screen target
        / get_ratio(global.FinalViewportSize.xy, 0);
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in float Diffusion;
layout(location = 2) in float Tabs;
layout(location = 3) in float Multiple;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define INPUT(color) rgb_to_srgb_fast(color)
#define OUTPUT(color) srgb_to_rgb_fast(color)

void main()
{
    if (PARAM_HALATION_INTENSITY == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 color = vec3(0.0);
    float sum = 0.0;

    // scale diffusion
    float diffusion = Diffusion / (Multiple * Multiple);

    // scale tabs (can be quite in-performant for high resolutions)
    int tabs = int(Tabs * Multiple);
    for (int i = -tabs; i <= tabs; i++)
    {
        vec2 texCoord = TexCoord;
        texCoord.y += i * global.SourceSize.w;

        float k = exp(-diffusion * i * i);
        color += k * INPUT(texture(Source, texCoord).rgb);
        sum += k;
    }

    FragColor = vec4(OUTPUT(color / sum), 1.0);
}
