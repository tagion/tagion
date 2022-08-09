/// \file Fingerprint.d
module tagion.utils.Fingerprint;

import std.bigint : BigInt;
import std.format;
import std.string : strip;
import tagion.basic.Types : Buffer;

/** @brief File contains structure Fingerprint
 */

/**
 * \struct Fingerprint
 * Struct stores fingerprint and helps with pretty output
 */
@safe struct Fingerprint
{
    /** Buffer representing fingerprint */
    Buffer buffer;

    this(Buffer buffer)
    {
        this.buffer = buffer;
    }

    /** Used for formatted output of buffer. Supports format specifiers.
     *  Supported specifiers: %s or %X, %x, %d with width parameter.
     *      @param sink - delegate to write output directly
     *      @param fmt - format specificators
     */
    @trusted void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
        string fmt_number;

        switch (fmt.spec)
        {
        case 's': // this is default format for fingerprint
        case 'X':
            fmt_number = "%02X ";
            break;
        case 'x':
            fmt_number = "%02x ";
            break;
        case 'd':
            fmt_number = "%d ";
            break;
        default:
            throw new Exception("Unknown format specifier: %" ~
                    fmt.spec);
        }

        string result;

        const width = fmt.width is 0 ? buffer.length + 1 : fmt.width;
        foreach (i; 0 .. buffer.length)
        {
            result ~= std.format.format(fmt_number, BigInt(buffer[i]));

            if ((i + 1) % width is 0)
                result ~= "\n";
        }

        sink(strip(result));
    }
}

/** Unittest for testing struct Fingerprint
 */
unittest
{
    assert(format("%s", Fingerprint([])) == "");
    assert(format("%X", Fingerprint([255])) == "FF");

    Buffer fingerprint = [
        143, 0, 51, 132, 41, 244, 105, 22, 182, 75, 173, 136, 17, 208, 91, 39
    ];

    // Specifiers %s and %X are equal
    assert(format("%X", Fingerprint(
            fingerprint)) == format("%s", Fingerprint(
            fingerprint)));

    // Output of uppercase hex
    assert(format("%X", Fingerprint(
            fingerprint)) == "8F 00 33 84 29 F4 69 16 B6 4B AD 88 11 D0 5B 27");

    // Output of decimal
    assert(format("%d", Fingerprint(
            fingerprint)) == "143 0 51 132 41 244 105 22 182 75 173 136 17 208 91 39");

    // Output of lowercase hex with width 4
    assert(format("%4x", Fingerprint(
            fingerprint)) == "8f 00 33 84 \n" ~
            "29 f4 69 16 \n" ~
            "b6 4b ad 88 \n" ~
            "11 d0 5b 27");

    // Exception for any wrong specifier
    try
    {
        format("%i", Fingerprint([]));
        assert(false); // Expecting exception
    }
    catch (Exception e)
    {
    }
}
