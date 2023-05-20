#ifndef SUBPIXEL_COLOR_DEFINDED

#define SUBPIXEL_COLOR_DEFINDED

#include "colorspace-srgb.h"
#include "utilities.h"

#define EPSILON 0.000001

const vec3 White = vec3(1.0, 1.0, 1.0);
const vec3 Black = vec3(0.0, 0.0, 0.0);
const vec3 Red = vec3(1.0, 0.0, 0.0);
const vec3 Blue = vec3(0.0, 0.0, 1.0);
const vec3 Green = vec3(0.0, 1.0, 0.0);
const vec3 Magenta = vec3(1.0, 0.0, 1.0);
const vec3 Yellow = vec3(1.0, 1.0, 0.0);
const vec3 Cyan = vec3(0.0, 1.0, 1.0);

vec2 shift_x_every_y(vec2 pixCoord, float x, float y)
{
    return vec2(
        mix(0.0, x, floor(pixCoord.y / y)),
        0.0);
}

vec2 shift_x_all_y(vec2 pixCoord, float x, float y)
{
    return vec2(
        mix(0.0, x, floor(mod(pixCoord.y / y, 2.0))),
        0.0);
}

vec2 shift_x_each_y(vec2 pixCoord, float x, float y)
{
    return vec2(
        mix(0.0, x, floor(max(0.0, mod(pixCoord.y, y) - (y - 2.0)))),
        0.0);
}

vec2 shift_y_every_x(vec2 pixCoord, float y, float x)
{
    return vec2(
        0.0,
        mix(0.0, y, floor(pixCoord.x / x)));
}

vec2 shift_y_all_x(vec2 pixCoord, float y, float x)
{
    return vec2(
        0.0,
        mix(0.0, y, floor(mod(pixCoord.x / x, 2.0))));
}

vec2 shift_y_each_x(vec2 pixCoord, float y, float x)
{
    return vec2(
        0.0,
        mix(0.0, y, floor(max(0.0, mod(pixCoord.x, x) - (x - 2.0)))));
}

int get_index(float pixCoord, int count)
{
    return int(floor(mod(pixCoord, count)));
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2)
{
    vec3 colors[2] = { c1, c2 };
    return colors[get_index(pixCoord.x, 2)];
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2, vec3 c3)
{
    vec3 colors[3] = { c1, c2, c3 };
    return colors[get_index(pixCoord.x, 3)];
}

vec3 get_subpixel_color(vec2 pixCoord, vec3 c1, vec3 c2, vec3 c3, vec3 c4)
{
    vec3 colors[4] = { c1, c2, c3, c4 };
    return colors[get_index(pixCoord.x, 4)];
}

