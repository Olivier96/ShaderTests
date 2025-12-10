import QtQuick

/**
 * MapDataOverlay - A shader-based overlay for visualizing geo-located data
 *
 * This component renders a color gradient overlay based on climate data
 * loaded from a texture. The texture contains normalized values that are
 * mapped to a color gradient.
 *
 * The shader samples from the data texture and applies the color gradient
 * to visualize the data across the map.
 */
ShaderEffect {
    id: root

    // Enable proper alpha blending for transparency
    blending: true

    // Viewport bounds packed as vec4 for proper std140 alignment
    // (topLeftLat, topLeftLon, bottomRightLat, bottomRightLon)
    property vector4d viewportBounds: Qt.vector4d(85, -180, -85, 180)

    // Data bounds: (minLat, maxLat, minLon, maxLon)
    property vector4d dataBounds: Qt.vector4d(-90, 90, -180, 180)

    // Data texture containing normalized climate values
    property var dataTexture: null

    // Use precompiled shaders for Qt6
    vertexShader: "qrc:/shaders/overlay.vert.qsb"
    fragmentShader: "qrc:/shaders/overlay.frag.qsb"
}
