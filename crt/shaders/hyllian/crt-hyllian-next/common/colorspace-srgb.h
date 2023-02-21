#ifndef COLORSPACE_SRGB_DEFINDED

#define COLORSPACE_SRGB_DEFINDED

const float LumaR = 0.2126;
const float LumaG = 0.7152;
const float LumaB = 0.0722;
const vec3 LumaC = vec3(LumaR, LumaG, LumaB);

// Returns the luminance of the given color by the default sRGB coefficients.
// @color - the color.
float get_luminance(vec3 color)
{
    return
        color.r * LumaR +
        color.g * LumaG +
        color.b * LumaB;
}

// Converts the given color from RGB to sRGB by the specified gamma.
//   This function uses an approximation and fails for very dark colors.
// @color - the color.
// @gamma - the gamma.
vec3 rgb_to_srgb_fast(vec3 rgb, float gamma)
{
    return pow(rgb, vec3(gamma));    
}

// Converts the given color from RGB to sRGB using the default gamma of 2.2.
//   This function uses an approximation and fails for very dark colors.
// @color - the color.
vec3 rgb_to_srgb_fast(vec3 rgb)
{
    return rgb_to_srgb_fast(rgb, 2.2);    
}

// Converts the given color from sRGB to RGB by the specified gamma.
//   This function uses an approximation and fails for very dark colors.
// @color - the color.
// @gamma - the gamma.
vec3 srgb_to_rgb_fast(vec3 srgb, float gamma)
{
    return pow(srgb, vec3(1.0 / gamma));    
}

// Converts the given color from sRGB to RGB using the default gamma of 2.2.
//   This function uses an approximation and fails for very dark colors.
// @color - the color.
vec3 srgb_to_rgb_fast(vec3 srgb)
{
    return srgb_to_rgb_fast(srgb, 2.2);    
}

#endif // COLORSPACE_SRGB_DEFINDED
