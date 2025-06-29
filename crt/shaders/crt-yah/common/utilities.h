#ifndef UTILITIES_DEFINDED

#define UTILITIES_DEFINDED

#define EPSILON 1e-6

// Returns a semi-random value based on the given seed.
// @seed: the seed value
// See: https://www.stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader/
float random(vec2 seed)
{
    const float gelfond = 23.140692; // e^pi (Gelfond constant)
    const float gelfondSchneider = 2.6651442; // 2^sqrt(2) (Gelfond-Schneider constant)

    // use irrationals for pseudo randomness
    vec2 i = vec2(gelfond, gelfondSchneider);

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

// Gets the texture coordinates for sharp bi-linear filtering, when the texture is filtered bi-linear.
// @tex_coord: the original texture coordinate
// @source_size: the size of the input sampler
// @output_size: the size of the output target
// Remarks: Based on the sharp bi-linear shader by The Maister.
vec2 sharp_bilinear(vec2 tex_coord, vec2 source_size, vec2 output_size)
{
    vec2 texel = tex_coord * source_size;

    // figure out where in the texel to sample to get correct pre-scaled bilinear
    float scale = floor(output_size.y / source_size.y + EPSILON);
    float region_range = 0.5 - 0.5 / scale;
    vec2 center_distance = fract(texel) - 0.5;
    vec2 fraction = (center_distance - clamp(center_distance, -region_range, region_range)) * scale + 0.5;

    vec2 sharp_texel = floor(texel) + fraction;

    return sharp_texel / source_size;
}

#endif // UTILITIES_DEFINDED
