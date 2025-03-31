/* @preserve
 * HashGraph 1.0.0+master.49e1b16, a JS library for Hashgraph visual debugging
*/
// <script src="https://unpkg.com/konva@9/konva.min.js"></script>

export let hashgraphID = 0;

export class HashGraph {
    
    constructor(id, options) {
        this.options = {
            transport: "websocket",
            eventid: "node",
            path: "",
            scrollctl: undefined,
            opt: undefined
        };
        
        for (const i in options) {
            this.options[i] = options[i];
        }

        this._container_id = id;

        // from state
        
        this.eventKeyMap = {
            eventId: "id",
            fatherId: "father",
            motherId: "mother",
            nodeId: "node_id",
            witness: "strongly_seeing",
            famous: "famous",
            round: "round",
            roundNumber: "number",
            remove: "remove",
            isGrounded: "is_grounded",
            count: "count",
        };

        this.selectedNode = {};
        this.autoScroll = true;
        this.highlightEventId = null;
        this.markInsteadOfDelete = false;

        this.length = 0;
        this.incount = 0;
        this.paused = false;

        this.stats = {
            events: 0,
            nodes: 0,
            round: 0,
        };


        // from graph

        this.counterNodeSelection = 0;

        this.lookup = {};
        this.roundLookup = {};

        this.isConnected = false;
        this.highestPointY = 0;

        this.dragMode = false;

        this._initContainer(id);
        
        this._reset();
        this.layerMain.draw();

        this._initEvents();
    }
    
    _initContainer(id){
        const container = typeof id === 'string' ? document.getElementById(id) : id;

        if (!container) {
            throw new Error('Hashgraph container not found.');
        } else if (container._hashgraph_id) {
            throw new Error('Hashgraph container is already initialized.');
        }

        if (!('_hashgraph_id' in container )) {
            container['_hashgraph_id'] = ++hashgraphID;
        }

        this._container = container;

        this._containerID = container._hashgraph_id;

        if(container.clientWidth > container.clientHeight){
            container.style.height = container.clientWidth;
        }

        this.stage = new Konva.Stage({
            container: container,
            width: container.clientWidth,
            height: container.clientHeight,
        });
        console.log("Container init");
    }


    _initEvents(){
        let ws = new WebSocket(location.origin.replace(/^http/, 'ws') + this.options.path);

        ws.onerror = console.error;
        ws.onopen = () => {
            console.log("[ON] Graph Socket connected: ");
            ws.send("subscribe\0monitor");
        };
        ws.onclose = () => {
            console.log("[OFF] Graph Socket disconnected: ");
        };
        ws.onmessage = ( msg ) => {
            let a = msg.data.split("\0");
            let jd = JSON.parse(a[1]);
            if(a[0].startsWith("monitor")) {
               this.setEventNode(jd); 
            }
        };

        window.addEventListener("resize", (e) => {
            const container = this._container;
            e.preventDefault();
            if(container.clientWidth > container.clientHeight){
                container.style.height = container.clientWidth;
            }
            this.stage.width(container.clientWidth);
            this.stage.height(container.clientHeight);
        });
        
        this.stage.on("mousedown", (e) => {
            this.dragMode = true;
        });

        this.stage.on("mouseup", (e) => {
            this.dragMode = false;
        });

        this.stage.on("mousemove", (e) => {
            if (this.dragMode) {
                this.setAutoScroll(false);
                this.layerMain.x(this.layerMain.x() + e.evt.movementX);
                this.layerMain.y(this.layerMain.y() + e.evt.movementY);

                e.evt.preventDefault();
                this.layerMain.batchDraw();
            }
        });

        this.stage.on("dblclick", (e) => {
            if (this.selectedNode) {
                this._deselectSelectedEventNode();
            }
        });

        this.stage.on("wheel", (e) => {
            let delta = e.evt.deltaY;
            if (e.evt.shiftKey) {
                this.layerMain.x(this.layerMain.x() - delta);
            } else if (e.evt.ctrlKey || e.evt.altKey) {
                let sign = delta > 0 ? 1 : -1;
                let scale = this.layerMain.scaleX() + sign * 0.1;
                if (scale < 0.1) scale = 0.1;
                this.layerMain.scaleX(scale);
                this.layerMain.scaleY(scale);
            } else {
                this.setAutoScroll(false);
                this.layerMain.y(this.layerMain.y() - delta);
            }
            this.layerMain.batchDraw();
        });

        if(this.options.scrollctl){
            $("#"+this.options.scrollctl).on('change',() => {
                if($("#"+this.options.scrollctl).is(':checked')){
                    if(!this.autoScroll){
                        this.autoScroll = true;
                        this._autoScroll();
                    }                        
                }else{
                    if(this.autoScroll){
                        this.setAutoScroll(false);
                    }                        
                }
            });
        }
    }
    
