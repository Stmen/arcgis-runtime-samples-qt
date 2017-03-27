// [WriteFile Name=SrviceArea, Category=Routing]
// [Legal]
// Copyright 2017 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// [Legal]

import QtQuick 2.6
import QtQuick.Controls 1.4
import QtQuick.Dialogs 1.2
import Esri.ArcGISRuntime 100.1
import Esri.ArcGISExtras 1.1

Rectangle {
    id: rootRectangle
    clip: true

    width: 800
    height: 600

    property double scaleFactor: System.displayScaleFactor
    property bool busy: false
    property string message: ""
    property var barrierBuilder: null
    property var facilityParams: null

    // add a mapView component
    MapView {
        id: mapView
        anchors.fill: parent

        Map {
            BasemapStreets {}

            // set the initial viewpoint to San Francisco
            initialViewpoint: ViewpointCenter {
                Point {
                    x: -13630000.0
                    y: 4547000.0
                    spatialReference: SpatialReference.createWebMercator()
                }
                targetScale: 80000
            }

            onLoadStatusChanged: {
                task.load();
            }
        }

        GraphicsOverlay {
            id: areasOverlay
            opacity: 0.5

            renderer: SimpleRenderer {
                symbol: SimpleFillSymbol {
                    style: "SimpleFillSymbolStyleSolid"
                    color: "green"
                    outline: lineSymbol
                }
            }
        }

        GraphicsOverlay {
            id: facilitiesOverlay

            renderer: SimpleRenderer {
                symbol: PictureMarkerSymbol {
                    url: "http://static.arcgis.com/images/Symbols/SafetyHealth/Hospital.png"
                    height: 30
                    width: 30
                }
            }
        }

        GraphicsOverlay {
            id: barriersOverlay

            renderer: SimpleRenderer {
                symbol: SimpleLineSymbol {
                    id: lineSymbol
                    style: "SimpleLineSymbolStyleSolid"
                    color: "black"
                    width: 3.0
                }
            }
        }

        onMouseClicked: {
            if (busy === true)
                return;

            if (facilitiesButton.checked) {
                var facilityGraphic = ArcGISRuntimeEnvironment.createObject(
                    "Graphic", {geometry: mouse.mapPoint});
                facilitiesOverlay.graphics.append(facilityGraphic);
            }
            else if (barrierButton.checked) {
                handleBarrierPoint(mouse.mapPoint);
            }
        }
    }

    ServiceAreaTask {
        id: task
        url: "http://ragss12512:6080/arcgis/rest/services/NA/SanFrancisco_GPNAS/NAServer/Service%20Area"

        onLoadStatusChanged: {
            if (loadStatus !== Enums.LoadStatusLoaded)
                return;

            setupRouting();
        }

        onCreateDefaultParametersStatusChanged: {
            if (createDefaultParametersStatus !== Enums.TaskStatusCompleted)
                return;

            busy = false;
            facilityParams = createDefaultParametersResult;
            facilityParams.outputSpatialReference = SpatialReference.createWebMercator();
            facilityParams.returnPolygonBarriers = true;
            facilityParams.polygonDetail = Enums.ServiceAreaPolygonDetailHigh;
        }

        onSolveServiceAreaStatusChanged: {
            if (solveServiceAreaStatus !== Enums.TaskStatusCompleted)
                return;

            busy = false;

            if (solveServiceAreaResult === null || solveServiceAreaResult.error)
                message = "No service Areas calculated!";

            var numFacilities = facilitiesOverlay.graphics.rowCount();
            for (var i = 0; i < numFacilities; i++) {
                var results = solveServiceAreaResult.resultPolygons(i);
                for (var j = 0; j < results.length; j++) {
                    var resultGeometry = results[j].geometry;
                    var resultGraphic = ArcGISRuntimeEnvironment.createObject(
                        "Graphic", {geometry: resultGeometry});
                    areasOverlay.graphics.append(resultGraphic);
                }
            }
        }
    }

    Column {
        anchors {
            fill: parent
            margins: 8 * scaleFactor
        }
        spacing: 16 * scaleFactor

        ExclusiveGroup {
            id: modeGroup
        }

        Button {
            id: facilitiesButton
            text: "Facility"
            checkable: true
            enabled: !busy
            exclusiveGroup: modeGroup
            width: serviceAreasButton.width
            iconSource: "qrc:/Samples/Routing/ServiceArea/ic_menu_addencircled_light.png"
        }

        Button {
            id: barrierButton
            text: "Barrier"
            checkable: true
            enabled: !busy
            exclusiveGroup: modeGroup
            width: serviceAreasButton.width
            iconSource: "qrc:/Samples/Routing/ServiceArea/ic_menu_addencircled_light.png"

            onClicked: {
                if (barrierBuilder === null)
                    createBarrierBuilder();
            }
        }

        Button {
            id: newBarrierButton
            text: "new barrier"
            anchors.right: barrierButton.right
            enabled: barrierButton.checked

            onClicked: {
                barrierBuilder = null;
                createBarrierBuilder();
                addBarrierGraphic();
            }
        }

        Button {
            id: serviceAreasButton
            text: "Service Area"
            checkable: true
            enabled: !busy
            exclusiveGroup: modeGroup
            iconSource: "qrc:/Samples/Routing/ServiceArea/ic_menu_find_light.png"

            onClicked: startSolveTask();
        }

        Button {
            text: "Reset"
            width: serviceAreasButton.width
            enabled: !busy
            iconSource: "qrc:/Samples/Routing/ServiceArea/ic_menu_closeclear_light.png"
            onClicked: {
                facilitiesButton.checked = false;
                barrierButton.checked = false;
                serviceAreasButton.checked = false;

                facilitiesOverlay.graphics.clear();
                barriersOverlay.graphics.clear();
                areasOverlay.graphics.clear();
                barrierBuilder = null;
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: busy
    }

    MessageDialog {
        id: messageDialog
        title: "Route Error"
        text: message
        visible: text.length > 0
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border {
            width: 0.5 * scaleFactor
            color: "black"
        }
    }

    function setupRouting() {
        busy = true;
        message = "";
        task.createDefaultParameters();
    }

    function createBarrierBuilder() {
        barrierBuilder = ArcGISRuntimeEnvironment.createObject(
            "PolylineBuilder", {spatialReference: SpatialReference.createWebMercator()})
    }

    function handleBarrierPoint(mapPoint) {
        barrierBuilder.addPoint(mapPoint);
        // update the geometry for the current barrier - or create 1 if it does not exist
        var barriersCount = barriersOverlay.graphics.rowCount();
        if (barriersCount > 0)
            barriersOverlay.graphics.get(barriersCount-1).geometry = barrierBuilder.geometry
        else
            addBarrierGraphic();
    }

    function addBarrierGraphic() {
        var barrierGraphic = ArcGISRuntimeEnvironment.createObject(
            "Graphic", {geometry: barrierBuilder.geometry});
        barriersOverlay.graphics.append(barrierGraphic);
    }

    function startSolveTask() {
        facilityParams.clearFacilities();
        facilityParams.clearPolylineBarriers();

        if (facilitiesOverlay.graphics.rowCount() === 0) {
            message = "At least 1 Facility is required.";
            return;
        }

        busy = true;

        var facilities = [];
        facilitiesOverlay.graphics.forEach(function(graphic) {
            var facility = ArcGISRuntimeEnvironment.createObject(
                "ServiceAreaFacility", {geometry: graphic.geometry});
            facilities.push(facility);
        });

        facilityParams.setFacilities(facilities);

        var barriers = [];
        barriersOverlay.graphics.forEach(function(graphic) {
            var barrier = ArcGISRuntimeEnvironment.createObject(
                "PolylineBarrier", {geometry: graphic.geometry});
            barriers.push(barrier);
        });

        if (barriers.length > 0)
            facilityParams.setPolylineBarriers(barriers);

        task.solveServiceArea(facilityParams);
    }
}
