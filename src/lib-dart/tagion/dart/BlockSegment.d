module tagion.dart.BlockSegment;

import LEB128=tagion.utils.LEB128;

/// BlockFile file position index
alias Index = Typedef!(ulong, ulong.init, "BINDEX");

enum NullIndex = Index.init;

@safe
struct BlockSegment {
    ulong previous; /** Block index of the previous block-segment
                    * If this is 0 then this is the first segment    
                    */
    ulong next; /** Block index of the next block 
                 * If this is 0 then this is the last segment
                 */
    Document doc; /// Document stored in the segment
    invariant {
        assert(((previous == 0) && (next == 0)) || (previous < next));
    }

    ulong totalSize() const pure nothrow @nogc {
        return LEB128.calc_size(previous) + LEB128.calc_size(next) + doc.full_size;
    }

    version (none) uint blocks(const uint block_size) const pure nothrow @nogc {
        const total_size = totalSize;
        return total_size / block_size + (total_size % block_size == 0) ? 0 : 1;
    }

    void write(ref File file) const {
        file.rawWrite(doc.serialize);
        file.rawWrite(LEB128.encode(previous));
        file.rawWrite(LEB128.encode(next));
    }

    @disable this();
    this(const Document doc, const ulong previousi = 0, const ulong next = 0) {
        this.previous = previous;
        this.next = next;
        this.doc = doc;
    }

    this(ref File file) {
        import tagion.hibon.HiBONRecord : fread;

        doc = file.fread;
        ubyte[LEB128.DataSize!ulong] _pre_buf;
        ubyte[] pre_buf = _pre_buf;
        file.rawRead(pre_buf);
        previous = LEB128.read!ulong(pre_buf).value;
        next = LEB128.read!ulong(pre_buf).value;
    }

    static void updateIndex(ref File file, const ulong previous, const ulong next)
    in (previous < next)
    do {
        const segment_start = file.tell;
        {
            ubyte[LEB128.DataSize!ulong] _buf;
            ubyte[] buf = _buf;
            file.rawRead(buf);
            const doc_size = LEB128.read!ulong(buf);
            file.seek(segment_start + doc_size.size + doc_size.value);
        }
        file.rawWrite(LEB128.encode(previous));
        file.rawWrite(LEB128.encode(next));
    }
}

version (unittest) {
    import Basic = tagion.basic.Basic;

    const(Basic.FileNames) fileId(T = BlockSegment)(string prefix = null) @safe {
        return Basic.fileId!T(FileExtension.block, prefix);
    }
}

///
@safe
unittest {
    import std.stdio;
    import std.array : array;

    immutable filename = fileId("blocksegment").fullpath;
    writefln("filename=%s", filename);
    auto file = File(filename, "w");
    scope (exit) {
        file.close;
    }
    file.rawWrite(iota(SMALL_BLOCK_SIZE).map!(i => cast(ubyte) i).array);

}
