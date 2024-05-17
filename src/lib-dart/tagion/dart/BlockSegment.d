/// Segments stored in BlockFile
module tagion.dart.BlockSegment;

import std.stdio : File;

import LEB128 = tagion.utils.LEB128;
import std.typecons : Typedef;
import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile;
import tagion.hibon.Document;

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
        const max_size = blockfile.headerBlock.max_size * blockfile.headerBlock.block_size;
        doc = blockfile.file.fread(max_size);
        this.index = index;
    }

}

version (unittest) {
    import tagion.basic.Types : FileExtension;
    import basic = tagion.basic.basic;

    const(basic.FileNames) fileId(T = BlockSegment)(string prefix = null) @safe {
        return basic.fileId!T(FileExtension.block, prefix);
    }

    enum SMALL_BLOCK_SIZE = 0x40;
}

///
@safe
unittest {
    import std.algorithm.iteration : map;
    import std.array : array;
    import std.range : iota;
    import std.stdio;

    immutable filename = fileId("blocksegment").fullpath;
    // writefln("filename=%s", filename);
    auto file = File(filename, "w");
    scope (exit) {
        file.close;
    }
    file.rawWrite(iota(SMALL_BLOCK_SIZE).map!(i => cast(ubyte) i).array);

}
