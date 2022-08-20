module tagion.hibon.HiBONtoText;

/**
 HiBON Base64 with  ':' added in the front of the string as an indetifyer
 is base64 base on the flowing ASCII characters
 "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 +/"

            1111111111222222 22223333333334444444444455 5555555566 66
  01234567890123456789012345 67890123456789012345678901 2345678901 23

  and = as padding


*/

import tagion.utils.Miscellaneous : toHex = toHexString, decode;
import tagion.hibon.HiBONException;
import std.format;
import std.base64;

enum BASE64Indetifyer = '@';

enum
{
    hex_prefix = "0x",
    HEX_PREFIX = "0X"
}

@safe string encodeBase64(const(ubyte[]) data) pure
{
    const result = BASE64Indetifyer ~ Base64.encode(data);
    return result.idup;
}

@nogc @safe bool isHexPrefix(const(char[]) str) pure nothrow
{
    if (str.length >= hex_prefix.length)
    {
        return (str[0 .. hex_prefix.length] == hex_prefix)
            || (str[0 .. HEX_PREFIX.length] == HEX_PREFIX);
    }
    return false;
}

@nogc @safe bool isBase64Prefix(const(char[]) str) pure nothrow
{
    return (str.length > 0) && (str[0] is BASE64Indetifyer);
}

@safe immutable(ubyte[]) HiBONdecode(const(char[]) str) pure
{
    if (str[0] is BASE64Indetifyer)
    {
        return Base64.decode(str[1 .. $]).idup;
    }
    else if (isHexPrefix(str))
    {
        return decode(str[hex_prefix.length .. $]);
    }
    else
    {
        throw new HiBONException(format("HiBON binary data missing the hex '%s' or Base64 identifier '%s'",
                hex_prefix, BASE64Indetifyer));
    }
}
