module tagion.dart.BlockSegment;

import std.stdio : File;

import LEB128 = tagion.utils.LEB128;
import std.typecons : Typedef;
import tagion.hibon.Document;
import tagion.dart.BlockFile;
import tagion.basic.Types : Buffer;

@safe
struct BlockSegment {
    Index index; /// Block index where the document is stored or should be stored
    Document doc; /// Document stored in the segment

    void write(BlockFile blockfile) const {
        blockfile.seek(index);
        blockfile.file.rawWrite(doc.serialize);
    }

    @disable this();
    this(const Document doc, const Index index) pure nothrow @nogc {
        this.index = index;
        this.doc = doc;
    }

    import tagion.hibon.HiBONFile : fread;

    this(BlockFile blockfile, const Index index) {
        blockfile.seek(index);
        doc = blockfile.file.fread;
        this.index = index;
    }

}

version (unittest) {
    import basic = tagion.basic.basic;
    import tagion.basic.Types : FileExtension;

    const(basic.FileNames) fileId(T = BlockSegment)(string prefix = null) @safe {
        return basic.fileId!T(FileExtension.block, prefix);
    }

    enum SMALL_BLOCK_SIZE = 0x40;
}

///
@safe
unittest {
    import std.stdio;
    import std.array : array;
    import std.range : iota;
    import std.algorithm.iteration : map;

    immutable filename = fileId("blocksegment").fullpath;
    // writefln("filename=%s", filename);
    auto file = File(filename, "w");
    scope (exit) {
        file.close;
    }
    file.rawWrite(iota(SMALL_BLOCK_SIZE).map!(i => cast(ubyte) i).array);

}
