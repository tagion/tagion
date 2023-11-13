module tagion.hibon.HiBONValid;

import tagion.basic.Types : Buffer;
import tagion.hibon.Document : Document;

bool error_callback(const Document main_doc, const Document.Element.ErrorCode error_code,
        const(Document.Element) current, const(Document.Element) previous) nothrow @safe {
    import tagion.hibon.HiBONBase : Type, isHiBONBaseType;
    import LEB128 = tagion.utils.LEB128;
    import std.exception : assumeWontThrow;
    import std.stdio;
    import std.traits : EnumMembers, isIntegral;

    static void hex_dump(Buffer data) {
        import std.algorithm.comparison : min;

        uint addr;
        enum width = 16;
        while (data.length) {
            writef("\t\t%04X", addr);
            const data_size = min(data.length, width);
            foreach (d; data[0 .. data_size]) {
                writef(" %02X", d);
            }
            writeln();
            data = data[data_size .. $];
            addr += width;
        }
    }

    try {
        writefln("ErrorCode %s", error_code);
        if (current.data.length) {
            const current_pos = (() @trusted {
                if (current.isEod) {
                    return size_t(0);
                }
                return size_t(current.data.ptr - main_doc.data.ptr);
            })();

            const previous_pos = (() @trusted {
                if (previous.isEod) {
                    return size_t(0);
                }
                return size_t(previous.data.ptr - main_doc.data.ptr);
            })();

            CaseErrorCode: with (Document.Element.ErrorCode) {
                switch (error_code) {
                case DOCUMENT_OVERFLOW:
                    return true;
                default:
                    writefln("\tpos      %d", current_pos);
                    writefln("\tType     %s", current.type);
                    writefln("\tKeyPos   %d", current.keyPos);
                    writefln("\tvaluePos %d", current.valuePos);
                    writefln("\tkey      '%s'", current.key);
                    with (Type) {
                CaseType:
                        switch (current.type) {
                            static foreach (E; EnumMembers!(Type)) {
                        case E:
                                static if ((E is STRING) || (E is DOCUMENT) || (E is BINARY)) {
                                    writefln("\tdataPos  %d", current.dataPos);
                                    writefln("\tdataSize %d", current.dataSize);
                                    hex_dump(current.data[current.dataPos .. current.dataSize]);
                                }
                                else static if (E is BINARY) {
                                    const big_size = BigNumber.calc_size(data[valuePos .. $]);
                                    writefln("\tbigSize  %d", big_size);
                                    hex_dump(current.data[current.dataPos .. big_size]);
                                }
                                else static if (isHiBONBaseType(E)) {
                                    static if (E is TIME) {
                                        alias T = long;
                                    }
                                    else {
                                        alias T = Document.Value.TypeT!E;
                                    }
                                    static if (isIntegral!T) {
                                        const leb128_size = LEB128.calc_size(
                                                current.data[current.valuePos .. $]);
                                        writefln("\tleb128  %d", leb128_size);
                                        hex_dump(
                                                current.data[current.valuePos
                                                .. current.valuePos + leb128_size]);
                                    }
                                    else {
                                        hex_dump(
                                                current.data[current.valuePos
                                                .. current.valuePos + T.sizeof]);
                                    }
                                }
                                else static if (E is VER) {
                                    const leb128_version_size = LEB128.calc_size(
                                            current.data[ubyte.sizeof .. $]);
                                    hex_dump(
                                            current.data[ubyte.sizeof
                                            .. ubyte.sizeof + leb128_version_size]);
                                }
                                static if (isHiBONBaseType(E)) {
                                    (() @trusted { writefln("\tvalue  %s", current.by!E); })();
                                }

                                break CaseType;

                            }
                        default:
                            // Empty
                        }
                    }
                }
            }
        }
        return false;
    }
    catch (Exception e) {
        assumeWontThrow( //        (() @trusted {
        { stdout.flush; writefln("%s", e); });
        //        })();
        return true;
    }
    return false;
}
