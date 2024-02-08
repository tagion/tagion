module tagion.services.error_codes;

import tagion.hibon.Document;
import std.traits;

enum ServiceCode {
    @("No Errors") none = 0,
    @("An internal error occured") internal = 1,

    @("Received an invalid buffer") buf = 5,
    @("The request timed out") timeout = 6,

    // HiRPC stuffz
    @("The document vas not a HiRPC sender") hirpc = 21,
    @("The method name was invalid") method = 22,
    @("The method domain was invalid") domain = 23,

    // HiBON error codes
    @("Generic invalid hibon") hibon = 700,
}

@safe
string toString(ServiceCode errno) pure nothrow {
    switch (errno) {
        static foreach (E; EnumMembers!ServiceCode) {
    case E:
            enum error_text = getUDAs!(E, string)[0];
            return (error_text.length) ? error_text : E.stringof;
        }
    default:
        return null;
    }
    assert(0);
}

int hibon_2_service_code(Document.Element.ErrorCode code) {
    return code + ServiceCode.hibon;
}