    setHighlightedEventNode(eventId) {
        this._highlightNode(eventId);
    }

    setEventNode(data) {
        if(this.paused){
            return;
        }
        this.incount += 1;
        //console.log("TICK",this.incount);
        // if it doesent exist add it to the lookup array
        if (
            !this.lookup[data[this.eventKeyMap.eventId]] &&
            data[this.eventKeyMap.motherId]
        ) {
            this.lookup[data[this.eventKeyMap.eventId]] = data;
            this.length += 1;
            this._createEventNode(data);
        }
        // else we add the data to the already existing object
        else if (this.lookup[data[this.eventKeyMap.eventId]]) {
            Object.assign(
                this.lookup[data[this.eventKeyMap.eventId]],
                data
            );
            this._updateEventNode(data);
        }

        if (this.autoScroll) this._autoScroll();
        this.layerMain.batchDraw();
    }

    _createEventNode(data) {
        let motherId = data[this.eventKeyMap.motherId];
        let fatherId = data[this.eventKeyMap.fatherId];
        let eventId = data[this.eventKeyMap.eventId];
        let nodeId = data[this.eventKeyMap.nodeId];

        let motherData = this.lookup[motherId];
        let fatherData = this.lookup[fatherId];
        let mother = this.stage.findOne("#" + motherId);

        let father = this.stage.findOne("#" + fatherId);

        let xStep = 60;
        let yStep = 70;

        let positionY = this.stage.height() * (2 / 3) - yStep;
        let positionX = 40 + nodeId * xStep;

        if (mother && father) {
            let motherY = mother.y();
            let fatherY = father.y();

            let max = Math.min(motherY, fatherY) - yStep;
            positionY = max;
        } else if (father) {
            positionY = father.y() - yStep;
        } else if (mother) {
            positionY = mother.y() - yStep;
        }

        if (this.highestPointY > positionY) this.highestPointY = positionY;

        let node = new Konva.Circle({
            x: positionX,
            y: positionY,
            radius: 10,
            fill: "transparent",
            stroke: "#444",
            strokeWidth: 2,
            id: eventId,
        });

        let that = this;

        node.on("mouseover", function () {
            if (!node.selected) {
                this.stroke("#aaa");
                this.draw();
            }
        });

        node.on("mouseout", function () {
            if (!node.selected) {
                this.stroke("#444");
                this.draw();
            }
        });

        node.on("click", function () {
            if (that.selectedNode) that._deselectSelectedEventNode();

            that.selectedNode = data;
            that._selectEventNode.bind(that)(data, true, undefined, true);

            that.layerMain.batchDraw();
        });

        this.groupEvents.add(node);
        this.length += 1;

        if (mother) {
            console.log("mother");
            this._connectEventNodes(motherData, data, "mother");
        }

        if (father) {
            console.log("father");
            this._connectEventNodes(fatherData, data, "father");
        }

        this._makeNodeWitness(data);
        this._makeNodeFamous(data);
        this._setNodeRound(data);
        this._setNodeDeleted(data);
    }

    _updateEventNode(data) {
        this._makeNodeWitness(data);
        this._makeNodeFamous(data);
        this._setNodeRound(data);
        // this._setNodeGrounded(data);

        this._setNodeDeleted(data);
    }
    
