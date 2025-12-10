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

    // Climate data model - loads from SQLite
    ClimateDataModel {
        id: climateModel
        activeColumn: columnSelector.currentText
        onDataChanged: {
            console.log("Climate data updated: " + pointCount + " points, column: " + activeColumn)
        }
    }

    // File dialog for selecting SQLite database
    FileDialog {
        id: fileDialog
        title: "Select Climate Database"
        nameFilters: ["SQLite databases (*.sqlite *.db)", "All files (*)"]
        onAccepted: {
            climateModel.databasePath = selectedFile
        }
    }

    // Helper function to get point data (returns default if not loaded)
    function getClimatePoint(index) {
        if (climateModel.pointCount > index) {
            return climateModel.getPoint(index)
        }
        return Qt.vector4d(0, 0, 0, 0)
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
                    model: climateModel.availableColumns
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
                    Layout.preferredWidth: 100
                }

                Label {
                    text: "IDW Power:"
                    color: "white"
                }

                Slider {
                    id: powerSlider
                    from: 0.5
                    to: 4.0
                    value: 2.0
                    Layout.preferredWidth: 100
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

                // Note: Visual markers removed - climate data has too many points
                // The shader overlay provides the visualization
            }

            // Shader overlay - calculate viewport from actual screen corners
            MapDataOverlay {
                id: overlay
                anchors.fill: parent
                visible: showOverlay.checked && climateModel.pointCount > 0
                opacity: opacitySlider.value

                // Bind directly to map's viewport property (updated via signals)
                viewportBounds: map.currentViewport

                // IDW params as vec4 (pointCount, idwPower, unused, unused)
                idwParams: Qt.vector4d(Math.min(climateModel.pointCount, 10), powerSlider.value, 0, 0)

                // Pass data points as vec4 (lat, lon, value, unused)
                point0: getClimatePoint(0)
                point1: getClimatePoint(1)
                point2: getClimatePoint(2)
                point3: getClimatePoint(3)
                point4: getClimatePoint(4)
                point5: getClimatePoint(5)
                point6: getClimatePoint(6)
                point7: getClimatePoint(7)
                point8: getClimatePoint(8)
                point9: getClimatePoint(9)
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
                        text: "Points: " + climateModel.pointCount
                        color: "white"
                        font.pixelSize: 12
                    }

                    Label {
                        text: "Column: " + climateModel.activeColumn
                        color: "white"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#555"
                    }

                    Label {
                        text: "Color Scale (" + climateModel.activeColumn + ")"
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
                            text: climateModel.minValue.toFixed(1)
                            color: "white"
                            font.pixelSize: 10
                            width: 45
                        }
                        Item { width: 90; height: 1 }
                        Label {
                            text: climateModel.maxValue.toFixed(1)
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
