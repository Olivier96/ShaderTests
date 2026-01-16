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

    // File dialog for selecting SQLite database
    FileDialog {
        id: fileDialog
        title: "Select Climate Database"
        nameFilters: ["SQLite databases (*.sqlite *.db)", "All files (*)"]
        onAccepted: {
            climateDataModel.databasePath = selectedFile
        }
    }

    // Bind column selector to model
    Binding {
        target: climateDataModel
        property: "activeColumn"
        value: columnSelector.currentText
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top control bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#2c3e50"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 15

                Label {
                    text: "Climate Data Visualization"
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
                    value: 0.4
                    Layout.preferredWidth: 80
                }

                CheckBox {
                    id: showOverlay
                    text: "Show Overlay"
                    checked: true
                    palette.windowText: "white"
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
                showOverlay: showOverlay.checked
                overlayOpacity: opacitySlider.value
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