    _setNodeDeleted(data) {
        if (data[this.eventKeyMap.remove] !== undefined) {
            let id = data[this.eventKeyMap.eventId];

            let node = this.stage.findOne("#" + id);

            if (node) {
                if (this.markInsteadOfDelete) {
                    let markNode = new Konva.Circle({
                        x: node.x(),
                        y: node.y(),
                        radius: 22,
                        fill: "#000",
                        opacity: 0.5,
                        listening: false,
                        id: id + "_round_bg",
                    });

                    this.groupDeletes.add(markNode);
                    this.length += 1;
                    this.layerMain.batchDraw();
                } else {
                    // let lines = this.stage.find("." + id + "_line");
                    let mother_line = this.stage.findOne(
                        "#" + id + "_linemother"
                    );
                    let father_line = this.stage.findOne(
                        "#" + id + "_linefather"
                    );
                    if (mother_line) {
                        mother_line.destroy();
                    }
                    if (father_line) {
                        father_line.destroy();
                    }

                    let mother_arrow = this.stage.findOne(
                        "#" + id + "_arrowmother"
                    );
                    let father_arrow = this.stage.findOne(
                        "#" + id + "_arrowfather"
                    );
                    if (mother_arrow) {
                        mother_arrow.destroy();
                    }
                    if (father_arrow) {
                        father_arrow.destroy();
                    }

                    // console.log("lines", lines);
                    // for (let line of lines) {
                    //     line.destroy();
                    // }

                    // let arrows = this.stage.find("." + id + "_arrow");

                    // for (let arrow of arrows) {
                    //     arrow.destroy();
                    // }

                    let witness = this.stage.find("#" + id + "_witness");
                    let famous = this.stage.find("#" + id + "_famous");
                    let roundBg = this.stage.find("#" + id + "_round_bg");
                    let round = this.stage.find("#" + id + "_round");
                    // let grounded = this.stage.find("#", id + "_grounded");

                    if (witness) witness.destroy();
                    if (famous) famous.destroy();
                    if (roundBg) roundBg.destroy();
                    if (round) round.destroy();
                    // if (grounded) grounded.destroy();

                    node.destroy();
                }
            }

            if (this.roundLookup[this.lookup[id][this.eventKeyMap.round]])
                delete this.roundLookup[
                    this.lookup[id][this.eventKeyMap.round]
                ];
            if (this.lookup[id]) delete this.lookup[id];
        }
    }

