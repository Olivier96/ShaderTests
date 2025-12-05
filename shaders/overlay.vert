#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 qt_TexCoord0;

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
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
