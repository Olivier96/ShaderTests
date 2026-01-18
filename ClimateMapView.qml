import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

/**
 * ClimateMapView - A reusable map component with shader-based data overlay
 *
 * This component can be embedded in any layout and provides:
 * - Interactive OSM map with pan/zoom
 * - Shader-based IDW interpolation overlay
 * - Click-to-query coordinate lookup
 * - Hover tooltips showing data values
 * - Info panel with data statistics
 * - Dropdown control bar for map settings
 *
 * Note: climateDataModel is accessed directly as a context property from C++
 */
Item {
    id: root

    // Control bar state
    property bool controlBarExpanded: false

    // Map overlay settings (directly controlled by internal UI now)
    property bool showOverlay: showOverlayCheck.checked
    property real overlayOpacity: opacitySlider.value
    property string activeColumn: climateDataModel ? climateDataModel.activeColumn : ""

    // Track texture version to force reload when data changes
    property int textureVersion: 0

    // Expose map for external control
    readonly property alias map: map

    // Bind column selector to model
    Binding {
        target: climateDataModel
        property: "activeColumn"
        value: columnSelector.currentText
        when: climateDataModel && columnSelector.currentText !== ""
    }

    Connections {
        target: climateDataModel
        function onDataChanged() {
            textureVersion++
        }
        function onActiveColumnChanged() {
            textureVersion++
        }
    }

    // Reverse geocoding model for coordinate lookup
    GeocodeModel {
        id: reverseGeocoder
        plugin: Plugin { name: "osm" }
        autoUpdate: false
        onLocationsChanged: {
            if (count > 0) {
                var addr = get(0).address
                var parts = []
                if (addr.city) parts.push(addr.city)
                else if (addr.county) parts.push(addr.county)
                if (addr.country) parts.push(addr.country)

                if (parts.length > 0) {
                    lookupLocationLabel.text = parts.join(", ")
                    lookupLocationLabel.color = "#88ccff"
                } else {
                    lookupLocationLabel.text = "Location name not found"
                    lookupLocationLabel.color = "#aaa"
                }
            } else {
                lookupLocationLabel.text = "Location name not found"
                lookupLocationLabel.color = "#aaa"
            }
        }
        onStatusChanged: {
            if (status === GeocodeModel.Error) {
                lookupLocationLabel.text = "Geocoding error"
                lookupLocationLabel.color = "#ff6666"
            }
        }
    }

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

        minimumZoomLevel: 2.5
        maximumZoomLevel: 18

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

        property vector4d currentViewport: Qt.vector4d(85, -180, -85, 180)

        function clampToWorldBounds() {
            var leftCoord = toCoordinate(Qt.point(0, height/2), false)
            var rightCoord = toCoordinate(Qt.point(width, height/2), false)

            if (!leftCoord.isValid || !rightCoord.isValid) return

            var halfWidthLon = Math.abs(rightCoord.longitude - leftCoord.longitude) / 2

            if (rightCoord.longitude < leftCoord.longitude) {
                halfWidthLon = (360 - Math.abs(rightCoord.longitude - leftCoord.longitude)) / 2
            }

            var newLon = center.longitude
            var needsUpdate = false

            if (halfWidthLon >= 180) {
                if (newLon !== 0) {
                    newLon = 0
                    needsUpdate = true
                }
            } else {
                var minLon = -180 + halfWidthLon
                var maxLon = 180 - halfWidthLon - 0.1

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

        property real dynamicMinZoom: 2.5 + Math.log2(width / 1200)

        onCenterChanged: Qt.callLater(updateViewport)
        onZoomLevelChanged: {
            if (map.zoomLevel < dynamicMinZoom) map.zoomLevel = dynamicMinZoom
            else if (map.zoomLevel > 18) map.zoomLevel = 18
            Qt.callLater(updateViewport)
            Qt.callLater(clampToWorldBounds)
        }
        onWidthChanged: {
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

        Component.onCompleted: {
            Qt.callLater(updateViewport)
            Qt.callLater(clampToWorldBounds)
        }

        // Map interaction handlers
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

        // Click handler - single tap to select point
        TapHandler {
            id: mapTap
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onSingleTapped: function(eventPoint) {
                var coord = map.toCoordinate(eventPoint.position, false)
                if (coord.isValid) {
                    map.selectedCoordinate = coord
                    map.hasSelectedPoint = true
                    infoColumn.updateFromMapClick(coord.latitude, coord.longitude)
                }
            }
            onDoubleTapped: function(eventPoint) {
                var coord = map.toCoordinate(eventPoint.position, false)
                if (coord.isValid && !zoomAnimation.running) {
                    // Smooth zoom in by 1 level, keeping the double-clicked point in place
                    map.zoomTargetCoord = coord
                    map.zoomTargetPoint = eventPoint.position
                    map.zoomTargetLevel = Math.min(map.zoomLevel + 1, 18)
                    zoomAnimation.start()
                }
            }
        }

        // Right-click to clear
        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                map.hasSelectedPoint = false
                map.selectedCoordinate = QtPositioning.coordinate(0, 0)
                lookupValueLabel.text = "Enter coordinates above"
                lookupValueLabel.color = "#aaa"
                lookupLocationLabel.text = ""
                latInput.text = ""
                lonInput.text = ""
            }
        }

        // Selected point marker
        MapQuickItem {
            id: selectedMarker
            visible: map.hasSelectedPoint
            coordinate: map.selectedCoordinate
            anchorPoint.x: markerItem.width / 2
            anchorPoint.y: markerItem.height

            sourceItem: Item {
                id: markerItem
                width: 32
                height: 42

                Rectangle {
                    x: 4; y: 4; width: 24; height: 24; radius: 12
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

                Rectangle {
                    id: pinHead
                    width: 24; height: 24; radius: 12
                    color: "#e74c3c"
                    border.width: 2
                    border.color: "#c0392b"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 10; radius: 5
                        color: "white"
                    }
                }

                Canvas {
                    id: pinPoint
                    x: 6; y: 20; width: 12; height: 16
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width, 0)
                        ctx.lineTo(width / 2, height)
                        ctx.closePath()
                        ctx.fillStyle = "#e74c3c"
                        ctx.fill()
                        ctx.strokeStyle = "#c0392b"
                        ctx.lineWidth = 2
                        ctx.stroke()
                    }
                }

                Rectangle {
                    id: pulseRing
                    anchors.centerIn: pinHead
                    width: 24; height: 24; radius: 12
                    color: "transparent"
                    border.width: 2
                    border.color: "#e74c3c"
                    opacity: 0

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: map.hasSelectedPoint
                        NumberAnimation { from: 0.8; to: 0; duration: 1500 }
                        PauseAnimation { duration: 500 }
                    }

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: map.hasSelectedPoint
                        NumberAnimation { from: 1; to: 2.5; duration: 1500 }
                        PauseAnimation { duration: 500 }
                    }
                }
            }
        }

        property bool hasSelectedPoint: false
        property geoCoordinate selectedCoordinate: QtPositioning.coordinate(0, 0)
        property geoCoordinate startCentroid

        // Double-tap zoom animation properties
        property geoCoordinate zoomTargetCoord
        property point zoomTargetPoint
        property real zoomTargetLevel

        NumberAnimation {
            id: zoomAnimation
            target: map
            property: "zoomLevel"
            to: map.zoomTargetLevel
            duration: 250
            easing.type: Easing.OutQuad
            onRunningChanged: {
                if (running) {
                    // Continuously align during animation
                    map.alignCoordinateToPoint(map.zoomTargetCoord, map.zoomTargetPoint)
                } else {
                    // Final alignment and bounds check when done
                    map.alignCoordinateToPoint(map.zoomTargetCoord, map.zoomTargetPoint)
                    map.clampToWorldBounds()
                }
            }
        }

        // Timer to keep aligning during zoom animation
        Timer {
            id: alignTimer
            interval: 16  // ~60fps
            repeat: true
            running: zoomAnimation.running
            onTriggered: {
                map.alignCoordinateToPoint(map.zoomTargetCoord, map.zoomTargetPoint)
            }
        }
    }

    // Hidden image that loads texture from the image provider
    Image {
        id: dataTextureImage
        visible: false
        cache: false
        source: climateDataModel && climateDataModel.pointCount > 0
            ? "image://climatedata/texture?v=" + textureVersion
            : ""
    }

    // Shader overlay
    MapDataOverlay {
        id: overlay
        anchors.fill: parent
        visible: root.showOverlay && climateDataModel && climateDataModel.pointCount > 0
        opacity: root.overlayOpacity

        viewportBounds: map.currentViewport

        dataBounds: climateDataModel ? Qt.vector4d(
            climateDataModel.shaderMinLat,
            climateDataModel.shaderMaxLat,
            climateDataModel.shaderMinLon,
            climateDataModel.shaderMaxLon
        ) : Qt.vector4d(-90, 90, -180, 180)

        idwPower: 2.0
        sampleRadius: 2.0

        texWidth: climateDataModel ? climateDataModel.textureWidth : 1
        texHeight: climateDataModel ? climateDataModel.textureHeight : 1

        dataTexture: dataTextureImage
    }

    // Info panel
    Rectangle {
        id: infoPanel
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 250
        height: infoColumn.height + 20
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: 8

        function containsPoint(pt) {
            var panelX = root.width - width - 10
            var panelY = root.height - height - 10
            return pt.x >= panelX && pt.x <= panelX + width &&
                   pt.y >= panelY && pt.y <= panelY + height
        }

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
                text: "Points: " + (climateDataModel ? climateDataModel.pointCount : 0)
                color: "white"
                font.pixelSize: 12
            }

            Label {
                text: "Column: " + (climateDataModel ? climateDataModel.activeColumn : "")
                color: "white"
                font.pixelSize: 12
            }

            Label {
                text: climateDataModel && climateDataModel.pointCount > 0 ?
                      "Grid: " + climateDataModel.gridResolution.toFixed(2) + "° (" +
                      climateDataModel.textureWidth + "x" + climateDataModel.textureHeight + ")" : ""
                color: "white"
                font.pixelSize: 12
                visible: climateDataModel && climateDataModel.pointCount > 0
            }

            Rectangle { width: parent.width; height: 1; color: "#555" }

            Label {
                text: "Color Scale (" + (climateDataModel ? climateDataModel.activeColumn : "") + ")"
                color: "white"
                font.bold: true
            }

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

            Row {
                spacing: 0
                Label {
                    text: climateDataModel ? climateDataModel.minValue.toFixed(1) : "0"
                    color: "white"
                    font.pixelSize: 10
                    width: 45
                }
                Item { width: 90; height: 1 }
                Label {
                    text: climateDataModel ? climateDataModel.maxValue.toFixed(1) : "0"
                    color: "white"
                    font.pixelSize: 10
                    width: 45
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#555" }

            Label {
                text: "Coordinate Lookup"
                color: "white"
                font.bold: true
            }

            Row {
                spacing: 5
                Label {
                    text: "Lat:"
                    color: "white"
                    font.pixelSize: 12
                    width: 30
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: latInput
                    width: 90
                    height: 28
                    placeholderText: "e.g. 41.9"
                    validator: DoubleValidator { bottom: -90; top: 90 }
                    selectByMouse: true
                    onAccepted: infoColumn.updateLookupValue()
                    background: Rectangle {
                        color: "#333"
                        border.color: latInput.focus ? "#4CAF50" : "#555"
                        radius: 3
                    }
                    color: "white"
                    font.pixelSize: 12
                }
            }

            Row {
                spacing: 5
                Label {
                    text: "Lon:"
                    color: "white"
                    font.pixelSize: 12
                    width: 30
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: lonInput
                    width: 90
                    height: 28
                    placeholderText: "e.g. 12.5"
                    validator: DoubleValidator { bottom: -180; top: 180 }
                    selectByMouse: true
                    onAccepted: infoColumn.updateLookupValue()
                    background: Rectangle {
                        color: "#333"
                        border.color: lonInput.focus ? "#4CAF50" : "#555"
                        radius: 3
                    }
                    color: "white"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 30
                color: "#2a2a2a"
                radius: 4
                visible: climateDataModel && climateDataModel.pointCount > 0

                Label {
                    id: lookupValueLabel
                    anchors.centerIn: parent
                    text: "Enter coordinates above"
                    color: "#aaa"
                    font.pixelSize: 12
                }
            }

            Label {
                id: lookupLocationLabel
                width: parent.width
                text: ""
                color: "#88ccff"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
            }

            function updateLookupValue() {
                lookupLocationLabel.text = ""

                if (latInput.text === "" || lonInput.text === "") {
                    lookupValueLabel.text = "Enter coordinates above"
                    lookupValueLabel.color = "#aaa"
                    map.hasSelectedPoint = false
                    return
                }

                var lat = parseFloat(latInput.text)
                var lon = parseFloat(lonInput.text)

                if (isNaN(lat) || isNaN(lon)) {
                    lookupValueLabel.text = "Invalid coordinates"
                    lookupValueLabel.color = "#ff6666"
                    map.hasSelectedPoint = false
                    return
                }

                if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                    lookupValueLabel.text = "Out of range"
                    lookupValueLabel.color = "#ff6666"
                    map.hasSelectedPoint = false
                    return
                }

                map.selectedCoordinate = QtPositioning.coordinate(lat, lon)
                map.hasSelectedPoint = true

                var value = climateDataModel.getValueAt(lat, lon)
                if (isNaN(value)) {
                    lookupValueLabel.text = "No data at this location"
                    lookupValueLabel.color = "#ffaa00"
                } else {
                    lookupValueLabel.text = climateDataModel.activeColumn + ": " + value.toFixed(2)
                    lookupValueLabel.color = "#4CAF50"
                }

                lookupLocationLabel.text = "Looking up location..."
                lookupLocationLabel.color = "#aaa"
                reverseGeocoder.query = QtPositioning.coordinate(lat, lon)
                reverseGeocoder.update()
            }

            function updateFromMapClick(lat, lon) {
                latInput.text = lat.toFixed(4)
                lonInput.text = lon.toFixed(4)

                lookupLocationLabel.text = ""

                var value = climateDataModel.getValueAt(lat, lon)
                if (isNaN(value)) {
                    lookupValueLabel.text = "No data at this location"
                    lookupValueLabel.color = "#ffaa00"
                } else {
                    lookupValueLabel.text = climateDataModel.activeColumn + ": " + value.toFixed(2)
                    lookupValueLabel.color = "#4CAF50"
                }

                lookupLocationLabel.text = "Looking up location..."
                lookupLocationLabel.color = "#aaa"
                reverseGeocoder.query = QtPositioning.coordinate(lat, lon)
                reverseGeocoder.update()
            }

            Rectangle { width: parent.width; height: 1; color: "#555" }

            Label {
                text: "Zoom: " + map.zoomLevel.toFixed(2)
                color: "white"
                font.pixelSize: 12
            }
        }
    }

    // Hover tracking
    property point lastHoverPos: Qt.point(0, 0)

    HoverHandler {
        id: mapHover
        onPointChanged: {
            if (hovered && climateDataModel && climateDataModel.pointCount > 0) {
                if (infoPanel.containsPoint(point.position)) {
                    dataTooltip.visible = false
                    hoverTimer.stop()
                    return
                }

                var dx = point.position.x - root.lastHoverPos.x
                var dy = point.position.y - root.lastHoverPos.y
                var moved = Math.sqrt(dx*dx + dy*dy) > 5

                if (moved) {
                    dataTooltip.visible = false
                    root.lastHoverPos = point.position
                    hoverTimer.restart()
                }
            }
        }
        onHoveredChanged: {
            if (!hovered) {
                hoverTimer.stop()
                dataTooltip.visible = false
            } else if (climateDataModel && climateDataModel.pointCount > 0) {
                root.lastHoverPos = point.position
                hoverTimer.restart()
            }
        }
    }

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

    Timer {
        id: hoverTimer
        interval: 150
        onTriggered: {
            if (mapHover.hovered && climateDataModel && climateDataModel.pointCount > 0) {
                if (infoPanel.containsPoint(mapHover.point.position)) {
                    return
                }
                var coord = map.toCoordinate(mapHover.point.position, false)
                if (coord.isValid) {
                    dataTooltip.updateData(coord.latitude, coord.longitude, mapHover.point.position)
                }
            }
        }
    }

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

            var tooltipX = screenPos.x + 15
            var tooltipY = screenPos.y + 15

            if (tooltipX + width > root.width) {
                tooltipX = screenPos.x - width - 10
            }
            if (tooltipY + height > root.height) {
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
                text: (climateDataModel ? climateDataModel.activeColumn : "") + ": " +
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

    // Dropdown control bar toggle button (top right)
    Rectangle {
        id: controlBarToggle
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        width: 36
        height: 36
        radius: 18
        color: toggleBtnMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(255, 255, 255, 0.1)
        border.width: 1
        z: 100

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Label {
            anchors.centerIn: parent
            text: controlBarExpanded ? "\u25B2" : "\u25BC"
            color: "white"
            font.pixelSize: 12
            opacity: 0.9
        }

        MouseArea {
            id: toggleBtnMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controlBarExpanded = !controlBarExpanded
        }

        ToolTip {
            visible: toggleBtnMouseArea.containsMouse
            text: controlBarExpanded ? "Hide controls" : "Show controls"
            delay: 500
        }
    }

    // Dropdown control bar - modern glassmorphism style
    Rectangle {
        id: controlBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: controlBarToggle.left
        anchors.rightMargin: 8
        anchors.topMargin: 12
        anchors.leftMargin: 12
        height: controlBarExpanded ? 56 : 0
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.5)
        border.color: Qt.rgba(255, 255, 255, 0.1)
        border.width: 1
        clip: true
        z: 99

        Behavior on height {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 20
            opacity: controlBarExpanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            // Column selector section
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Label {
                    text: "Column"
                    color: Qt.rgba(255, 255, 255, 0.6)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                ComboBox {
                    id: columnSelector
                    model: climateDataModel ? climateDataModel.availableColumns : []
                    implicitWidth: 130
                    implicitHeight: 32

                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.08)
                        border.color: columnSelector.hovered ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1
                        radius: 6
                    }

                    contentItem: Label {
                        text: columnSelector.displayText
                        color: "white"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        elide: Text.ElideRight
                    }

                    indicator: Label {
                        x: columnSelector.width - width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u25BC"
                        color: Qt.rgba(255, 255, 255, 0.5)
                        font.pixelSize: 8
                    }
                }
            }

            // Separator
            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Opacity section
            Row {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                Label {
                    text: "Opacity"
                    color: Qt.rgba(255, 255, 255, 0.6)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: opacitySlider
                    from: 0
                    to: 1
                    value: 0.4
                    implicitWidth: 100
                    implicitHeight: 20

                    background: Rectangle {
                        x: opacitySlider.leftPadding
                        y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                        width: opacitySlider.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(255, 255, 255, 0.1)

                        Rectangle {
                            width: opacitySlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#4fc3f7" }
                                GradientStop { position: 1.0; color: "#29b6f6" }
                            }
                        }
                    }

                    handle: Rectangle {
                        x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                        y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: opacitySlider.pressed ? "#fff" : "#f0f0f0"
                        border.color: Qt.rgba(0, 0, 0, 0.1)
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }
                    }
                }

                Rectangle {
                    width: 40
                    height: 24
                    radius: 4
                    color: Qt.rgba(255, 255, 255, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        anchors.centerIn: parent
                        text: Math.round(opacitySlider.value * 100) + "%"
                        color: "white"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Separator
            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.1)
                Layout.alignment: Qt.AlignVCenter
            }

            // Show overlay toggle
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                Switch {
                    id: showOverlayCheck
                    checked: true
                    implicitHeight: 24

                    indicator: Rectangle {
                        implicitWidth: 40
                        implicitHeight: 22
                        x: showOverlayCheck.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 11
                        color: showOverlayCheck.checked ? "#4fc3f7" : Qt.rgba(255, 255, 255, 0.15)
                        border.color: showOverlayCheck.checked ? "#29b6f6" : Qt.rgba(255, 255, 255, 0.1)
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Rectangle {
                            x: showOverlayCheck.checked ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: "white"

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                Label {
                    text: "Overlay"
                    color: Qt.rgba(255, 255, 255, 0.9)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
