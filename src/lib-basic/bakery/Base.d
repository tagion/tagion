module bakery.Base;

import bakery.crypto.Hash;

//Common components for bakery

enum ThreadState {
    KILL = 9,
    LIVE = 1
}

enum EventProperty {
	IS_STRONGLY_SEEING,
	IS_FAMOUS,
	IS_WITNESS
};

enum EventType {
    EVENT_BODY,
    EVENT_UPDATE
};

struct InterfaceEventUpdate {
    EventType eventType;
    uint id;
	EventProperty property;
	bool value;

    this (const uint id, const EventProperty property, const bool value) {
        this.eventType = EventType.EVENT_UPDATE;
        this.id = id;
        this.property = property;
        this.value = value;
    }
}

struct InterfaceEventBody {
    EventType eventType;
    uint id;
    uint mother_id;
	uint father_id;
	//immutable(ubyte)[] payload;
    uint node_id;

    this(const(uint) id, 
	/*immutable(ubyte)[] payload,*/
    const(uint) node_id,
	const(uint) mother_id = 0, 
	const(uint) father_id = 0
	) inout {
        this.eventType = EventType.EVENT_BODY;
        this.id = id;
        this.mother_id = mother_id;
		this.father_id = father_id;
		//this.payload = payload;
        this.node_id = node_id;
    }
}

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import bakery.crypto.SHA256;
    return SHA256(data);
}