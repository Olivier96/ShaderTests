import QtQuick

/**
 * MapDataOverlay - A shader-based overlay for visualizing geo-located data
 *
 * This component renders a color gradient overlay based on data points
 * with latitude/longitude coordinates and associated values.
 *
 * The shader uses Inverse Distance Weighting (IDW) interpolation to
 * create smooth color transitions between data points.
 * The entire map is covered - points act as color anchors.
 */
ShaderEffect {
    id: root

    // Enable proper alpha blending for transparency
    blending: true

    // Viewport bounds packed as vec4 for proper std140 alignment
    // (topLeftLat, topLeftLon, bottomRightLat, bottomRightLon)
    property vector4d viewportBounds: Qt.vector4d(85, -180, -85, 180)

    // IDW parameters packed as vec4 for alignment
    // (pointCount as float, idwPower, unused, unused)
    property vector4d idwParams: Qt.vector4d(10, 2.0, 0, 0)

    // Data points as vec4(lat, lon, value, unused)
    property vector4d point0: Qt.vector4d(0, 0, 0, 0)
    property vector4d point1: Qt.vector4d(0, 0, 0, 0)
    property vector4d point2: Qt.vector4d(0, 0, 0, 0)
    property vector4d point3: Qt.vector4d(0, 0, 0, 0)
    property vector4d point4: Qt.vector4d(0, 0, 0, 0)
    property vector4d point5: Qt.vector4d(0, 0, 0, 0)
    property vector4d point6: Qt.vector4d(0, 0, 0, 0)
    property vector4d point7: Qt.vector4d(0, 0, 0, 0)
    property vector4d point8: Qt.vector4d(0, 0, 0, 0)
    property vector4d point9: Qt.vector4d(0, 0, 0, 0)

    // Use precompiled shaders for Qt6
    vertexShader: "qrc:/shaders/overlay.vert.qsb"
    fragmentShader: "qrc:/shaders/overlay.frag.qsb"
}
