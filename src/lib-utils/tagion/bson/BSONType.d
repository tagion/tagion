module tagion.bson.BSONType;

import tagion.Base : EnumText, basename;
import std.conv;
import std.string : format;
import std.stdio : writefln, writeln;
import tagion.utils.BSON : HBSON, Document;
import tagion.Base : Pubkey, Buffer;

//alias Pubkey = immutable(ubyte[]);

enum BSON_TEST_MSG = "bson_test_msg";
enum BSON_TEST_MSG_CODE = 10_000;
enum BSON_TYPE_CODE = "bson_type_code";

@safe
class bsonTypeCodeException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}


template getTypeCode(uint index, CT, T...) {
    static assert ( T.length > 0, "At least one type is needed.");
    //pragma(msg, format("The length of the T slice is %s in getTypeCode. The type is %s and comp. type is %s", T.length, CT.stringof, T[0].stringof));
    static if ( is ( T[0] : CT) ) {
        alias getTypeCode = index;
    }
    else static if ( T.length > 1) {
        alias getTypeCode = getTypeCode!(index+1, CT, T[1..$]);
    }
    else {
        static assert ( 0, "The bson type does not exist.");
    }
}

//get document type
template bsonTypeCode(T) {
    alias bsonTypeCode = getTypeCode!(0,
    T,
    EventCreateMessage,
    EventUpdateMessage);
}

static immutable string[uint] bson_Types;

static this() {
    string[uint] _bson_Types=[
        0 : EventCreateMessage.stringof,
        1 : EventUpdateMessage.stringof,
        BSON_TEST_MSG_CODE : BSON_TEST_MSG
    ];
    import std.exception : assumeUnique;
    bson_Types = assumeUnique(_bson_Types);
}

string getBsonType(Document doc) {
    if(!doc.hasElement(BSON_TYPE_CODE)) {
        throw new bsonTypeCodeException("The document does not contain any bson_type code.");
    }

    auto type_code = doc[BSON_TYPE_CODE].get!uint;
    if(type_code !in bson_Types) {
        throw new bsonTypeCodeException("The type code "~to!string(type_code)~ " is not recognized.");
    }

    return bson_Types[type_code];
}

template hasBsonTypeCode(M...) {

    static if ( BSON_TYPE_CODE == basename!(M[0]) ) {
        enum has_member = true;
        alias hasBsonTypeCode = has_member;
    }
    else static if ( M.length > 1) {
        alias hasBsonTypeCode = hasBsonTypeCode!(M[1..$]);
    }
    else {
        enum has_member = false;
        alias hasBsonTypeCode = has_member;
    }
}

template checkBsonType(T, string member_name, M...) {
    void checkBsonType(Document doc) inout {
        //Check if the type has a bson_type_code member
        enum has_bson_type_code = hasBsonTypeCode!(M);
        //pragma(msg, format("Has bson_type_code: %s", has_bson_type_code));
        static assert(has_bson_type_code, format("The type %s does not contain a \"%s\".", T.stringof, BSON_TYPE_CODE));

        //Check if the member name is the bson_type code and compare the code with the assigning code
        static if( member_name == BSON_TYPE_CODE ) {
            enum assigning_bson_type_code = bsonTypeCode!T;
            uint doc_bson_type_code = doc[BSON_TYPE_CODE].get!uint;
            if ( assigning_bson_type_code != assigning_bson_type_code ) {
                throw new BsonCastException(format("The type code in the document is %s, but should have been %s for the type %s", doc_bson_type_code, assigning_bson_type_code, T.stringof));
            }
        }
    }
}

@safe
class BsonCastException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

enum EventProperty {
	IS_STRONGLY_SEEING,
	IS_FAMOUS,
	IS_WITNESS,
        IS_STRONGLY2_SEEING,

}

@safe
struct EventUpdateMessage {
    immutable uint bson_type_code=bsonTypeCode!(typeof(this));
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
            //writeln("Type for member: ", type.stringof);
            enum name=basename!(this.tupleof[i]);
            checkBsonType!(typeof(this), name, this.tupleof)(doc);
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
                    //writefln("Inserting value for : %s with the value: %s and doc type: %s", name, doc[name], doc[name].type);
                    this.tupleof[i]=doc[name].get!type;
                }
            }
        }
    }

    HBSON toBSON () const {
        auto bson = new HBSON();
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

immutable(ubyte[]) generateHoleThroughBsonMsg(string msg) {
    auto doc = new HBSON;
    doc[BSON_TYPE_CODE]=BSON_TEST_MSG_CODE;
    doc["message"]=msg;
    return doc.serialize;
}

unittest { // Serialize and unserialize EventCreateMessage

    auto seed_body=EventUpdateMessage(1, EventProperty.IS_FAMOUS, true);
    //writefln("Event id: %s,  Event property: %s : %s  ,   bson_type_code: %s", seed_body.id, seed_body.property.stringof, seed_body.value, seed_body.bson_type_code);
    auto raw=seed_body.serialize;

    auto replicate_body=EventUpdateMessage(raw);

    // Raw and repicate shoud be the same
    assert(seed_body == replicate_body);
}

@safe
struct EventCreateMessage {
    immutable uint bson_type_code=bsonTypeCode!(typeof(this));
    uint id;
    uint mother_id;
    uint father_id;
    immutable(ubyte)[] payload;
    immutable(ubyte)[] signature;
    uint node_id;
    bool witness;
    Buffer pubkey;
    immutable(ubyte[]) event_body;

    this(
        const(uint) id,
	immutable(ubyte)[] payload,
        const(uint) node_id,
	const(uint) mother_id,
	const(uint) father_id,
        const(bool) witness,
        immutable(ubyte)[] signature,
        Pubkey pubkey,
        immutable(ubyte[]) event_body) inout {
        this.id = id;
        this.mother_id = mother_id;
        this.father_id = father_id;
        this.payload = payload;
        this.node_id = node_id;
        this.witness = witness;
        this.signature = signature;
        this.pubkey = cast(Buffer)pubkey;
        this.event_body = event_body;
    }

    this(immutable(ubyte[]) data) inout {
        auto doc=Document(data);
        this(doc);
    }

    this(Document doc) inout {
        foreach(i, ref m; this.tupleof) {
            alias type = typeof(m);
            //writeln("Type for member: ", type.stringof);
            enum name=basename!(this.tupleof[i]);
            checkBsonType!(typeof(this), name, this.tupleof)(doc);
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
                    this.tupleof[i]=doc[name].get!type;
                }
            }
        }
    }

    HBSON toBSON () const {
        auto bson = new HBSON();
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
    auto sig = cast(immutable(ubyte)[])"signature goes here";
    auto seed_body = EventCreateMessage(1, payload, 2, 3, 5, false, sig, cast(Pubkey)"Test", cast(immutable(ubyte[]))"Event Body");
    //writefln("Event id: %s,  bson_type_code: %s", seed_body.id, seed_body.bson_type_code);
    immutable raw = seed_body.serialize;

    auto replicate_body = immutable EventCreateMessage(raw);
    assert(replicate_body == seed_body);

}
