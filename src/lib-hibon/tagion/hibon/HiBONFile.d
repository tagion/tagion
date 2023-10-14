module tagion.hibon.HiBONFile;
import file = std.file;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import LEB128 = tagion.utils.LEB128;
import std.stdio : File;
import std.exception : assumeUnique;
import std.typecons : No;

/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
@safe void fwrite(const(char[]) filename, const HiBON hibon) {
    file.write(filename, hibon.serialize);
}

/++
 Serialize the hibon and writes it a file
 Params:
 filename = is the name of the file
 hibon = is the HiBON object
 +/
@safe void fwrite(const(char[]) filename, const Document doc) {
    file.write(filename, doc.serialize);
}

@safe void fwrite(T)(const(char[]) filename, const T rec) if (isHiBONRecord!T) {
    fwrite(filename, rec.toDoc);
}

/++
 Reads a HiBON document from a file
 Params:
 filename = is the name of the file
 Returns:
 The Document read from the file
 +/
@trusted Document fread(const(char[]) filename) {
    import std.format;
    import tagion.hibon.HiBONException : check;

    immutable data = assumeUnique(cast(ubyte[]) file.read(filename));
    const doc = Document(data);
    const error_code = doc.valid(null, No.Reserved);
    check(error_code is Document.Element.ErrorCode.NONE, format("HiBON Document format %s failed in %s", error_code, filename));
    return doc;
}

@safe
T fread(T, Args...)(const(char[]) filename, Args args) if (isHiBONRecord!T) {
    const doc = filename.fread;
    return T(doc, args);
}

@safe
Document fread(ref File file) {
    import LEB128 = tagion.utils.LEB128;

    enum LEB128_SIZE = LEB128.DataSize!size_t;
    ubyte[LEB128_SIZE] _buf;
    ubyte[] buf = _buf;
    const doc_start = file.tell;
    file.rawRead(buf);
    const doc_size = LEB128.read!size_t(buf);
    auto data = new ubyte[doc_size.size + doc_size.value];
    file.seek(doc_start);
    file.rawRead(data);
    return (() @trusted => Document(assumeUnique(data)))();
}

@safe
T fread(T)(ref File file) if (isHiBONRecord!T) {
    const doc = file.fread;
    return T(doc);
}

@safe
void fwrite(ref File file, const Document doc) {
    file.rawWrite(doc.serialize);
}

@safe
void fwrite(T)(ref File file, const T rec) if (isHiBONRecord!T) {
    fwrite(file, rec.toDoc);
}

@safe
unittest {
    import std.file : deleteme, remove;

    static struct Simple {
        int x;
        mixin HiBONRecord!(q{
            this(int _x) {
                x = _x;
            }
        });
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

struct HiBONFile {
    File file;
    Document doc;
    private ubyte[] buf;
    @property
    bool empty() pure const {
        return file.eof;
    }

    Document front() pure nothrow const @nogc {
        return doc;
    }

    void popFront() {
        if (!empty) {
            buf.length = LEB128.DataSize!size_t;
            const doc_start = file.tell;
            file.rawRead(buf);
            const doc_size = LEB128.decode!size_t(buf);
            buf.length = doc_size.size + doc_size.value;
            file.seek(doc_start);
            file.rawRead(buf);
            doc = Document(buf.idup);
        }
    }
}