// Gets the sub-pixel color of a mask with full saturation.
//    to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//    which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @type - the mask type [1, 3]
//    1: Aperture-grille
//    2: Slot-mask
//    3: Shadow-mask
// @colors - the colors type [0, 4]
//    0: white, black
//    1: green, magenta
//    2: green, magenta, black
//    3: red, green, blue
//    4: red, green, blue, black
// @swap - whether the sub-pixel color shall be swapped
//    0: red/green/blue, green/magenta
//    1: blue/green/red, blue/yellow
vec3 get_subpixel_color(vec2 pixCoord, int size, int type, int colors, bool swap)
{
    vec3 color = White;

    if (type == 0)
    {
        return color;
    }

    pixCoord /= size;

    vec3 c1 = swap ? Red : Blue;
    vec3 c2 = Green;
    vec3 c3 = swap ? Blue : Red;
    vec3 c4 = Black;

    if (colors == 0)
    {
        c1 = White;
        c2 = Black;
    }
    else if (colors == 1)
    {
        c1 = swap ? Yellow : Magenta;
        c2 = swap ? Blue : Green;
    }
    else if (colors == 2)
    {
        c1 = swap ? Yellow : Magenta;
        c2 = swap ? Blue : Green;
        c3 = Black;
    }

    // Aperture-grille
    if (type == 1)
    {
        // white, black
        // green, magenta
        if (colors == 0 || colors == 1)
        {
            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // red, green, blue
        else if (colors == 2 || colors == 3)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (colors == 4)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }
    // Slot-mask
    else if (type == 2)
    {
        // white, black
        // magenta, green
        if (colors == 0 || colors == 1)
        {
            pixCoord += shift_y_all_x(pixCoord, 2.0, 2.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // red, green, blue
        else if (colors == 2 || colors == 3)
        {
            pixCoord += shift_y_all_x(pixCoord, 2.0, 3.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (colors == 4)
        {
            pixCoord += shift_y_all_x(pixCoord, 2.0, 4.0);

            color = get_index(pixCoord.y, 4) == 0
                ? c4
                : get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }
    // Shadow-mask
    else if (type == 3)
    {
        // white, black
        // magenta, green
        if(colors == 0 || colors == 1)
        {
            pixCoord += shift_x_all_y(pixCoord, 1.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // green, magenta, black
        // reg, green, blue
        else if (colors == 2 || colors == 3)
        {
            pixCoord += shift_x_all_y(pixCoord, 1.5, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift

            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // reg, green, blue, black
        else if (colors == 4)
        {
            pixCoord += shift_x_all_y(pixCoord, 2.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }

    return color;
}

// Gets the sub-pixel color of a mask with full saturation.
//    to apply a mask intensity add (1.0 - intensity) to the mask color.
// @pixCoord - the pixel coordinate
//    which is usually the texture coordinate multiplied by the output size.
// @size - the mask size
// @type - the mask type [1, 3]
//    1: Aperture-grille
//    2: Slot-mask
//    3: Shadow-mask
// @colors - the colors type [0, 4]
//    0: white, black
//    1: green, magenta
//    2: green, magenta, black
//    3: red, green, blue
//    4: red, green, blue, black
// @swap - whether the sub-pixel color shall be swapped
//    0: red/green/blue, green/magenta
//    1: blue/green/red, blue/yellow
// @radius - the corner radius of the sub-pixel
// @smoothness - the smoothness of the sub-pixel
vec3 get_subpixel_color(vec2 pixCoord, int size, int type, int colors, bool swap, float radius, float smoothness)
{
    vec3 color = White;

    if (type == 0)
    {
        return color;
    }

    pixCoord /= size;

    vec2 bounds = vec2(1.0, 1.0);
    vec2 scale = vec2(1.0, 1.0);

    vec3 c1 = swap ? Red : Blue;
    vec3 c2 = Green;
    vec3 c3 = swap ? Blue : Red;
    vec3 c4 = Black;

    if (colors == 0)
    {
        c1 = White;
        c2 = Black;
    }
    else if (colors == 1)
    {
        c1 = swap ? Yellow : Magenta;
        c2 = swap ? Blue : Green;
    }
    else if (colors == 2)
    {
        c1 = swap ? Yellow : Magenta;
        c2 = swap ? Blue : Green;
        c3 = Black;
    }

    // Aperture-grille
    if (type == 1)
    {
        float shift =
            // correct shape for size 3
            size == 3 ? 1.0 / 6.0 :
            // default
            0.0;

        pixCoord.x += shift;

        // white, black
        // magenta, green
        if (colors == 0 || colors == 1)
        {
            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // magenta, green, black
        // red, green, blue
        else if (colors == 2 || colors == 3)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // red, green, blue, black
        else if (colors == 4)
        {
            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }

        bounds = vec2(1.0, 10000.0);
    }
    // Slot-mask
    else if (type == 2)
    {
        // correct shape for size 1
        float height = size == 1
            ? 4.0
            : 3.0;

        float offset =
            // correct shape for size 1
            size == 1 ? 1.0 :
            // correct shape for size 2
            size == 2 ? 0.5 :
            // default
            0.25;

        vec2 shift =
            // correct shape for size 3
            size == 3 ? vec2(1.0 / 6.0, offset / 2.0) :
            // default
            vec2(0.0);

        pixCoord += shift;

        // white, black
        // magenta, green
        if (colors == 0 || colors == 1)
        {
            pixCoord += shift_y_all_x(pixCoord, 1.5, 2.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset / 2.0;

            color = get_subpixel_color(pixCoord, c1, c2);

            bounds = vec2(1.0, height);
            scale = vec2(1.0, (height - offset) / height);
        }
        // magenta, green, black
        // red, green, blue
        else if (colors == 2 || colors == 3)
        {
            pixCoord += shift_y_all_x(pixCoord, 1.5, 3.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset / 2.0;

            color = get_subpixel_color(pixCoord, c1, c2, c3);

            bounds = vec2(1.0, height);
            scale = vec2(1.0, (height - offset) / height);
        }
        // red, green, blue, black
        else if (colors == 4)
        {
            pixCoord += shift_y_all_x(pixCoord, 1.5, 4.0);
            pixCoord.y *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift
            pixCoord.y += offset / 2.0;

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);

            bounds = vec2(1.0, height);
            scale = vec2(1.0, (height - offset) / height);
        }
    }
    // Shadow-mask
    else if (type == 3)
    {
        // white, black
        // magenta, green
        if(colors == 0 || colors == 1)
        {
            pixCoord += shift_x_all_y(pixCoord, 1.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2);
        }
        // magenta, green, black
        // reg, green, blue
        else if (colors == 2 || colors == 3)
        {
            float shift =
                // correct shape for size 3
                size == 3 ? (1.0 / 6.0) :
                // default
                0.0;

            pixCoord += shift_x_all_y(pixCoord, 1.5 + shift, 1.0);
            pixCoord.x *= 1.0 + EPSILON; // avoid color artifacts due to half pixel shift

            color = get_subpixel_color(pixCoord, c1, c2, c3);
        }
        // reg, green, blue, black
        else if (colors == 4)
        {
            pixCoord += shift_x_all_y(pixCoord, 2.0, 1.0);

            color = get_subpixel_color(pixCoord, c1, c2, c3, c4);
        }
    }

    color *= smooth_round_box(
        fract(pixCoord / bounds),
        bounds * 1000,
        scale,
        radius,
        smoothness);

    return color;
}

// Gets the weight of the given sub-pixel color of a mask by the specified intensity.
// @color - the full-saturated color of the mask
//    see: get_subpixel_color()
// @intensity - the intensity of the mask in range [-1.0, 1.0]
//    < 0: applies a darkening mask
//    > 0: applies a lightening mask
vec3 get_subpixel_weight(vec3 color, float intensity)
{
    color = clamp(color, 0.0, 1.0);
    color += 1.0 - abs(intensity);
    color = clamp(color, 0.0, 1.0);

    if (intensity > 0.0)
    {
        color += intensity;
    }

    return color;
}

#endif // SUBPIXEL_COLOR_DEFINDED
