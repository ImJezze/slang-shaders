#version 450

/*
    NTSC-Adaptive pass 1 by Hunter Kaller
    Based on NTSC shader by The Maister
    Modified by Jezze
*/

// Required shader pass settings:
//    filter_linear0 = true
//    float_framebuffer0 = true
//    scale_type_x0 = source
//    scale_type_y0 = source
//    scale_x0 = 4.0
//    scale_y0 = 4.0

const float Prescale = 4.0;

#pragma name NtscPass1

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
    float NTSC_PROFILE;
    float NTSC_QUALITY;
} param;

#include "parameters.h"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 Coord;
layout(location = 0) out vec2 TexCoord;
layout(location = 1) out vec2 PixCoord;
layout(location = 2) out float Fringing;
layout(location = 3) out float Artifacting;
layout(location = 4) out float Phase;
layout(location = 5) out float Merge;

#include "common/screen-helper.h"

void main()
{
	gl_Position = global.MVP * Position;

    float screen_orientation = get_orientation(global.OutputSize.xy, PARAM_SCREEN_ORIENTATION);
    float screen_scale = 1.0 / get_multiple(global.OriginalSize.xy, screen_orientation, -PARAM_SCREEN_SCALE);

	TexCoord = Coord;
	PixCoord = TexCoord * global.OutputSize.xy;
    PixCoord = screen_scale < 1.0
        ? PixCoord * screen_scale
        : PixCoord;
    PixCoord = int(screen_orientation) == 0
        ? PixCoord.xy
        : PixCoord.yx;
    PixCoord.x *= max(screen_scale, 1.0);
    PixCoord.y /= Prescale;

    // 1-Low - 2 phase
    // 2-Medium - 3 phase
    // 3-High - 3 phase & field merge
    Phase = clamp(PARAM_NTSC_QUALITY + 1.0, 2.0, 3.0);
    Merge = PARAM_NTSC_QUALITY == 3.0 ? 1.0 : 0.0;

    float profile = PARAM_NTSC_PROFILE - 1.0;

	Artifacting = profile * 0.5 * (max(screen_scale, 1.0) + 1.0);
	Fringing = profile;
}

#pragma stage fragment
layout(location = 0) in vec2 TexCoord;
layout(location = 1) in vec2 PixCoord;
layout(location = 2) in float Fringing;
layout(location = 3) in float Artifacting;
layout(location = 4) in float Phase;
layout(location = 5) in float Merge;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define MIX mat3(            \
    1.0, Fringing, Fringing, \
    Artifacting, 2.0, 0.0,   \
    Artifacting, 0.0, 2.0)

#include "ntsc-pass1.h"

void main()
{
    if (PARAM_NTSC_PROFILE == 0.0)
    {
        FragColor = texture(Source, TexCoord);

        return;
    }

    vec3 yiq = pass1(Source, TexCoord, PixCoord, int(Phase), bool(Merge), MIX, global.FrameCount);

    FragColor = vec4(yiq, 1.0);
}
