import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    width: 1400
    height: 900
    visible: true
    title: "Climate Data Visualization"

    // climateDataModel is exposed from C++ via context property

    // Sidebar state
    property bool sidebarExpanded: true
    property int sidebarExpandedWidth: 200
    property int sidebarCollapsedWidth: 50

    // File dialog for selecting SQLite database
    FileDialog {
        id: fileDialog
        title: "Select Climate Database"
        nameFilters: ["SQLite databases (*.sqlite *.db)", "All files (*)"]
        onAccepted: {
            climateDataModel.databasePath = selectedFile
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Collapsible Sidebar
        Rectangle {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: sidebarExpanded ? sidebarExpandedWidth : sidebarCollapsedWidth
            color: "#1a1a2e"

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Sidebar header with toggle button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#16213e"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Label {
                            text: "Menu"
                            color: "white"
                            font.pixelSize: 16
                            font.bold: true
                            visible: sidebarExpanded
                            Layout.fillWidth: true
                        }

                        // Toggle button
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 4
                            color: toggleMouseArea.containsMouse ? "#2a2a4e" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: sidebarExpanded ? "\u2039" : "\u203A"  // ‹ or ›
                                color: "white"
                                font.pixelSize: 20
                            }

                            MouseArea {
                                id: toggleMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sidebarExpanded = !sidebarExpanded
                            }
                        }
                    }
                }

                // Sidebar items
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2

                    model: ListModel {
                        ListElement { name: "Home"; icon: "\u2302"; action: "home" }
                        ListElement { name: "Import Data"; icon: "\u2913"; action: "import" }
                        ListElement { name: "Export Data"; icon: "\u2912"; action: "export" }
                        ListElement { name: "Layers"; icon: "\u2630"; action: "layers" }
                        ListElement { name: "Map Settings"; icon: "\u2699"; action: "mapSettings" }
                        ListElement { name: "Settings"; icon: "\u2699"; action: "settings" }
                        ListElement { name: "Help"; icon: "?"; action: "help" }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 44
                        color: itemMouseArea.containsMouse ? "#2a2a4e" : "transparent"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // Icon
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: "#0f3460"

                                Label {
                                    anchors.centerIn: parent
                                    text: model.icon
                                    color: "#4fc3f7"
                                    font.pixelSize: 14
                                }
                            }

                            // Label (only visible when expanded)
                            Label {
                                text: model.name
                                color: "white"
                                font.pixelSize: 14
                                visible: sidebarExpanded
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (model.action === "import") {
                                    fileDialog.open()
                                }
                                // Other actions can be added here
                            }
                        }

                        // Tooltip when collapsed
                        ToolTip {
                            visible: itemMouseArea.containsMouse && !sidebarExpanded
                            text: model.name
                            delay: 500
                        }
                    }
                }

                // Sidebar footer - data status
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sidebarExpanded ? 60 : 50
                    color: "#0f3460"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Label {
                            text: sidebarExpanded ? "Data Status" : ""
                            color: "#888"
                            font.pixelSize: 10
                            visible: sidebarExpanded
                        }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: climateDataModel && climateDataModel.pointCount > 0 ? "#4CAF50" : "#ff5722"
                            }

                            Label {
                                text: climateDataModel && climateDataModel.pointCount > 0
                                      ? (sidebarExpanded ? climateDataModel.pointCount + " points" : "")
                                      : (sidebarExpanded ? "No data" : "")
                                color: "white"
                                font.pixelSize: 12
                                visible: sidebarExpanded
                            }
                        }
                    }
                }
            }
        }

        // Main content area with split view
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
                orientation: Qt.Horizontal

                // Left side: Climate Map
                ClimateMapView {
                    id: mapView
                    SplitView.preferredWidth: parent.width * 0.6
                    SplitView.minimumWidth: 400
                }

                // Right side: Content panel with tabs
                Rectangle {
                    SplitView.minimumWidth: 300
                    SplitView.preferredWidth: parent.width * 0.4
                    color: "#1a1a2e"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Tab bar
                        TabBar {
                            id: tabBar
                            Layout.fillWidth: true

                            TabButton {
                                text: "Graphs"
                                width: implicitWidth
                            }
                            TabButton {
                                text: "Data"
                                width: implicitWidth
                            }
                            TabButton {
                                text: "Summary"
                                width: implicitWidth
                            }
                        }

                        // Tab content
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: tabBar.currentIndex

                            // Graphs tab
                            Rectangle {
                                color: "#16213e"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15

                                    Label {
                                        text: "Data Visualization"
                                        color: "white"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }

                                    Label {
                                        text: "Graphs and charts will be displayed here."
                                        color: "#aaa"
                                        font.pixelSize: 14
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    // Placeholder for histogram
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 200
                                        color: "#0f3460"
                                        radius: 8

                                        Label {
                                            anchors.centerIn: parent
                                            text: "Histogram Placeholder"
                                            color: "#555"
                                            font.pixelSize: 16
                                        }
                                    }

                                    // Placeholder for line chart
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#0f3460"
                                        radius: 8

                                        Label {
                                            anchors.centerIn: parent
                                            text: "Time Series Chart Placeholder"
                                            color: "#555"
                                            font.pixelSize: 16
                                        }
                                    }
                                }
                            }

                            // Data tab
                            Rectangle {
                                color: "#16213e"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15

                                    Label {
                                        text: "Data Table"
                                        color: "white"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }

                                    Label {
                                        text: "Points loaded: " + (climateDataModel ? climateDataModel.pointCount : 0)
                                        color: "#aaa"
                                        font.pixelSize: 14
                                    }

                                    // Placeholder table header
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#0f3460"
                                        radius: 4

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            Label {
                                                text: "Latitude"
                                                color: "white"
                                                font.bold: true
                                                Layout.preferredWidth: 80
                                            }
                                            Label {
                                                text: "Longitude"
                                                color: "white"
                                                font.bold: true
                                                Layout.preferredWidth: 80
                                            }
                                            Label {
                                                text: "Value"
                                                color: "white"
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Placeholder for data list
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#0f3460"
                                        radius: 8

                                        Label {
                                            anchors.centerIn: parent
                                            text: "Data rows will appear here"
                                            color: "#555"
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }

                            // Summary tab
                            Rectangle {
                                color: "#16213e"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15

                                    Label {
                                        text: "Data Summary"
                                        color: "white"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }

                                    // Statistics grid
                                    GridLayout {
                                        columns: 2
                                        columnSpacing: 20
                                        rowSpacing: 10
                                        Layout.fillWidth: true

                                        Label { text: "Data Points:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel ? climateDataModel.pointCount.toString() : "0"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Label { text: "Active Column:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel ? climateDataModel.activeColumn : "-"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Label { text: "Min Value:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel && climateDataModel.pointCount > 0
                                                  ? climateDataModel.minValue.toFixed(2) : "-"
                                            color: "#4fc3f7"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Label { text: "Max Value:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel && climateDataModel.pointCount > 0
                                                  ? climateDataModel.maxValue.toFixed(2) : "-"
                                            color: "#ff7043"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Label { text: "Grid Resolution:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel && climateDataModel.pointCount > 0
                                                  ? climateDataModel.gridResolution.toFixed(2) + "°" : "-"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Label { text: "Texture Size:"; color: "#aaa"; font.pixelSize: 14 }
                                        Label {
                                            text: climateDataModel && climateDataModel.pointCount > 0
                                                  ? climateDataModel.textureWidth + " x " + climateDataModel.textureHeight : "-"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#333"
                                    }

                                    Label {
                                        text: "Available Columns"
                                        color: "white"
                                        font.pixelSize: 16
                                        font.bold: true
                                    }

                                    // List available columns
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: climateDataModel ? climateDataModel.availableColumns : []
                                            delegate: Rectangle {
                                                width: colLabel.width + 16
                                                height: 28
                                                radius: 14
                                                color: modelData === (climateDataModel ? climateDataModel.activeColumn : "")
                                                       ? "#4CAF50" : "#0f3460"

                                                Label {
                                                    id: colLabel
                                                    anchors.centerIn: parent
                                                    text: modelData
                                                    color: "white"
                                                    font.pixelSize: 12
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        columnSelector.currentIndex = index
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
