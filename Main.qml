import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtLocation
import QtPositioning

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: "Map Data Overlay - Climate Data Visualization"

    // climateDataModel is exposed from C++ via context property

    // Track texture version to force reload when data changes
    property int textureVersion: 0

    Connections {
        target: climateDataModel
        function onDataChanged() {
            textureVersion++
        }
        function onActiveColumnChanged() {
            textureVersion++
        }
    }

    // Bind column selector to model
    Binding {
        target: climateDataModel
        property: "activeColumn"
        value: columnSelector.currentText
    }

    // File dialog for selecting SQLite database
    FileDialog {
        id: fileDialog
        title: "Select Climate Database"
        nameFilters: ["SQLite databases (*.sqlite *.db)", "All files (*)"]
        onAccepted: {
            climateDataModel.databasePath = selectedFile
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Control panel
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#2c3e50"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15

                Label {
                    text: "Climate Data Overlay"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Button {
                    text: "Load Database"
                    onClicked: fileDialog.open()
                }

                Label {
                    text: "Column:"
                    color: "white"
                }

                ComboBox {
                    id: columnSelector
                    model: climateDataModel.availableColumns
                    Layout.preferredWidth: 120
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Opacity:"
                    color: "white"
                }

                Slider {
                    id: opacitySlider
                    from: 0
                    to: 1
                    value: 0.6
                    Layout.preferredWidth: 80
                }

                Label {
                    text: "Smoothing:"
                    color: "white"
                }

                Slider {
                    id: smoothingSlider
                    from: 1
                    to: 5
                    value: 3
                    stepSize: 1
                    Layout.preferredWidth: 80
                    ToolTip.visible: hovered
                    ToolTip.text: "Sample radius: " + value.toFixed(0) + " cells"
                }

                Label {
                    text: "IDW:"
                    color: "white"
                }

                Slider {
                    id: idwPowerSlider
                    from: 0.5
                    to: 4.0
                    value: 2.0
                    Layout.preferredWidth: 80
                    ToolTip.visible: hovered
                    ToolTip.text: "IDW power: " + value.toFixed(1)
                }

                CheckBox {
                    id: showOverlay
                    text: "Show Overlay"
                    checked: true
                    palette.windowText: "white"
                }
            }
        }

        // Map container
        Item {
            id: mapContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            Map {
                id: map
                anchors.fill: parent

                plugin: Plugin {
                    name: "osm"
                    PluginParameter {
                        name: "osm.mapping.providersrepository.disabled"
                        value: "true"
                    }
                    PluginParameter {
                        name: "osm.mapping.providersrepository.address"
                        value: ""
                    }
                }

                center: QtPositioning.coordinate(30, 0)
                zoomLevel: 3

                // Prevent extreme zoom out
                minimumZoomLevel: 2.5
                maximumZoomLevel: 18

                // Helper function to calculate viewport bounds using visibleRegion
                function updateViewport() {
                    var rect = visibleRegion.boundingGeoRectangle()
                    if (rect.isValid) {
                        currentViewport = Qt.vector4d(
                            rect.topLeft.latitude,
                            rect.topLeft.longitude,
                            rect.bottomRight.latitude,
                            rect.bottomRight.longitude
                        )
                    }
                }

                // Property that holds the current viewport bounds
                property vector4d currentViewport: Qt.vector4d(85, -180, -85, 180)

                // Function to clamp map so edges don't go past world bounds (longitude only)
                function clampToWorldBounds() {
                    // Get coordinates at screen edges
                    var leftCoord = toCoordinate(Qt.point(0, height/2), false)
                    var rightCoord = toCoordinate(Qt.point(width, height/2), false)

                    if (!leftCoord.isValid || !rightCoord.isValid) return

                    // Calculate the half-width of viewport in degrees
                    var halfWidthLon = Math.abs(rightCoord.longitude - leftCoord.longitude) / 2

                    // Handle case where we cross the antimeridian (right < left means wrapping)
                    if (rightCoord.longitude < leftCoord.longitude) {
                        halfWidthLon = (360 - Math.abs(rightCoord.longitude - leftCoord.longitude)) / 2
                    }

                    var newLon = center.longitude
                    var needsUpdate = false

                    // If viewport is wider than world, center horizontally
                    if (halfWidthLon >= 180) {
                        if (newLon !== 0) {
                            newLon = 0
                            needsUpdate = true
                        }
                    } else {
                        // Calculate allowed center range so edges stay within bounds
                        var minLon = -180 + halfWidthLon
                        var maxLon = 180 - halfWidthLon - 0.1  // Small offset to fix right edge glitch

                        // Clamp longitude
                        if (newLon < minLon) {
                            newLon = minLon
                            needsUpdate = true
                        } else if (newLon > maxLon) {
                            newLon = maxLon
                            needsUpdate = true
                        }
                    }

                    if (needsUpdate) {
                        center = QtPositioning.coordinate(center.latitude, newLon)
                    }
                }

                // Dynamic minimum zoom based on window width (1200px = 2.5 baseline)
                property real dynamicMinZoom: 2.5 + Math.log2(width / 1200)

                // Update viewport and clamp on changes
                onCenterChanged: {
                    Qt.callLater(updateViewport)
                }
                onZoomLevelChanged: {
                    // Force clamp zoom level using dynamic minimum
                    if (map.zoomLevel < dynamicMinZoom) map.zoomLevel = dynamicMinZoom
                    else if (map.zoomLevel > 18) map.zoomLevel = 18
                    Qt.callLater(updateViewport)
                    Qt.callLater(clampToWorldBounds)
                }
                onWidthChanged: {
                    // Enforce dynamic minimum zoom when window width changes
                    if (map.zoomLevel < dynamicMinZoom) map.zoomLevel = dynamicMinZoom
                    Qt.callLater(updateViewport)
                    Qt.callLater(clampToWorldBounds)
                }
                onHeightChanged: {
                    Qt.callLater(updateViewport)
                    Qt.callLater(clampToWorldBounds)
                }
                onBearingChanged: Qt.callLater(updateViewport)
                onVisibleRegionChanged: Qt.callLater(updateViewport)

                // Initial update after component is ready
                Component.onCompleted: {
                    Qt.callLater(updateViewport)
                    Qt.callLater(clampToWorldBounds)
                }

                // Enable map interaction
                PinchHandler {
                    id: pinch
                    target: null
                    onActiveChanged: if (active) {
                        map.startCentroid = map.toCoordinate(pinch.centroid.position, false)
                    }
                    onScaleChanged: (delta) => {
                        map.zoomLevel = Math.max(2.5, Math.min(18, map.zoomLevel + Math.log2(delta)))
                        map.alignCoordinateToPoint(map.startCentroid, pinch.centroid.position)
                        map.clampToWorldBounds()
                    }
                    onRotationChanged: (delta) => {
                        map.bearing -= delta
                        map.alignCoordinateToPoint(map.startCentroid, pinch.centroid.position)
                    }
                    grabPermissions: PointerHandler.TakeOverForbidden
                }

                WheelHandler {
                    id: wheel
                    acceptedDevices: Qt.platform.pluginName === "cocoa" || Qt.platform.pluginName === "wayland"
                                     ? PointerDevice.Mouse | PointerDevice.TouchPad
                                     : PointerDevice.Mouse
                    rotationScale: 1/120
                    property: "zoomLevel"
                    onActiveChanged: if (!active) map.clampToWorldBounds()
                }

                DragHandler {
                    id: drag
                    target: null
                    onTranslationChanged: (delta) => {
                        map.pan(-delta.x, -delta.y)
                        map.clampToWorldBounds()
                    }
                }

                property geoCoordinate startCentroid
            }

            // Hidden image that loads texture from the image provider
            Image {
                id: dataTextureImage
                visible: false
                cache: false
                // The version parameter forces reload when data changes
                source: climateDataModel.pointCount > 0
                    ? "image://climatedata/texture?v=" + textureVersion
                    : ""
            }

            // Shader overlay
            MapDataOverlay {
                id: overlay
                anchors.fill: parent
                visible: showOverlay.checked && climateDataModel.pointCount > 0
                opacity: opacitySlider.value

                // Bind directly to map's viewport property
                viewportBounds: map.currentViewport

                // Data bounds from the model
                dataBounds: Qt.vector4d(
                    climateDataModel.minLat,
                    climateDataModel.maxLat,
                    climateDataModel.minLon,
                    climateDataModel.maxLon
                )

                // IDW interpolation parameters (power, sampleRadius, unused, unused)
                idwParams: Qt.vector4d(idwPowerSlider.value, smoothingSlider.value, 0, 0)

                // Texture dimensions (for GLES compatibility)
                textureSize: Qt.vector4d(climateDataModel.textureWidth, climateDataModel.textureHeight, 0, 0)

                // Use the loaded texture
                dataTexture: dataTextureImage
            }

            // Info panel
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: 250
                height: infoColumn.height + 20
                color: Qt.rgba(0, 0, 0, 0.7)
                radius: 8

                Column {
                    id: infoColumn
                    anchors.centerIn: parent
                    width: parent.width - 20
                    spacing: 5

                    Label {
                        text: "Climate Data Info"
                        color: "white"
                        font.bold: true
                    }

                    Label {
                        text: "Points: " + climateDataModel.pointCount
                        color: "white"
                        font.pixelSize: 12
                    }

                    Label {
                        text: "Column: " + climateDataModel.activeColumn
                        color: "white"
                        font.pixelSize: 12
                    }

                    Label {
                        text: "Grid: " + climateDataModel.gridResolution.toFixed(2) + "° (" +
                              climateDataModel.textureWidth + "x" + climateDataModel.textureHeight + ")"
                        color: "white"
                        font.pixelSize: 12
                        visible: climateDataModel.pointCount > 0
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#555"
                    }

                    Label {
                        text: "Color Scale (" + climateDataModel.activeColumn + ")"
                        color: "white"
                        font.bold: true
                    }

                    Row {
                        spacing: 5
                        Rectangle {
                            width: 180
                            height: 20
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#0000ff" }
                                GradientStop { position: 0.25; color: "#00ffff" }
                                GradientStop { position: 0.5; color: "#00ff00" }
                                GradientStop { position: 0.75; color: "#ffff00" }
                                GradientStop { position: 1.0; color: "#ff0000" }
                            }
                        }
                    }

                    Row {
                        spacing: 0
                        Label {
                            text: climateDataModel.minValue.toFixed(1)
                            color: "white"
                            font.pixelSize: 10
                            width: 45
                        }
                        Item { width: 90; height: 1 }
                        Label {
                            text: climateDataModel.maxValue.toFixed(1)
                            color: "white"
                            font.pixelSize: 10
                            width: 45
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#555"
                    }

                    Label {
                        text: "Zoom: " + map.zoomLevel.toFixed(2)
                        color: "white"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
