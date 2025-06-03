#ifndef UTILITIES_DEFINDED

#define UTILITIES_DEFINDED

#include "colorspace-srgb.h"

#define EPSILON 0.000001

const float PI = 3.1415926;
const float PIo2 = PI / 2.0;
const float E = 2.7182817;
const float Gelfond = 23.140692; // e^pi (Gelfond constant)
const float GelfondSchneider = 2.6651442; // 2^sqrt(2) (Gelfond-Schneider constant)

// www.stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader/
float random(vec2 seed)
{
    // use irrationals for pseudo randomness
    vec2 i = vec2(Gelfond, GelfondSchneider);

    return fract(cos(dot(seed, i)) * 123456.0);
}

// Applies a normalized sigmoid function to the given value.
//   The input parameters have to be in the range of [-1.0, 1.0].
// @value: the value to transform
// @slope: the slope to apply
// See: https://dinodini.wordpress.com/2010/04/05/normalized-tunable-sigmoid-functions/
float normalized_sigmoid(float value, float slope)
{
    return (value - value * slope) / (slope - abs(value) * 2.0 * slope + 1.0);
}

// Returns a value determining whether the given point is inside an axis-align box
//   of the given size and corner radius.
// @point: the point to check.
// @size: the size of the box.
// @radius: the corner radius of the box.
// See: https://iquilezles.org/articles/distfunctions/
float round_box(vec2 point, vec2 size, float radius)
{
    return length(max(abs(point) - size + radius, 0.0)) - radius;
}

// Returns the intensity of a smooth rounded box at the given coordinate.
// @coord: the texture coordinate of the box.
// @bounds: the bounds of the box.
// @scale: the scale of the box within it's bounds.
// @radius: the corner radius of the box.
// @smoothness: the smoothness the box borders.
float smooth_round_box(vec2 coord, vec2 bounds, vec2 scale, float radius, float smoothness)
{
    // center coordinates
    coord -= 0.5;
    // full bounds
    coord *= 2.0;
    // individual scale
    coord /= scale;

    // compute round box
    float boxMinimum = min(bounds.x, bounds.y);
    float boxRadius = boxMinimum * max(radius, 1.0 / boxMinimum);
    float box = round_box(coord * bounds, bounds, boxRadius);

    // apply smoothness
    float boxSmooth = 1.0 / (boxRadius * smoothness);
    box *= boxSmooth;
    box += 1.0 - pow(boxSmooth * 0.5, 0.5);

    return clamp(smoothstep(1.0, 0.0, box), 0.0, 1.0);
}

// Returns whether the x-axis is the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
bool is_landscape(vec2 size)
{
    return size.x >= size.y;
}

// Returns whether the y-axis is the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
bool is_portrait(vec2 size)
{
    return size.y > size.x;
}

// Returns the orientation based on the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
//   e.g. global.OutputSize
float get_orientation(vec2 size)
{
    return float(is_portrait(size));
}

// Returns the orientation based on the largest dimension of the given size.
//   0 - horizontal
//   1 - vertical
// @size: the size to test
//   e.g. global.OutputSize
// @orientation: the preferred orientation
//   0 - auto
//   1 - horizontal
//   2 - vertical
float get_orientation(vec2 size, float orientation)
{
    return orientation > 0.0
        ? orientation - 1.0
        : get_orientation(size);
}

// Returns the ratio of the size based on the dominant dimension.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation of the dominant dimension
//   0 - horizontal
//   1 - vertical
float get_ratio(vec2 size, float orientation)
{
    return orientation > 0.0
        ? size.x / size.y
        : size.y / size.x;
}

// Returns the ratio of the size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
float get_ratio(vec2 size)
{
    return get_ratio(size, get_orientation(size));
}

// Returns the base size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation of the dominant dimension
//   0 - horizontal
//   1 - vertical
float get_base_size(vec2 size, float orientation)
{
    return orientation > 0.0
        ? size.x
        : size.y;
}

// Returns the base size based on the dominant orientation.
// @size: the size to test
//   e.g. global.SourceSize
float get_base_size(vec2 size)
{
    return get_base_size(size, get_orientation(size));
}

#ifndef BASE_SIZE
    // The base size to compute the multiple from the source size.
    #define BASE_SIZE 240.0
#endif

#ifndef OUTPUT_SIZE
    // The output size.
    #define OUTPUT_SIZE global.FinalViewportSize
#endif

#ifndef PIXEL_SIZE_LIMIT
    // The allowed pixel size after the multiple has been applied.
    #define PIXEL_SIZE_LIMIT 3.0
#endif

// Returns the multiple of the size for the defined base size.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
float get_multiple(vec2 size, float orientation)
{
    float ratio = get_ratio(size, orientation);

    float portrait = float(is_portrait(size));

    float base_size = BASE_SIZE;
    base_size = orientation > 0.0
        ? mix(base_size * ratio, base_size, portrait)
        : mix(base_size, base_size * ratio, portrait);

    return orientation > 0.0
        ? size.x / base_size
        : size.y / base_size;
}

// Returns the multiple of the size for the defined base size.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
float get_multiple(vec2 size)
{
    return get_multiple(size, get_orientation(size));
}

const int multiple_base = 8;
const int multiple_count = 17;
const float multiple_factors[multiple_count] = float[multiple_count](
    1.0 / 9.0,
    1.0 / 8.0,
    1.0 / 7.0,
    1.0 / 6.0,
    1.0 / 5.0,
    1.0 / 4.0,
    1.0 / 3.0,
    1.0 / 2.0,
    1.0, // base
    2.0,
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0);

