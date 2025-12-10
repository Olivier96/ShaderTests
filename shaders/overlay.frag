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

    // IDW parameters: (power, sampleRadius, unused, unused)
    vec4 idwParams;
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
// Blue -> Cyan -> Green -> Yellow -> Red (professional heatmap)
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

// Calculate geographic distance with latitude correction
float geoDistance(vec2 p1, vec2 p2) {
    float dLat = p2.x - p1.x;
    float dLon = p2.y - p1.y;
    float avgLat = (p1.x + p2.x) * 0.5;
    float lonScale = cos(radians(avgLat));
    return sqrt(dLat * dLat + (dLon * lonScale) * (dLon * lonScale));
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

    // IDW parameters
    float idwPower = idwParams.x;
    float sampleRadius = idwParams.y;  // In grid cells

    // Convert viewport latitudes to Mercator Y coordinates
    float topMercY = latToMercatorY(topLeftLat);
    float bottomMercY = latToMercatorY(bottomRightLat);

    // Interpolate in Mercator space, then convert back to latitude
    float mercY = mix(topMercY, bottomMercY, qt_TexCoord0.y);
    float lat = mercatorYToLat(mercY);
    float lon = mix(topLeftLon, bottomRightLon, qt_TexCoord0.x);

    // Check if current position is within data bounds (with small margin)
    float margin = 0.5;  // Half a grid cell margin
    if (lat < minLat - margin || lat > maxLat + margin ||
        lon < minLon - margin || lon > maxLon + margin) {
        fragColor = vec4(0.0);
        return;
    }

    // Get texture size for proper sampling
    vec2 texSize = vec2(textureSize(dataTexture, 0));
    vec2 texelSize = 1.0 / texSize;

    // Map geographic coordinates to texture coordinates
    float texU = (lon - minLon) / (maxLon - minLon);
    float texV = (maxLat - lat) / (maxLat - minLat);

    // Calculate grid cell size in degrees
    float cellSizeLon = (maxLon - minLon) / texSize.x;
    float cellSizeLat = (maxLat - minLat) / texSize.y;

    // IDW interpolation: sample nearby grid cells
    float weightSum = 0.0;
    float valueSum = 0.0;
    int validSamples = 0;

    int radius = int(sampleRadius);
    vec2 currentPos = vec2(lat, lon);

    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            vec2 sampleUV = vec2(texU, texV) + vec2(float(dx), float(dy)) * texelSize;

            // Skip if outside texture bounds
            if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) {
                continue;
            }

            vec4 texSample = texture(dataTexture, sampleUV);

            // Skip if no valid data at this cell
            if (texSample.a < 0.5) {
                continue;
            }

            // Calculate the geographic position of this sample
            float sampleLon = minLon + sampleUV.x * (maxLon - minLon);
            float sampleLat = maxLat - sampleUV.y * (maxLat - minLat);
            vec2 samplePos = vec2(sampleLat, sampleLon);

            // Calculate distance
            float dist = geoDistance(currentPos, samplePos);

            // Avoid division by zero - if very close, use this value directly
            if (dist < 0.0001) {
                weightSum = 1.0;
                valueSum = texSample.r;
                validSamples = 1;
                break;
            }

            float weight = 1.0 / pow(dist, idwPower);
            weightSum += weight;
            valueSum += weight * texSample.r;
            validSamples++;
        }
        if (validSamples == 1 && weightSum == 1.0) break;  // Early exit if exact hit
    }

    // No valid samples found
    if (validSamples == 0 || weightSum < 0.0001) {
        fragColor = vec4(0.0);
        return;
    }

    // Calculate interpolated value
    float value = valueSum / weightSum;

    // Convert to color
    vec3 color = valueToColor(value);

    // Use premultiplied alpha for correct Qt compositing
    fragColor = vec4(color * qt_Opacity, qt_Opacity);
}
