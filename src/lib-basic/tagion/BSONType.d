module tagion.BSONType;

import tagion.Base : EnumText;


enum bson_type_list = ["event_create_message", "event_update_message"];

mixin("bson_type", EnumText!(bson_type_list));

//create document with type
struct BsonType(T : tagion.Base.InterfaceEventUpdate) {
    enum type = bson_type.event_update_message;

}

//convert from bson to type
public static immutable(string[bson_type]) bson_types;

static this() {
    with(bson_type) {
        string[bson_type] _
    }
}
