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

    // IDW power: higher = sharper transitions, lower = smoother
    property real idwPower: 2.0

    // Sample radius: number of grid cells to sample in each direction (1-3)
    property real sampleRadius: 2.0

    // Texture dimensions (width, height) - needed for GLES compatibility
    property real texWidth: 1.0
    property real texHeight: 1.0

    // Shader uniforms - explicitly updated when source properties change
    property vector4d idwParams: Qt.vector4d(2.0, 2.0, 0, 0)
    property vector4d textureSize: Qt.vector4d(1, 1, 0, 0)

    onIdwPowerChanged: updateIdwParams()
    onSampleRadiusChanged: updateIdwParams()
    onTexWidthChanged: updateTextureSize()
    onTexHeightChanged: updateTextureSize()

    function updateIdwParams() {
        // Ensure valid values to prevent shader issues
        var power = Math.max(0.1, idwPower)
        var radius = Math.max(1, Math.min(3, Math.round(sampleRadius)))
        idwParams = Qt.vector4d(power, radius, 0, 0)
    }

    function updateTextureSize() {
        // Ensure minimum texture size of 1 to prevent division by zero
        var w = Math.max(1, texWidth)
        var h = Math.max(1, texHeight)
        textureSize = Qt.vector4d(w, h, 0, 0)
    }

    Component.onCompleted: {
        updateIdwParams()
        updateTextureSize()
    }

    // Data texture containing normalized climate values
    property var dataTexture: null

    // Use precompiled shaders for Qt6
    vertexShader: "qrc:/shaders/overlay.vert.qsb"
    fragmentShader: "qrc:/shaders/overlay.frag.qsb"
}
