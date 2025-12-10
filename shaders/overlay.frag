#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Viewport bounds: (topLeftLat, topLeftLon, bottomRightLat, bottomRightLon)
    vec4 viewportBounds;

    // Data bounds: (minLat, maxLat, minLon, maxLon)
    vec4 dataBounds;
};

// Climate data texture (normalized values in R channel, alpha=255 means valid data)
layout(binding = 1) uniform sampler2D dataTexture;

const float PI = 3.14159265359;

// Convert latitude to Web Mercator Y coordinate
float latToMercatorY(float lat) {
    lat = clamp(lat, -85.0, 85.0);
    float latRad = radians(lat);
    return log(tan(PI / 4.0 + latRad / 2.0));
}

// Convert Web Mercator Y coordinate back to latitude
float mercatorYToLat(float y) {
    return degrees(2.0 * atan(exp(y)) - PI / 2.0);
}

// Color gradient function: maps value (0-1) to a color
// Blue -> Cyan -> Green -> Yellow -> Red
vec3 valueToColor(float value) {
    value = clamp(value, 0.0, 1.0);

    vec3 color;
    if (value < 0.25) {
        float t = value / 0.25;
        color = mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), t);
    } else if (value < 0.5) {
        float t = (value - 0.25) / 0.25;
        color = mix(vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0), t);
    } else if (value < 0.75) {
        float t = (value - 0.5) / 0.25;
        color = mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0), t);
    } else {
        float t = (value - 0.75) / 0.25;
        color = mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), t);
    }

    return color;
}

void main() {
    // Extract viewport bounds
    float topLeftLat = viewportBounds.x;
    float topLeftLon = viewportBounds.y;
    float bottomRightLat = viewportBounds.z;
    float bottomRightLon = viewportBounds.w;

    // Extract data bounds
    float minLat = dataBounds.x;
    float maxLat = dataBounds.y;
    float minLon = dataBounds.z;
    float maxLon = dataBounds.w;

    // Convert viewport latitudes to Mercator Y coordinates
    float topMercY = latToMercatorY(topLeftLat);
    float bottomMercY = latToMercatorY(bottomRightLat);

    // Interpolate in Mercator space, then convert back to latitude
    float mercY = mix(topMercY, bottomMercY, qt_TexCoord0.y);
    float lat = mercatorYToLat(mercY);

    // Longitude is linear
    float lon = mix(topLeftLon, bottomRightLon, qt_TexCoord0.x);

    // Check if current position is within data bounds
    if (lat < minLat || lat > maxLat || lon < minLon || lon > maxLon) {
        fragColor = vec4(0.0);
        return;
    }

    // Map geographic coordinates to texture coordinates
    // Texture: Y=0 is top (maxLat), Y=1 is bottom (minLat)
    // Texture: X=0 is left (minLon), X=1 is right (maxLon)
    float texU = (lon - minLon) / (maxLon - minLon);
    float texV = (maxLat - lat) / (maxLat - minLat);

    // Sample the data texture
    vec4 texSample = texture(dataTexture, vec2(texU, texV));

    // Check if this pixel has valid data (alpha > 0)
    if (texSample.a < 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    // Get normalized value from red channel
    float value = texSample.r;

    // Convert to color
    vec3 color = valueToColor(value);

    // Use premultiplied alpha for correct Qt compositing
    fragColor = vec4(color * qt_Opacity, qt_Opacity);
}
