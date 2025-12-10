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

                // Smoothing and IDW sliders temporarily disabled - dynamic uniform updates
                // cause shader to break on Windows/HLSL. Using hardcoded values for now.
                Slider {
                    id: smoothingSlider
                    visible: false
                    value: 2
                }
                Slider {
                    id: idwPowerSlider
                    visible: false
                    value: 2.0
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

                // IDW interpolation parameters - hardcoded to avoid shader update issues
                // TODO: Investigate why dynamic updates break the shader
                idwPower: 2.0
                sampleRadius: 2.0

                // Texture dimensions (for GLES compatibility)
                texWidth: climateDataModel.textureWidth
                texHeight: climateDataModel.textureHeight

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

            // Hover tracking for data tooltip
            property point lastHoverPos: Qt.point(0, 0)

            HoverHandler {
                id: mapHover
                onPointChanged: {
                    if (hovered && climateDataModel.pointCount > 0) {
                        // Check if mouse moved significantly (more than 5 pixels)
                        var dx = point.position.x - mapContainer.lastHoverPos.x
                        var dy = point.position.y - mapContainer.lastHoverPos.y
                        var moved = Math.sqrt(dx*dx + dy*dy) > 5

                        if (moved) {
                            // Significant movement - hide tooltip and restart timer
                            dataTooltip.visible = false
                            mapContainer.lastHoverPos = point.position
                            hoverTimer.restart()
                        }
                    }
                }
                onHoveredChanged: {
                    if (!hovered) {
                        hoverTimer.stop()
                        dataTooltip.visible = false
                    } else if (climateDataModel.pointCount > 0) {
                        // Just entered - start tracking
                        mapContainer.lastHoverPos = point.position
                        hoverTimer.restart()
                    }
                }
            }

            // Hide tooltip on zoom or size changes
            Connections {
                target: map
                function onZoomLevelChanged() {
                    dataTooltip.visible = false
                    hoverTimer.stop()
                }
                function onWidthChanged() {
                    dataTooltip.visible = false
                    hoverTimer.stop()
                }
                function onHeightChanged() {
                    dataTooltip.visible = false
                    hoverTimer.stop()
                }
            }

            // Debounce timer for hover queries
            Timer {
                id: hoverTimer
                interval: 150
                onTriggered: {
                    if (mapHover.hovered && climateDataModel.pointCount > 0) {
                        var coord = map.toCoordinate(mapHover.point.position, false)
                        if (coord.isValid) {
                            dataTooltip.updateData(coord.latitude, coord.longitude, mapHover.point.position)
                        }
                    }
                }
            }

            // Data tooltip
            Rectangle {
                id: dataTooltip
                visible: false
                width: tooltipContent.width + 16
                height: tooltipContent.height + 12
                color: Qt.rgba(0, 0, 0, 0.85)
                radius: 6
                border.color: "#555"
                border.width: 1

                property real hoveredLat: 0
                property real hoveredLon: 0
                property real hoveredValue: 0
                property bool hasData: false

                function updateData(lat, lon, screenPos) {
                    hoveredLat = lat
                    hoveredLon = lon
                    hasData = climateDataModel.hasDataAt(lat, lon)
                    if (hasData) {
                        hoveredValue = climateDataModel.getValueAt(lat, lon)
                    }

                    // Position tooltip near cursor but keep on screen
                    var tooltipX = screenPos.x + 15
                    var tooltipY = screenPos.y + 15

                    // Keep tooltip within bounds
                    if (tooltipX + width > mapContainer.width) {
                        tooltipX = screenPos.x - width - 10
                    }
                    if (tooltipY + height > mapContainer.height) {
                        tooltipY = screenPos.y - height - 10
                    }

                    x = tooltipX
                    y = tooltipY
                    visible = true
                }

                Column {
                    id: tooltipContent
                    anchors.centerIn: parent
                    spacing: 4

                    Label {
                        text: "Lat: " + dataTooltip.hoveredLat.toFixed(4) + "°"
                        color: "white"
                        font.pixelSize: 12
                    }

                    Label {
                        text: "Lon: " + dataTooltip.hoveredLon.toFixed(4) + "°"
                        color: "white"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#555"
                        visible: dataTooltip.hasData
                    }

                    Label {
                        visible: dataTooltip.hasData
                        text: climateDataModel.activeColumn + ": " +
                              (isNaN(dataTooltip.hoveredValue) ? "N/A" : dataTooltip.hoveredValue.toFixed(2))
                        color: "#4fc3f7"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Label {
                        visible: !dataTooltip.hasData
                        text: "No data"
                        color: "#888"
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }
        }
    }
}
