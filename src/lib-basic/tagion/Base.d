module tagion.Base;

import tagion.crypto.Hash;

enum this_dot="this.";

/**
   Template function for removing the "this." prefix
 */
template basename(alias K) {
    enum name=K.stringof;
    static if (
        (name.length > this_dot.length) &&
        (name[0..this_dot.length] == this_dot) ) {
        alias name[this_dot.length..$] basename;
    }
    else {
        alias name basename;
    }
}
// immutable(char[]) basename(immutable(char[]) fullname) {
//     enum _fullname=fullname;
//     static if (
//         (_fullname.length > this_dot) &&
//         (_fullname[0..this_dot.length] == this_dot) ) {
//         return _fullname[this_dot.length..$];
//     }
//     else {
//         return _fullname;
//     }
// }

//Common components for tagion

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
    bool witness;

    this(const(uint) id,
	/*immutable(ubyte)[] payload,*/
    const(uint) node_id,
	const(uint) mother_id,
	const(uint) father_id,
    const(bool) witness
	) inout {
        this.eventType = EventType.EVENT_BODY;
        this.id = id;
        this.mother_id = mother_id;
		this.father_id = father_id;
		//this.payload = payload;
        this.node_id = node_id;
        this.witness = witness;
    }
}

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import tagion.crypto.SHA256;
    return SHA256(data);
}
