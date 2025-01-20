module tagion.hibon.HiBONFile;
import file = std.file;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONException;
import LEB128 = tagion.utils.LEB128;
import std.exception : assumeUnique;
import std.stdio : File;
import std.typecons : No;
import std.format;
import std.range.primitives;

@safe:
/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
void fwrite(const(char[]) filename, const HiBON hibon) {
    file.write(filename, hibon.serialize);
}

/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
void fwrite(const(char[]) filename, const Document doc) {
    file.write(filename, doc.serialize);
}

void fwrite(T)(const(char[]) filename, const T rec) if (isHiBONRecord!T) {
    fwrite(filename, rec.toDoc);
}

/++
 Reads a HiBON document from a file
 Params:
 filename = is the name of the file
 Returns:
 The Document read from the file
 +/
@trusted Document fread(const(char[]) filename, const size_t max_size = 0) {
    import std.format;
    import tagion.hibon.HiBONException : check;

    immutable data = assumeUnique(cast(ubyte[]) file.read(filename));
    const doc = Document(data);
    const error_code = doc.valid(null, No.Reserved);
    check(error_code is Document.Element.ErrorCode.NONE, format("HiBON Document format %s failed in %s", error_code, filename));
    return doc;
}

T fread(T, Args...)(const(char[]) filename, Args args) if (isHiBONRecord!T) {
    const doc = filename.fread;
    return T(doc, args);
}

Document fread(ref File file, const size_t max_size = 0) {
    import LEB128 = tagion.utils.LEB128;
    import std.format;
    import tagion.hibon.HiBONException : check;

    enum LEB128_SIZE = LEB128.DataSize!size_t;
    ubyte[LEB128_SIZE] _buf;
    ubyte[] buf = _buf;
    const doc_start = file.tell;
    file.rawRead(buf);
    const doc_size = LEB128.read!size_t(buf);
    const data_size = doc_size.size + doc_size.value;
    check(max_size == 0 || (data_size <= max_size), format("Document size exceeds the max limit of %d", max_size));
    auto data = new ubyte[doc_size.size + doc_size.value];
    file.seek(doc_start);
    file.rawRead(data);
    return (() @trusted => Document(assumeUnique(data)))();
}

T fread(T)(ref File file) if (isHiBONRecord!T) {
    const doc = file.fread;
    return T(doc);
}

void fwrite(ref File file, const Document doc) {
    file.rawWrite(doc.serialize);
}

void fwrite(T)(ref File file, const T rec) if (isHiBONRecord!T) {
    fwrite(file, rec.toDoc);
}

unittest {
    import std.file : deleteme, remove;

    static struct Simple {
        int x;
        mixin HiBONRecord;
    }

    auto fout = File(deleteme, "w");
    scope (exit) {
        deleteme.remove;
    }

    const expected_s = Simple(42);

    fout.fwrite(expected_s);
    fout.close;
    {
        fout = File(deleteme, "r");
        const result = fout.fread!Simple;
        assert(expected_s == result);
    }
}

struct HiBONRange {
    private File file;
    enum default_max_size = 0x100_0000;
    size_t max_size;
    this(ref File file, const size_t max_size = default_max_size) {
        this.file = file;
        this.max_size = max_size;
        popFront;
    }

    //Document doc;
    private ubyte[] buf;
    @property
    bool empty() pure const {
        return file.eof;
    }

    @property
    Document front() pure nothrow const {
        return Document(buf.idup);
    }

    T get(T)() const {
        if (buf.empty) {
            return T.init;
        }
        return T(front);
    }

    void popFront() {
        if (!empty) {
            buf.length = LEB128.DataSize!size_t;
            foreach (pos; 0 .. buf.length) {
                if (file.rawRead(buf[pos .. pos + 1]).length == 0) {
                    break;
                }
                if ((buf[pos] & 0x80) == 0) {
                    break;
                }
            }
            const doc_size = LEB128.decode!size_t(buf);
            const buf_size = doc_size.size + doc_size.value;
            check((buf_size <= max_size) || (max_size == 0), format("The read buffer size is %d max size is set to %d", buf_size, max_size));
            buf.length = buf_size;
            file.rawRead(buf[doc_size.size .. $]);
            //doc = Document(buf.idup);
        }
    }

    private this(const size_t max_size) pure nothrow {
        this.max_size = max_size;
    }
}

version (unittest) {
    import tagion.hibon.HiBONRecord;
    import std.stdio;
    import std.file;
    import tagion.hibon.HiBONJSON;
    import std.algorithm;

    private struct S {
        int x;
        mixin HiBONRecord;
    }
}

