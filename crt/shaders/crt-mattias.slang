#version 450

// CRT Emulation
// by Mattias
// https://www.shadertoy.com/view/lsB3DV

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
   float CURVATURE;
   float SCANSPEED;
} params;

#pragma parameter CURVATURE "Curvature" 0.5 0.0 1.0 0.05
#pragma parameter SCANSPEED "Scanline Crawl Speed" 1.0 0.0 10.0 0.5

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define iChannel0 Source
#define iTime (float(params.FrameCount) / 60.0)
#define iResolution params.OutputSize.xy
#define fragCoord (vTexCoord.xy * params.OutputSize.xy)
#define Pi 3.1415927
#define Pi2 (Pi * 2.0)
#define HalfPi (Pi * 0.5)

vec3 sample_( sampler2D tex, vec2 tc )
{
    vec3 s = pow(texture(tex,tc).rgb, vec3(2.2));
    return s;
}

vec3 blur(sampler2D tex, vec2 tc, float offs)
{
    vec4 xoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / iResolution.x;
    vec4 yoffs = offs * vec4(-2.0, -1.0, 1.0, 2.0) / iResolution.y;

    vec3 color = vec3(0.0, 0.0, 0.0);
    color += sample_(tex,tc + vec2(xoffs.x, yoffs.x)) * 0.00366;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.x)) * 0.01465;
    color += sample_(tex,tc + vec2(0.00000, yoffs.x)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.x)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.x)) * 0.00366;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.y)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.y)) * 0.05861;
    color += sample_(tex,tc + vec2(0.00000, yoffs.y)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.y)) * 0.05861;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.y)) * 0.01465;

    color += sample_(tex,tc + vec2(xoffs.x, 0.00000)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.y, 0.00000)) * 0.09524;
    color += sample_(tex,tc + vec2(0.00000, 0.00000)) * 0.15018;
    color += sample_(tex,tc + vec2(xoffs.z, 0.00000)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.w, 0.00000)) * 0.02564;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.z)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.z)) * 0.05861;
    color += sample_(tex,tc + vec2(0.00000, yoffs.z)) * 0.09524;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.z)) * 0.05861;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.z)) * 0.01465;

    color += sample_(tex,tc + vec2(xoffs.x, yoffs.w)) * 0.00366;
    color += sample_(tex,tc + vec2(xoffs.y, yoffs.w)) * 0.01465;
    color += sample_(tex,tc + vec2(0.00000, yoffs.w)) * 0.02564;
    color += sample_(tex,tc + vec2(xoffs.z, yoffs.w)) * 0.01465;
    color += sample_(tex,tc + vec2(xoffs.w, yoffs.w)) * 0.00366;

    return color;
}

//Canonical noise function; replaced to prevent precision errors
//float rand(vec2 co){
//    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
//}

float rand(vec2 co)
{
    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
    float dt= dot(co.xy, vec2(a,b));
    float sn= mod(dt, 3.14);
    return fract(sin(sn) * c);
}

vec2 curve(vec2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}

void main()
{
    float sTime = iTime * params.SCANSPEED;

    vec2 q = fragCoord.xy / iResolution.xy;
    vec2 uv = q;
    uv = mix(uv, curve(uv), params.CURVATURE);
    vec3 col;
    float x = sin(0.1 * sTime + uv.y * 21.0) * sin(0.23 * sTime + uv.y * 29.0) * sin(0.3 + 0.11 * sTime + uv.y * 31.0) * 0.0017;
    float o = 2.0 * mod(fragCoord.y, 2.0) / iResolution.x;
    x += o;
    col.r =  1.0 * blur(iChannel0, vec2(x + uv.x + 0.0009, uv.y + 0.0009), 1.20).x + 0.005;
    col.g =  1.0 * blur(iChannel0, vec2(x + uv.x + 0.0000, uv.y - 0.0015), 1.20).y + 0.005;
    col.b =  1.0 * blur(iChannel0, vec2(x + uv.x - 0.0015, uv.y + 0.0000), 1.20).z + 0.005;
    col.r += 0.2 * blur(iChannel0, vec2(x + uv.x + 0.0009, uv.y + 0.0009), 2.25).x - 0.005;
    col.g += 0.2 * blur(iChannel0, vec2(x + uv.x + 0.0000, uv.y - 0.0015), 1.75).y - 0.005;
    col.b += 0.2 * blur(iChannel0, vec2(x + uv.x - 0.0015, uv.y + 0.0000), 1.25).z - 0.005;
    col.r += 0.05 * (1.0 - 0.299) * blur(iChannel0, 0.75 * vec2(x - 0.010, -0.027) + vec2(uv.x + 0.001, uv.y + 0.001), 7.0).x;
    col.g += 0.05 * (1.0 - 0.587) * blur(iChannel0, 0.75 * vec2(x - 0.022, -0.020) + vec2(uv.x + 0.000, uv.y - 0.002), 5.0).y;
    col.b += 0.05 * (1.0 - 0.114) * blur(iChannel0, 0.75 * vec2(x - 0.020, -0.000) + vec2(uv.x - 0.002, uv.y + 0.000), 3.0).z;

    col = clamp(0.4 * col + 0.6 * col * col, 0.0, 1.0);

    float vig = (16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));
    vig = pow(vig, 0.3);
    col *= vec3(vig);

    col *= vec3(0.95, 1.05, 0.95);
    col = mix(col, col * col, 0.3) * 3.8;

    float scans_y = (uv.y * params.OriginalSize.y * Pi2) - HalfPi;
    float scans = clamp(0.35 + 0.15 * sin(3.5 * sTime + scans_y), 0.0, 1.0);

    float s = pow(scans, 0.9);
    col = col * vec3(s);

    col *= 1.0 + 0.0015 * sin(300.0 * iTime);

    col *= 1.0 - 0.15 * vec3(clamp((mod(fragCoord.x + o, 2.0) - 1.0) * 2.0, 0.0, 1.0));
    col *= vec3( 1.0 ) - 0.25 * vec3(rand(uv + 0.0001 * iTime), rand(uv + 0.0001 * iTime + 0.3), rand(uv + 0.0001 * iTime + 0.5));
    col = pow(col, vec3(0.45));

    if (uv.x < 0.0 || uv.x > 1.0)
        col *= 0.0;
    if (uv.y < 0.0 || uv.y > 1.0)
        col *= 0.0;

    FragColor = vec4(col, 1.0);
}
