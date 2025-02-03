/**
 HiBON Base64 with  ':' added in the front of the string as an indetifyer
 is base64 base on the flowing ASCII characters
 "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 +/"

            1111111111222222 22223333333334444444444455 5555555566 66
  01234567890123456789012345 67890123456789012345678901 2345678901 23

  and = as padding


*/
module tagion.hibon.HiBONtoText;
@safe:

import std.format;
import tagion.hibon.HiBONException;
import convert = tagion.utils.convert;
import tagion.utils.convert: Prefix;
import std.base64;
import std.typecons : TypedefType;
import tagion.basic.Types : encodeBase64;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;

public import tagion.basic.Types;


string encodeBase64(const(Document) doc) pure {
    return encodeBase64(doc.data);
}

string encodeBase64(T)(const(T) t) pure
if (isHiBONRecord!T) {
    return encodeBase64(t.serialize);
}

@nogc bool isHexPrefix(const(char[]) str) pure nothrow {
    if (str.length >= Prefix.hex.length) {
        return (str[0 .. Prefix.hex.length] == Prefix.hex)
            || (str[0 .. Prefix.HEX.length] == Prefix.HEX);
    }
    return false;
}

@nogc bool isBase64Prefix(const(char[]) str) pure nothrow {
    return (str.length > 0) && (str[0] is BASE64Identifier);
}

immutable(ubyte[]) decode(const(char[]) str) pure {
    if (isBase64Prefix(str)) {
        return Base64URL.decode(str[1 .. $]);
    }
    else if (isHexPrefix(str)) {
        return convert.decode(str[Prefix.hex.length .. $]);
    }
    return convert.decode(str);
}

Document decodeBase64(const(char[]) str) pure {
    return Document(decode(str));
}