    _setNodeRound(data) {
        let node = this.stage.findOne(
            "#" + data[this.eventKeyMap.eventId]
        );

        if (!node) return;

        let roundObj = data[this.eventKeyMap.round];

        if (roundObj === undefined) return;
        let round = roundObj[this.eventKeyMap.roundNumber];

        if (this.roundLookup[round]) {
            Object.assign(this.roundLookup[round], roundObj);
        } else this.roundLookup[round] = roundObj;

        let roundProcessed = (round + 10) % 10;
        let roundText = roundProcessed.toString();
        roundText = roundText.split("");
        roundText = roundText[roundText.length - 1];

        if (round != undefined) {
            let roundNode = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_round"
            );

            if (!roundNode) {
                let roundBackgroundNode = new Konva.Circle({
                    x: node.x(),
                    y: node.y(),
                    radius: 8,
                    fill: "#fff",
                    listening: false,
                    id: data[this.eventKeyMap.eventId] + "_round_bg",
                });
                this.groupEvents.add(roundBackgroundNode);
                this.length += 1;

                let roundNode = new Konva.Text({
                    x: node.x() - 3,
                    y: node.y() - 5,
                    text: roundText,
                    align: "center",
                    verticalAlign: "center",
                    fill: "#222",
                    listening: false,
                    id: data[this.eventKeyMap.eventId] + "_round",
                });
                this.groupLabels.add(roundNode);
                this.length += 1;
            } else {
                roundNode.text(roundText);
            }
        }
    }

    _makeNodeWitness(data) {
        // get the data connecting to the event
        let lookupData = this.lookup[data[this.eventKeyMap.eventId]];
        // maybe just do data.witness? or lookupdata.witness?
        // if the event exists and the event is a witness
        if (lookupData && lookupData.witness) {
            let node = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId]
            );

            if (!node) return;

            let witnessNode = this.layerMain.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_witness"
            );

            if (!witnessNode) {
                let witnessNode = new Konva.Circle({
                    x: node.x(),
                    y: node.y(),
                    radius: 14,
                    fill: "transparent",
                    stroke: "#af4141",
                    strokeWidth: 3,
                    listening: false,
                    id: data[this.eventKeyMap.eventId] + "_witness",
                });

                this.groupEvents.add(witnessNode);
                this.length += 1;
            }
        } else {
            let witnessNode = this.layerMain.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_witness"
            );

            if (witnessNode) {
                witnessNode.destroy();
            }
        }
    }

    _makeNodeFamous(data) {
        let lookupData = this.lookup[data[this.eventKeyMap.eventId]];
        if (lookupData && lookupData.famous) {
            let node = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId]
            );

            if (!node) return;

            let famousNode = this.layerMain.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_famous"
            );

            if (!famousNode) {
                let famousNode = new Konva.Circle({
                    x: node.x(),
                    y: node.y(),
                    radius: 19,
                    fill: "transparent",
//                    stroke: "#5ac900",
                    stroke: "#0021c9",
                    strokeWidth: 3,
                    listening: false,
                    id: data[this.eventKeyMap.eventId] + "_famous",
                });

                this.groupEvents.add(famousNode);
                this.length += 1;
            } else {
                famousNode.stroke("#5ac900");
                this.layerMain.batchDraw();
            }
        } else if (
            lookupData &&
            lookupData[this.eventKeyMap.famous] == false
        ) {
            let node = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId]
            );

            let famousNode = this.layerMain.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_famous"
            );

            if (!famousNode) {
                let famousNode = new Konva.Circle({
                    x: node.x(),
                    y: node.y(),
                    radius: 19,
                    fill: "transparent",
                    stroke: "#2F80ED",
                    strokeWidth: 3,
                    listening: false,
                    id: data[this.eventKeyMap.eventId] + "_famous",
                });

                this.groupEvents.add(famousNode);
                this.length += 1;
            } else {
                famousNode.stroke("#2F80ED");
                this.layerMain.batchDraw();
            }
        } else {
            let famousNode = this.layerMain.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_famous"
            );

            if (famousNode) {
                famousNode.destroy();
            }
        }
    }

    _connectEventNodes(data1, data2, suffix) {
        let node1 = this.stage.findOne("#" + data1.id);
        let node2 = this.stage.findOne("#" + data2.id);

        if (!node1 || !node2) return;

        let lineNode = new Konva.Line({
            points: [node1.x(), node1.y(), node2.x(), node2.y()],
            stroke: "#eee",
            strokeWidth: 2,
            id: data2.id + "_line" + suffix,
            name: data2.id + "_line",
        });

        let angleDegrees = Math.atan2(
            node1.y() - node2.y(),
            node1.x() - node2.x()
        );

        let distance = -10;
        let arrowX = node1.x() + distance * Math.cos(angleDegrees);
        let arrowY = node1.y() + distance * Math.sin(angleDegrees);

        let arrowNode = new Konva.RegularPolygon({
            x: arrowX,
            y: arrowY,
            sides: 3,
            radius: 5,
            rotation: (angleDegrees / Math.PI) * 180 - 30,
            fill: "#eee",
            id: data2.id + "_arrow" + suffix,
            name: data2.id + "_arrow",
        });

        this.groupLines.add(lineNode, arrowNode);
        this.length += 1;
    }

    _selectEventNode(data, value, currentRound, primary) {
        let round = data[this.eventKeyMap.round];
        let witness = data[this.eventKeyMap.witness];

        if (primary) {
            this.counterNodeSelection++;
        }

        let node = this.stage.findOne(
            "#" + data[this.eventKeyMap.eventId]
        );

        if (!node) return;
        if (node.counterNodeSelection === this.counterNodeSelection) return;

        node.counterNodeSelection = this.counterNodeSelection;

        node.selectedPrimary = primary && value;
        node.selectedChild = !primary && value;
        node.selected = value;

        if (value) node.stroke(primary ? "#af4141" : "#4172af");
        else node.stroke("#444");

        if (!primary && witness) return;

        let motherData = this.lookup[data[this.eventKeyMap.motherId]];
        let fatherData = this.lookup[data[this.eventKeyMap.fatherId]];

        if (motherData) {
            this._selectEventNode(motherData, value, round);
            let lineNode = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_linemother"
            );
            lineNode.stroke(value ? "#4172af" : "#eee");

            let arrowNode = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_arrowmother"
            );
            arrowNode.fill(value ? "#4172af" : "#eee");
        }
        if (fatherData) {
            this._selectEventNode(fatherData, value, round);
            let lineNode = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_linefather"
            );
            lineNode.stroke(value ? "#4172af" : "#eee");

            let arrowNode = this.stage.findOne(
                "#" + data[this.eventKeyMap.eventId] + "_arrowfather"
            );
            arrowNode.fill(value ? "#4172af" : "#eee");
        }
    }
    
    _deselectSelectedEventNode() {
        this._selectEventNode.bind(this)(
            this.selectedNode,
            false,
            undefined,
            true
        );
        this.layerMain.batchDraw();

        this.selectedNode = {};
    }

    _highlightNode(id) {
        let highlightNode = this.stage.findOne("#_highlight");

        if (highlightNode) {
            highlightNode.destroy();
            this.layerMain.batchDraw();
        }

        if (id) {
            if (this.lookup[id]) {
                let node = this.stage.findOne("#" + id);

                if (node) {
                    let highlightNode = new Konva.Circle({
                        x: node.x(),
                        y: node.y(),
                        radius: 23,
                        fill: "transparent",
                        stroke: "red",
                        strokeWidth: 4,
                        opacity: 0.75,
                        listening: false,
                        id: "_highlight",
                    });

                    this.setAutoScroll(false);

                    this.layerMain.y(-node.y() + this._container.clientHeight * (1 / 2));

                    this.groupEvents.add(highlightNode);
                    this.length += 1;
                    this.layerMain.batchDraw();
                }
            }
        }
    }

    _autoScroll() {
        this.layerMain.y(
            -this.highestPointY * this.layerMain.scaleY() +
                this._container.clientHeight * (1 / 16)
        );

        this.layerMain.batchDraw();
    }

    _reset() {
        if(this.groupDeletes){
            this.groupDeletes.destroyChildren();
            this.groupDeletes.destroy();
        }
        if(this.groupLines){
            this.groupLines.destroyChildren();
            this.groupLines.destroy();
        }
        if(this.groupEvents){
            this.groupEvents.destroyChildren();
            this.groupEvents.destroy();
        }
        if(this.groupLabels){
            this.groupLabels.destroyChildren();
            this.groupLabels.destroy();
        }

        this.stage.removeChildren();
        this.stage.clearCache();
        
        if(this.layerMain){
            this.layerMain.destroy();
        }

        this.layerMain = new Konva.Layer();

        this.groupDeletes = new Konva.Group();
        this.groupLines = new Konva.Group();
        this.groupEvents = new Konva.Group();
        this.groupLabels = new Konva.Group();

        this.layerMain.add(this.groupDeletes);
        this.layerMain.add(this.groupLines);
        this.layerMain.add(this.groupEvents);
        this.layerMain.add(this.groupLabels);

        let startNode = new Konva.Circle({
            x: 35,
            y: this._container.clientHeight * (2 / 3) - 35,
            radius: 30,
            fill: "#bbb",
        });

        this.layerMain.add(startNode);

        this.stage.add(this.layerMain);

        this.lookup = {};
        this.roundLookup = {};
        this.highestPointY = 0;
        this.length = 0;
        this.incount = 0;
        
        this.stats = {
            events: 0,
            nodes: 0,
            round: 0,
        };

        this._autoScroll();

        this.layerMain.batchDraw();
    }

    estimateSize(){
        return this.length;    
    }

    // from state

    setAutoScroll(value) {
        this.autoScroll = value;
        $("#"+this.options.scrollctl).prop('checked', value);
        if (value) {
            this._autoScroll();
        }
    }
    
    pause() {
        this.paused = true;
    }

    resume() {
        this.paused = false;
        this._reset();
    }

}

export function createHashGraph(id, options) {
    return new HashGraph(id, options);
}
