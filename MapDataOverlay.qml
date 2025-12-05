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

    // Viewport bounds in lat/lon coordinates
    property real topLeftLat: 85
    property real topLeftLon: -180
    property real bottomRightLat: -85
    property real bottomRightLon: 180

    // Number of active data points
    property int pointCount: 10

    // Power parameter for IDW (higher = sharper transitions near points)
    property real idwPower: 2.0

    // Data points as vec3(lat, lon, value)
    // Using individual properties because GLSL has limitations with dynamic arrays
    property vector3d point0: Qt.vector3d(0, 0, 0)
    property vector3d point1: Qt.vector3d(0, 0, 0)
    property vector3d point2: Qt.vector3d(0, 0, 0)
    property vector3d point3: Qt.vector3d(0, 0, 0)
    property vector3d point4: Qt.vector3d(0, 0, 0)
    property vector3d point5: Qt.vector3d(0, 0, 0)
    property vector3d point6: Qt.vector3d(0, 0, 0)
    property vector3d point7: Qt.vector3d(0, 0, 0)
    property vector3d point8: Qt.vector3d(0, 0, 0)
    property vector3d point9: Qt.vector3d(0, 0, 0)

    // Use precompiled shaders for Qt6
    // qt_add_shaders compiles these and embeds them in Qt resources
    vertexShader: "qrc:/shaders/overlay.vert.qsb"
    fragmentShader: "qrc:/shaders/overlay.frag.qsb"
}