float get_multiple_factor(float index, float amount)
{
    return mix(
        multiple_factors[int(clamp(floor(index), 0.0, multiple_count - 1.0))],
        multiple_factors[int(clamp(ceil(index), 0.0, multiple_count - 1.0))],
        amount);
}

// Returns the multiple of the size for the defined base size, scaled by the specified offset.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
// @offset: the scaling offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
// @pixel_size_limit: the smallest allowed pixel size, which the multiple may result in.
float get_multiple(vec2 size, float orientation, float offset, float pixel_size_limit)
{
    float multiple = get_multiple(size, orientation);
    float multiple_index = max(1.0, round(multiple)) - 1.0;

    multiple_index += multiple_base;
    multiple_index += offset;

    float scale = orientation > 0.0
        ? OUTPUT_SIZE.x / size.x
        : OUTPUT_SIZE.y / size.y;
    for (multiple_index; multiple_index < multiple_count; multiple_index += 1.0)
    {
        // apply factional offset
        multiple = get_multiple_factor(multiple_index, fract(offset));

        // break at a multiple which results in a pixel size larger/equal the given limit
        if ((scale * multiple) >= pixel_size_limit)
        {
            break;
        }
    }

    return multiple;
}

float get_multiple(vec2 size, float orientation, float offset)
{
    return get_multiple(size, orientation, offset, 0.0);
}

// Returns the step-wise multiple of the size for the defined base size, scaled by the specified offset.
//   Multiple greater than 1.0 will be whole integers.
//   Multiple smaller than 1.0 will be fraction, the inverse of a whole integer.
//   The base size can be set by #define BASE_SIZE, which has to be be a float or integer.
// @size: the size to test
//   e.g. global.SourceSize
// @orientation: the orientation
//   0 - horizontal
//   1 - vertical
// @offset: the scaling offset
//   = 0.0 - the multiple will be rounded to the next integer greater equal to 1.
//   > 0.0 - in addition the multiple will be incremented by the offset.
//   < 0.0 - in addition the multiple will be decremented by the offset.
float get_multiple_stepwise(vec2 size, float orientation, float offset)
{
    offset = offset > 0.0
        ? floor(offset)
        : ceil(offset);

    return get_multiple(size, orientation, offset, PIXEL_SIZE_LIMIT);
}

// Decodes the gamma of the given color.
// @color - the color.
vec3 decode_gamma(vec3 color)
{
    return srgb_to_linear(color, 2.4);
}

// Encodes the gamma of the given color.
// @color - the color.
vec3 encode_gamma(vec3 color)
{
    return linear_to_srgb(color, 2.4);
}

// Returns the maximum value of the given color.
// @color - the color.
float max_color(vec3 color)
{
    return max(max(color.r, color.g), color.b);
}

// Normalizes the given color based on a reference color value.
// @color - the color.
// @reference - the reference color value.
vec3 normalize_color(vec3 color, float reference)
{
    return color / (max_color(color) + EPSILON) * reference;
}

// Applies the contrast to the given color.
// @color - the color.
// @contrast - the contrast to apply.
//   <0.0 - decreasing
//    0.0 - unchanged
//   >0.0 - increasing
vec3 apply_contrast(vec3 color, float contrast)
{
    float linear_max = max_color(color);

    float nonlinear_max = linear_max;

    // move range [0, 1] to [-1, 1]
    nonlinear_max = 2.0 * nonlinear_max - 1.0;

    // apply non-linear mapping
    nonlinear_max = sin(nonlinear_max * PIo2);

    // move range [-1, 1] to [0, 1]
    nonlinear_max = (nonlinear_max + 1.0) * 0.5;

    return normalize_color(
        color,
        mix(linear_max, nonlinear_max, contrast));
}

// Applies the brightness to the given color.
// @color - the color.
// @brightness - the brightness to apply.
vec3 apply_brightness(vec3 color, float brightness)
{
    return color * (1.0 + brightness);
}
float apply_brightness(float color, float brightness)
{
    return color * (1.0 + brightness);
}

// Applies a minimum value to the given color.
// @color - the color.
// @floot - the minimum value.
vec3 apply_floor(vec3 color, float floor)
{
    float luma = get_luminance(color);
    floor *= 1.0 - luma;

    return (color + floor) / (1.0 + floor);
}

// Applies the saturation to the given color.
// @color - the color.
// @saturation - the saturation to apply.
//   <0.0 - decreasing
//    0.0 - unchanged
//   >0.0 - increasing
vec3 apply_saturation(vec3 color, float saturation)
{
    float luminance = get_luminance(color);

    return saturation > 1.0
        // increase
        ? normalize_color(pow(color, vec3(saturation)), max_color(color))
        // decrease
        : mix(vec3(luminance), color, saturation);
}

// Applies the temperature to the given color based on the given white point.
// @color - the color.
// @white_point_relative - the relative white point to apply.
//   -1.0 - D55
//    0.0 - D65
//    1.0 - D75
vec3 apply_temperature(vec3 color, float white_point_relative)
{
    mat3 white_point = white_point_relative < 0.0
        // warmer
        ? D65toD55
        // cooler
        : D65toD75;

    return mix(
        color,
        color * RGBtoXYZ * white_point * XYZtoRGB,
        abs(white_point_relative));
}

#endif // UTILITIES_DEFINDED
