import QtQuick

/**
 * MapDataOverlay - A shader-based overlay for visualizing geo-located data
 *
 * This component renders a smooth color gradient overlay based on climate data
 * using a hybrid approach:
 * - Data is stored efficiently in a texture (supports unlimited points)
 * - IDW interpolation samples nearby grid cells for smooth blending
 *
 * The result is a professional-looking heatmap visualization.
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

    // IDW parameters: (power, sampleRadius, unused, unused)
    // - power: IDW exponent (higher = sharper transitions, lower = smoother)
    // - sampleRadius: number of grid cells to sample in each direction
    property vector4d idwParams: Qt.vector4d(2.0, 3.0, 0, 0)

    // Texture size: (width, height, unused, unused) - needed for GLES compatibility
    property vector4d textureSize: Qt.vector4d(1, 1, 0, 0)

    // Data texture containing normalized climate values
    property var dataTexture: null

    // Use precompiled shaders for Qt6
    vertexShader: "qrc:/shaders/overlay.vert.qsb"
    fragmentShader: "qrc:/shaders/overlay.frag.qsb"
}
