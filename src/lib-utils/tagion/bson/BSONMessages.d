module tagion.bson.BSONMessages;

import std.stdio : writefln, writeln;
import tagion.bson.BSONType;
import tagion.Base : basename;
import tagion.utils.BSON : R_BSON=BSON, Document;
alias GBSON = R_BSON!true;

@safe
class BsonCastException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

enum EventProperty {
	IS_STRONGLY_SEEING,
	IS_FAMOUS,
	IS_WITNESS
}

@safe
struct EventUpdateMessage {
    immutable uint bson_type_code=bsonType!(typeof(this));
    uint id;
	EventProperty property;
	bool value;

    this (const uint id, const EventProperty property, const bool value) {
        this.id = id;
        this.property = property;
        this.value = value;
    }

    this(immutable(ubyte)[] data) inout {
        auto doc=Document(data);
        this(doc);
    }

    this(Document doc) inout {
        foreach(i, ref m; this.tupleof) {
            alias typeof(m) type;
            writeln("Type for member: ", type.stringof);
            enum name=basename!(this.tupleof[i]);
            //CheckBSON!(cc, name, doc);
            if ( doc.hasElement(name) ) {
                static if(is(type == enum)) {
                    auto value = doc[name].get!uint;
                    if(value <= type.max) {
                        this.tupleof[i]=cast(type)value;
                    }
                    else {
                        throw new BsonCastException("The chosen enum element is out of range");
                    }
                }
                else {
                    writefln("Inserting value for : %s with the value: %s and doc type: %s", name, doc[name], doc[name].type);
                    this.tupleof[i]=doc[name].get!type;
                }
            }
        }
    }

    GBSON toBSON () const {
        auto bson = new GBSON();
        foreach(i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name] = m.toBSON;
                //pragma(msg, format("Associated member type %s implements toBSON." , name));
            }

            bool include_member = true;

            static if ( __traits(compiles, m.length ) ) {
                include_member = m.length != 0;
                //pragma(msg, format("The member %s is an array type", name) );
            }

            enum member_is_enum = is(type == enum );
            if( include_member ) {
                static if(member_is_enum) {
                    bson[name] = cast(uint)m;
                }
                else {
                    bson[name] = m;
                }

                //pragma(msg, format("Member %s included.", name) );
            }
        }
        return bson;
    }

    immutable(ubyte)[] serialize() const {
        return toBSON().serialize;
    }
}

unittest { // Serialize and unserialize EventCreateMessage

    auto seed_body=EventUpdateMessage(1, EventProperty.IS_FAMOUS, true);
    writefln("Event id: %s,  Event property: %s : %s  ,   bson_type_code: %s", seed_body.id, seed_body.property.stringof, seed_body.value, seed_body.bson_type_code);
    auto raw=seed_body.serialize;

    auto replicate_body=EventUpdateMessage(raw);

    // Raw and repicate shoud be the same
    assert(seed_body == replicate_body);
}

@safe
struct EventCreateMessage {
    immutable uint bson_type_code=bsonType!(typeof(this));
    uint id;
    uint mother_id;
	uint father_id;
	immutable(ubyte)[] payload;
    uint node_id;
    bool witness;

    this(const(uint) id,
	immutable(ubyte)[] payload,
    const(uint) node_id,
	const(uint) mother_id,
	const(uint) father_id,
    const(bool) witness
	) inout {
        this.id = id;
        this.mother_id = mother_id;
		this.father_id = father_id;
		this.payload = payload;
        this.node_id = node_id;
        this.witness = witness;
    }

    this(immutable(ubyte)[] data) inout {
        auto doc=Document(data);
        this(doc);
    }

    this(Document doc) inout {
        foreach(i, ref m; this.tupleof) {
            alias type = typeof(m);
            writeln("Type for member: ", type.stringof);
            enum name=basename!(this.tupleof[i]);
            if ( doc.hasElement(name) ) {
                static if(is(type == enum)) {
                    auto value = doc[name].get!uint;
                    if(value <= type.max) {
                        this.tupleof[i]=cast(type)value;
                    }
                    else {
                        throw new BsonCastException("The chosen enum element is out of range");
                    }
                }
                else {
                    writefln("Inserting value for : %s with the value: %s and doc type: %s", name, doc[name], doc[name].type);
                    this.tupleof[i]=doc[name].get!type;
                }
            }
        }
    }

    GBSON toBSON () const {
        auto bson = new GBSON();
        foreach(i, m; this.tupleof) {
            enum name = basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name] = m.toBSON;
                //pragma(msg, format("Associated member type %s implements toBSON." , name));
            }

            bool include_member = true;

            static if ( __traits(compiles, m.length ) ) {
                include_member = m.length != 0;
                //pragma(msg, format("The member %s is an array type", name) );
            }

            enum member_is_enum = is(typeof (m) == enum );

            if( include_member ) {
                static if(member_is_enum) {
                    bson[name] = cast(uint)m;
                }
                else {
                    bson[name] = m;
                }

                //pragma(msg, format("Member %s included.", name) );
            }
        }
        return bson;
    }

    immutable(ubyte)[] serialize() const {
        return toBSON().serialize;
    }
}

unittest {
    auto payload = cast(immutable(ubyte)[])"Test payload";
    auto seed_body = EventCreateMessage(1, payload, 2, 3, 5, false);
    writefln("Event id: %s,  bson_type_code: %s", seed_body.id, seed_body.bson_type_code);
    auto raw = seed_body.serialize;

    auto replicate_body = EventCreateMessage(raw);
    assert(replicate_body == seed_body);

}