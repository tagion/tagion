/// Service Error codes
module tagion.services.codes;

import tagion.hibon.Document;
import std.traits;

enum ServiceCode {
    @("No Errors") none = 0,
    @("An internal error occurred") internal = 1,

    @("Received an invalid buffer") buf = 5,
    @("The request timed out") timeout = 6,

    @("Missing or invalid signature") sign = 10,

    // HiRPC stuffz
    @("The document was not a HiRPC sender") hirpc = 20,
    @("The method name was invalid") method = 21,
    @("The method domain was invalid") domain = 22,
    @("Incorrect parameters") params = 23,

    // HiBON error codes
    @("Generic invalid hibon") hibon = 700,
}

int hibon_2_service_code(Document.Element.ErrorCode code) {
    return code + ServiceCode.hibon;
}

@safe
string toString(T)(T code) pure nothrow {
    final switch (code) {
        static foreach (E; EnumMembers!T) {
    case E:
            enum text = getUDAs!(E, string)[0];
            return (text.length) ? text : E.stringof;
        }
    }
}

@safe
string toString(ServiceCode errno) pure nothrow {
    return errno.toString!ServiceCode;
}
