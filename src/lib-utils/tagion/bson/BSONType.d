module tagion.bson.BSONType;

import tagion.Base : EnumText;
import tagion.bson.BSONMessages;
import tagion.utils.BSON : Document;

// enum BsonType {
//     EVENT_CREATE_MESSAGE,
//     EVENT_UPDATE_MESSAGE
// }


template checkType(uint index, CT, T...) {
    static assert ( T.length > 0, "At least one type is needed.");
    static if ( is ( T[0] == CT) ) {
        alias checkType = index;
    }
    else {
        static assert ( T.length > 1, "The bson type does not exist.");
        alias checkType = checkType!(index+1, CT, T[1..$]);
    }
}

//get document type
template bsonType(T) {
    alias bsonType = checkType!(0,
    T,
    EventCreateMessage,
    EventUpdateMessage);
}

T getBsonType(Document doc) {

}

// //convert from bson to type
// public static immutable(string[BsonType]) bson_types;

// static this() {

//     with(BsonType) {
//         string[BsonType] _bson_type = [
//             EVENT_CREATE_MESSAGE : EventCreateMessage.stringof,
//             EVENT_UPDATE_MESSAGE : EventUpdateMessage.stringof
//         ];

//         import std.exception : assumeUnique;
//         bson_types = assumeUnique(_bson_type);
//         assert(
//             BsonType.max+1 == bson_types.length,
//             "Some BsonTupes in "~bson_types.stringof~"is missing"
//         );
//     }
// }
