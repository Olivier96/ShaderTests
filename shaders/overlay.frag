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

    // Texture size: (width, height, unused, unused) - passed as uniform for GLES compatibility
    vec4 textureSize;
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

    // IDW parameters with safety clamps
    float idwPower = max(0.1, idwParams.x);
    float sampleRadius = clamp(idwParams.y, 1.0, 3.0);

    // Safety check: ensure valid data bounds (prevent division by zero)
    if (maxLat - minLat < 0.001 || maxLon - minLon < 0.001) {
        fragColor = vec4(0.0);
        return;
    }

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

    // Get texture size for proper sampling (from uniform, for GLES compatibility)
    // Ensure minimum size of 1 to prevent division by zero
    vec2 texSize = max(textureSize.xy, vec2(1.0, 1.0));
    vec2 texelSize = 1.0 / texSize;

    // Map geographic coordinates to texture coordinates
    float texU = (lon - minLon) / (maxLon - minLon);
    float texV = (maxLat - lat) / (maxLat - minLat);

    // Empirical offset to fix north-south alignment
    // Shift sampling to move overlay northward on the map
    float northShift = 0.5 * texelSize.y;  // Half pixel shift
    vec2 texUV_corrected = vec2(texU, texV + northShift);  // Add to shift overlay north

    // Calculate grid cell size in degrees
    float cellSizeLon = (maxLon - minLon) / texSize.x;
    float cellSizeLat = (maxLat - minLat) / texSize.y;

    // IDW interpolation: sample nearby grid cells
    // Use fixed loop bounds for HLSL compatibility (max radius = 3, so 7x7 = 49 samples)
    float weightSum = 0.0;
    float valueSum = 0.0;
    int validSamples = 0;
    int totalSamplesInRadius = 0;  // Track expected samples for coverage calculation

    int radius = int(sampleRadius);
    vec2 currentPos = vec2(lat, lon);

    // Fixed loop bounds for shader compiler compatibility
    for (int dy = -3; dy <= 3; dy++) {
        for (int dx = -3; dx <= 3; dx++) {
            // Skip samples outside the requested radius
            if (abs(dx) > radius || abs(dy) > radius) {
                continue;
            }

            // Offset in grid space (for distance calculation)
            vec2 gridOffset = vec2(float(dx), float(dy)) * texelSize;
            vec2 sampleUV_geo = vec2(texU, texV) + gridOffset;  // For geographic calculations
            vec2 sampleUV_tex = texUV_corrected + gridOffset;    // For texture sampling

            // Skip if outside texture bounds
            if (sampleUV_geo.x < 0.0 || sampleUV_geo.x > 1.0 || sampleUV_geo.y < 0.0 || sampleUV_geo.y > 1.0) {
                continue;
            }

            // Count this as a potential sample location
            totalSamplesInRadius++;

            vec4 texSample = texture(dataTexture, sampleUV_tex);

            // Skip if no valid data at this cell
            if (texSample.a < 0.5) {
                continue;
            }

            // Calculate the geographic position of this sample (use uncorrected coords for accuracy)
            float sampleLon = minLon + sampleUV_geo.x * (maxLon - minLon);
            float sampleLat = maxLat - sampleUV_geo.y * (maxLat - minLat);
            vec2 samplePos = vec2(sampleLat, sampleLon);

            // Calculate distance
            float dist = geoDistance(currentPos, samplePos);

            // Avoid division by zero - if very close, use this value directly
            if (dist < 0.0001) {
                weightSum = 1.0;
                valueSum = texSample.r;
                validSamples = 1;
                totalSamplesInRadius = 1;  // Perfect hit = 100% coverage
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

    // Calculate coverage ratio for edge fade
    float coverage = float(validSamples) / float(max(totalSamplesInRadius, 1));

    // Calculate interpolated value
    float value = valueSum / weightSum;

    // Convert to color
    vec3 color = valueToColor(value);

    // Apply coverage-based fade at edges
    float alpha = qt_Opacity * coverage;

    // Use premultiplied alpha for correct Qt compositing
    fragColor = vec4(color * alpha, alpha);
}
