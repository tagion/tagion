/**
 HiBON Base58 with  ':' added in the front of the string as an indetifyer
 is base58 base on the flowing ASCII characters
 "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz""

*/
module tagion.hibon.HiBONtoText;
@safe:

import std.format;
import tagion.hibon.HiBONException;
import misc = tagion.utils.Miscellaneous;
import std.typecons : TypedefType;
import tagion.basic.Types : encodeBase58;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;

public import tagion.basic.Types;
import tagion.basic.base58;

enum {
    hex_prefix = "0x",
    HEX_PREFIX = "0X"
}

string encodeBase58(const(Document) doc) pure {
    return encodeBase58(doc.data);
}

string encodeBase58(T)(const(T) t) pure
if (isHiBONRecord!T) {
    return encodeBase58(t.serialize);
}

@nogc bool isHexPrefix(const(char[]) str) pure nothrow {
    if (str.length >= hex_prefix.length) {
        return (str[0 .. hex_prefix.length] == hex_prefix)
            || (str[0 .. HEX_PREFIX.length] == HEX_PREFIX);
    }
    return false;
}

@nogc bool isBase58Prefix(const(char[]) str) pure nothrow {
    return (str.length > 0) && (str[0] is BASE58Identifier);
}

@trusted
immutable(ubyte[]) decode(const(char[]) str) pure {
    if (isBase58Prefix(str)) {
        return Base58.decode(str[1 .. $]);
    }
    else if (isHexPrefix(str)) {
        return misc.decode(str[hex_prefix.length .. $]);
    }
    return misc.decode(str);
}

Document decodeBase58(const(char[]) str) pure {
    return Document(decode(str));
}
