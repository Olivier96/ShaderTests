#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Viewport bounds - must match QML property order exactly
    float topLeftLat;
    float topLeftLon;
    float bottomRightLat;
    float bottomRightLon;

    // IDW parameters
    int pointCount;
    float idwPower;

    // Data points - vec4 for std140 alignment (vector3d maps to vec4)
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

void main() {
    // DEBUG: Output color based on what data we're receiving
    // Red channel: topLeftLat normalized (expect ~80 at top -> 0.8)
    // Green channel: point0.z (first point's value, expect 0.9 for Paris)
    // Blue channel: pointCount / 10.0 (expect 1.0 for 10 points)

    float r = abs(topLeftLat) / 100.0;  // Latitude ranges roughly -90 to 90
    float g = point0.z;                  // Value should be 0.9
    float b = float(pointCount) / 10.0;  // Should be 1.0 for 10 points

    fragColor = vec4(r, g, b, qt_Opacity);
}
