#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // All custom uniforms as vec4 for proper std140 alignment
    vec4 viewportBounds;  // (topLeftLat, topLeftLon, bottomRightLat, bottomRightLon)
    vec4 idwParams;       // (pointCount, idwPower, unused, unused)
    vec4 point0;
    vec4 point1;
    vec4 point2;
    vec4 point3;
    vec4 point4;
    vec4 point5;
    vec4 point6;
    vec4 point7;
    vec4 point8;
    vec4 point9;
};

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

// Calculate geographic distance with latitude correction
float geoDistance(vec2 p1, vec2 p2) {
    float dLat = p2.x - p1.x;
    float dLon = p2.y - p1.y;

    float avgLat = (p1.x + p2.x) * 0.5;
    float lonScale = cos(radians(avgLat));

    return sqrt(dLat * dLat + (dLon * lonScale) * (dLon * lonScale));
}

// Get point data by index (returns vec3: lat, lon, value)
vec3 getPoint(int idx) {
    if (idx == 0) return point0.xyz;
    if (idx == 1) return point1.xyz;
    if (idx == 2) return point2.xyz;
    if (idx == 3) return point3.xyz;
    if (idx == 4) return point4.xyz;
    if (idx == 5) return point5.xyz;
    if (idx == 6) return point6.xyz;
    if (idx == 7) return point7.xyz;
    if (idx == 8) return point8.xyz;
    if (idx == 9) return point9.xyz;
    return vec3(0.0);
}

void main() {
    // Extract viewport bounds
    float topLeftLat = viewportBounds.x;
    float topLeftLon = viewportBounds.y;
    float bottomRightLat = viewportBounds.z;
    float bottomRightLon = viewportBounds.w;

    // Extract IDW parameters
    int pointCount = int(idwParams.x);
    float idwPower = idwParams.y;

    // Convert texture coordinates to lat/lon
    float lat = mix(topLeftLat, bottomRightLat, qt_TexCoord0.y);
    float lon = mix(topLeftLon, bottomRightLon, qt_TexCoord0.x);
    vec2 currentPos = vec2(lat, lon);

    // Inverse Distance Weighting interpolation
    float weightSum = 0.0;
    float valueSum = 0.0;

    for (int i = 0; i < 10; i++) {
        if (i >= pointCount) break;

        vec3 point = getPoint(i);
        vec2 pointPos = point.xy;
        float pointValue = point.z;

        float dist = geoDistance(currentPos, pointPos);

        if (dist < 0.001) {
            weightSum = 1.0;
            valueSum = pointValue;
            break;
        }

        float weight = 1.0 / pow(dist, idwPower);
        weightSum += weight;
        valueSum += weight * pointValue;
    }

    // Calculate interpolated value
    float value = (weightSum > 0.0) ? (valueSum / weightSum) : 0.5;

    vec3 color = valueToColor(value);
    fragColor = vec4(color, qt_Opacity);
}
