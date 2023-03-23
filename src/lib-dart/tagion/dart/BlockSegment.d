module tagion.dart.BlockSegment;

import std.stdio : File;

import LEB128 = tagion.utils.LEB128;
import std.typecons : Typedef;
import tagion.hibon.Document;
import tagion.dart.BlockFile;
import tagion.basic.Types : Buffer;
/// BlockFile file position index
//alias Index = Typedef!(ulong, ulong.init, "BINDEX");

//enum NullIndex = Index.init;

@safe
struct BlockSegment {
    Index index; /// Block index where the document is stored or should be stored
    Document doc; /// Document stored in the segment
        immutable bool head; /// Set to `true` this block starts a chain of blocks
    alias begin_index=index;
    version (none) uint blocks(const uint block_size) const pure nothrow @nogc {
        const total_size = totalSize;
        return total_size / block_size + (total_size % block_size == 0) ? 0 : 1;
    }

    void write(BlockFile blockfile) const {
        blockfile.seek(index);
        blockfile.file.rawWrite(doc.serialize);
    }

    @disable this();
    this(const Document doc, const Index index) pure nothrow @nogc {
        this.index = index;
        this.doc = doc;
    }

    this(BlockFile blockfile, const Index index) {
        import tagion.hibon.HiBONRecord : fread;
        blockfile.seek(index);
        doc = blockfile.file.fread;
    }

    uint size() const pure nothrow @nogc {
        return cast(uint)doc.full_size;
    }
        enum HEADER_SIZE = cast(uint)(uint.sizeof);
    
    Buffer data() {
        return doc.data;
    }
}

version (unittest) {
    import Basic = tagion.basic.Basic;
    import tagion.basic.Types : FileExtension;

    const(Basic.FileNames) fileId(T = BlockSegment)(string prefix = null) @safe {
        return Basic.fileId!T(FileExtension.block, prefix);
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
    writefln("filename=%s", filename);
    auto file = File(filename, "w");
    scope (exit) {
        file.close;
    }
    file.rawWrite(iota(SMALL_BLOCK_SIZE).map!(i => cast(ubyte) i).array);

}