unittest {
    { /// Empty HiBON-stream
        auto fout = File(deleteme, "w");
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRange(fin);
        assert(r.empty);
    }

    { /// HiBON stream with one element
        auto fout = File(deleteme, "w");
        fout.fwrite(S(17));
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRange(fin);
        assert(r.front == S(17).toDoc);

        assert(r.get!S == S(17));
        assert(!r.empty);
        r.popFront;
        assert(r.empty);
    }

    { /// HiBON stream with two element
        auto fout = File(deleteme, "w");
        fout.fwrite(S(17));
        fout.fwrite(S(42));
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRange(fin);
        assert(r.front == S(17).toDoc);
        assert(!r.empty);
        r.popFront;
        assert(r.front == S(42).toDoc);
        assert(!r.empty);
        r.popFront;
        assert(r.empty);
    }
}

static assert(isInputRange!HiBONRange);

struct HiBONRangeArray {
    private {
        File file;
        ulong index;
        ubyte[] buf;
        bool the_first = true;
    }

    const ulong[] indices;
    this(ref File file) {
        this.file = file;
        indices = initialize_indices;
    }

    private const(ulong[]) initialize_indices() {
        ulong[] _indices;
        while (true) {
            const tell = file.tell;
            const buf_size = bufSize;
            if (buf_size == 0) {
                return _indices;
            }
            _indices ~= tell;
            file.seek(tell + buf_size);
        }
        assert(0);
    }

    private size_t bufSize() {
        ubyte[LEB128.DataSize!size_t] local_buf;
        const len_buf = file.rawRead(local_buf);
        if (len_buf.length == 0) {
            return 0;
        }
        const len = LEB128.decode!size_t(len_buf);
        return len.size + len.value;
    }

    private const(ubyte[]) getBuffer(const size_t i) {
        if (i < indices.length) {
            file.seek(indices[i]);
            const buf_size = bufSize;
            if (buf.length < buf_size) {
                buf.length = buf_size;
            }
            file.seek(indices[i]);
            return file.rawRead(buf[0 .. buf_size]);
        }
        return null;
    }

    T get(T)() if (isHiBONRecord!T) {
        if (empty) {
            return T.init;
        }
        return T(front);
    }

    @property
    bool empty() pure const nothrow @nogc {
        return index >= indices.length;
    }

    @property
    Document front() {
        if (index < indices.length) {
            return Document(getBuffer(index).idup);
        }
        return Document.init;
    }

    @property back() {
        if (the_first && index < indices.length) {
            index = indices.length - 1;
            the_first = false;
        }
        return front;
    }

    void popFront() {
        if (!empty) {
            index++;
        }
    }

    void popBack() {
        index--;
    }

    HiBONRangeArray save() pure nothrow {
        return this;
    }

    Document opIndex(const size_t i) {
        return Document(getBuffer(i).idup);
    }

    size_t length() const pure nothrow @nogc {
        return indices.length;
    }
}

static assert(isBidirectionalRange!HiBONRangeArray);
static assert(isRandomAccessRange!HiBONRangeArray);
static assert(isForwardRange!HiBONRangeArray);
static assert(hasLength!HiBONRangeArray);

unittest {
    import std.range;

    { /// Empty HiBON-stream
        auto fout = File(deleteme, "w");
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRangeArray(fin);
        assert(r.empty);
    }

    { /// HiBON stream with one element
        auto fout = File(deleteme, "w");
        fout.fwrite(S(17));
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRangeArray(fin);
        assert(r.front == S(17).toDoc);

        assert(r.get!S == S(17));
        assert(!r.empty);
        r.popFront;
        assert(r.empty);
        assert(r[0] == S(17).toDoc);
    }

    { /// HiBON stream with two element
        auto fout = File(deleteme, "w");
        fout.fwrite(S(17));
        fout.fwrite(S(42));
        fout.fwrite(S(117));
        fout.fwrite(S(38));
        fout.close;
        scope (success) {
            deleteme.remove;
        }
        auto fin = File(deleteme, "r");
        scope (exit) {
            fin.close;
        }
        auto r = HiBONRangeArray(fin);
        auto r_retro = r.retro;
        assert(r.front == S(17).toDoc);
        assert(!r.empty);
        r.popFront;
        assert(r.front == S(42).toDoc);
        assert(!r.empty);
        r.popFront;
        //assert(r.empty);
        assert(r[0] == S(17).toDoc);
        assert(r[1] == S(42).toDoc);
        assert(r_retro[1] == S(117).toDoc);
        assert(equal(r_retro.map!(e => S(e).x), [38, 117, 42, 17]));
    }

}
