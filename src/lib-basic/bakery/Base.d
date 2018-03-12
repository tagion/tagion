module bakery.Base;

import bakery.crypto.Hash;

//Common components for bakery

enum ThreadState {
    KILL = 9,
    LIVE = 1
}

enum EventProperty {
	STRONGLY_SEEING,
	IS_FAMOUS,
	IS_WITNESS
};

struct InterfaceEventUpdate {
    immutable(uint) id;
	immutable(EventProperty) property;
	immutable(bool) value;

    this (const uint id, const EventProperty property, const bool value) {
        this.id = id;
        this.property = property;
        this.value = value;
    }
}

struct InterfaceEventBody {
    immutable(uint) id;
    immutable(uint) motherId;
	immutable(uint) fatherId;
	immutable(ubyte[]) payload;

    this(const(uint) id, 
	immutable(ubyte[]) payload,
	const(uint) motherId = 0, 
	const(uint) fatherId = 0
	) {
        this.id = id;
        this.motherId = motherId;
		this.fatherId = fatherId;
		this.payload = payload;
    }
}

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import bakery.crypto.SHA256;
    return SHA256(data);
}