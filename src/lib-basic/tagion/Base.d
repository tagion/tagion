module tagion.Base;
import tagion.utils.BSON : R_BSON=BSON, Document;
alias R_BSON!true GBSON;
import tagion.crypto.Hash;
import std.string : format;

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

@safe
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

    GBSON toBSON () const {
        auto bson = new GBSON();
        foreach(i, m; this.tupleof) {
            enum name = this.tupleof[i].stringof["this.".length..$];
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name] = m.toBSON;
                pragma(msg, format("Associated member type %s implements toBSON." , m.name));
            }

            bool include_member = true;
            static if ( __traits(compiles, m.length ) ) {
                include_member = m.length != 0;
                pragma(msg, format("The member %s is an array type", name) );
            }

            if( include_member ) {
                bson[name] = m;
                pragma(msg, format("Member %s included.", name) );
            }

        }
        return bson;
    }

    @trusted
    immutable(ubyte)[] serialize() const {
        return toBSON().serialize;
    }

}

@safe
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

    GBSON toBSON () const {
        auto bson = new GBSON();
        foreach(i, m; this.tupleof) {
            enum name = this.tupleof[i].stringof["this.".length..$];
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name] = m.toBSON;
                pragma(msg, format("Associated member type %s implements toBSON." , m.name));
            }

            bool include_member = true;
            static if ( __traits(compiles, m.length ) ) {
                include_member = m.length != 0;
                pragma(msg, format("The member %s is an array type", name) );
            }

            if( include_member ) {
                bson[name] = m;
                pragma(msg, format("Member %s included.", name) );
            }

        }
        return bson;
    }

    @trusted
    immutable(ubyte)[] serialize() const {
        return toBSON().serialize;
    }
}

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import tagion.crypto.SHA256;
    return SHA256(data);
}