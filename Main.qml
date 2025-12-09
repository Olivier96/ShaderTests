import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: "Map Data Overlay - Shader Example"

    // Data model with 10 sample points
    // Each point has: latitude, longitude, and a value (0.0 - 1.0)
    // The value will be mapped to a color gradient
    ListModel {
        id: dataPointsModel

        // Major cities with sample data values
        ListElement { lat: 48.8566; lon: 2.3522; value: 0.9 }    // Paris - high
        ListElement { lat: 51.5074; lon: -0.1278; value: 0.7 }   // London
        ListElement { lat: 40.7128; lon: -74.0060; value: 0.85 } // New York
        ListElement { lat: 35.6762; lon: 139.6503; value: 0.6 }  // Tokyo
        ListElement { lat: -33.8688; lon: 151.2093; value: 0.4 } // Sydney
        ListElement { lat: 55.7558; lon: 37.6173; value: 0.3 }   // Moscow
        ListElement { lat: -22.9068; lon: -43.1729; value: 0.75 }// Rio de Janeiro
        ListElement { lat: 19.4326; lon: -99.1332; value: 0.5 }  // Mexico City
        ListElement { lat: 1.3521; lon: 103.8198; value: 0.65 }  // Singapore
        ListElement { lat: 28.6139; lon: 77.2090; value: 0.8 }   // New Delhi
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
                spacing: 20

                Label {
                    text: "Map Data Overlay Demo"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Overlay Opacity:"
                    color: "white"
                }

                Slider {
                    id: opacitySlider
                    from: 0
                    to: 1
                    value: 0.6
                    Layout.preferredWidth: 150
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
                    Layout.preferredWidth: 150
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

                // Update viewport and clamp on changes
                onCenterChanged: {
                    Qt.callLater(updateViewport)
                }
                onZoomLevelChanged: {
                    // Force clamp zoom level
                    if (map.zoomLevel < 2.5) map.zoomLevel = 2.5
                    else if (map.zoomLevel > 18) map.zoomLevel = 18
                    Qt.callLater(updateViewport)
                    Qt.callLater(clampToWorldBounds)
                }
                onWidthChanged: {
                    // Bump minimum zoom slightly when window grows to prevent edge glitch
                    if (map.zoomLevel < 2.9) map.zoomLevel = 2.9
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

                // Visual markers for data points (for reference)
                MapItemView {
                    model: dataPointsModel
                    delegate: MapQuickItem {
                        coordinate: QtPositioning.coordinate(model.lat, model.lon)
                        anchorPoint.x: marker.width / 2
                        anchorPoint.y: marker.height / 2
                        sourceItem: Rectangle {
                            id: marker
                            width: 12
                            height: 12
                            radius: 6
                            color: Qt.hsla(0.7 - model.value * 0.7, 0.8, 0.5, 1.0)
                            border.color: "white"
                            border.width: 2
                        }
                    }
                }
            }

            // Shader overlay - calculate viewport from actual screen corners
            MapDataOverlay {
                id: overlay
                anchors.fill: parent
                visible: showOverlay.checked
                opacity: opacitySlider.value

                // Bind directly to map's viewport property (updated via signals)
                viewportBounds: map.currentViewport

                // IDW params as vec4 (pointCount, idwPower, unused, unused)
                idwParams: Qt.vector4d(dataPointsModel.count, powerSlider.value, 0, 0)

                // Pass data points as vec4 (lat, lon, value, unused)
                point0: Qt.vector4d(dataPointsModel.get(0).lat, dataPointsModel.get(0).lon, dataPointsModel.get(0).value, 0)
                point1: Qt.vector4d(dataPointsModel.get(1).lat, dataPointsModel.get(1).lon, dataPointsModel.get(1).value, 0)
                point2: Qt.vector4d(dataPointsModel.get(2).lat, dataPointsModel.get(2).lon, dataPointsModel.get(2).value, 0)
                point3: Qt.vector4d(dataPointsModel.get(3).lat, dataPointsModel.get(3).lon, dataPointsModel.get(3).value, 0)
                point4: Qt.vector4d(dataPointsModel.get(4).lat, dataPointsModel.get(4).lon, dataPointsModel.get(4).value, 0)
                point5: Qt.vector4d(dataPointsModel.get(5).lat, dataPointsModel.get(5).lon, dataPointsModel.get(5).value, 0)
                point6: Qt.vector4d(dataPointsModel.get(6).lat, dataPointsModel.get(6).lon, dataPointsModel.get(6).value, 0)
                point7: Qt.vector4d(dataPointsModel.get(7).lat, dataPointsModel.get(7).lon, dataPointsModel.get(7).value, 0)
                point8: Qt.vector4d(dataPointsModel.get(8).lat, dataPointsModel.get(8).lon, dataPointsModel.get(8).value, 0)
                point9: Qt.vector4d(dataPointsModel.get(9).lat, dataPointsModel.get(9).lon, dataPointsModel.get(9).value, 0)
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
                        text: "Viewport Info"
                        color: "white"
                        font.bold: true
                    }

                    Label {
                        text: "Zoom: " + map.zoomLevel.toFixed(2)
                        color: "white"
                        font.pixelSize: 12
                    }

                    Label {
                        text: "Center: " + map.center.latitude.toFixed(4) + ", " + map.center.longitude.toFixed(4)
                        color: "white"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#555"
                    }

                    Label {
                        text: "Color Scale"
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
                        Label { text: "0.0"; color: "white"; font.pixelSize: 10; width: 45 }
                        Label { text: "0.25"; color: "white"; font.pixelSize: 10; width: 45 }
                        Label { text: "0.5"; color: "white"; font.pixelSize: 10; width: 45 }
                        Label { text: "0.75"; color: "white"; font.pixelSize: 10; width: 45 }
                        Label { text: "1.0"; color: "white"; font.pixelSize: 10 }
                    }
                }
            }
        }
    }
}
