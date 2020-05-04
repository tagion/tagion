module hibon.BinBuffer;

extern(C):
@system:
import core.stdc.stdlib : calloc, malloc, realloc, free;
import std.bitmanip : nativeToLittleEndian, nativeToBigEndian;
import std.traits : isNumeric, isArray, Unqual;
import std.exception : assumeUnique;
import hibon.Memory;

struct BinBuffer {
    version(none) {
    struct Buffer {
        private {
            ubyte[] data;
            Buffer* next;
        }
        void create(size_t size)
            in {
                assert(data !is null);
            }
        do {
            data=cast(ubyte[])(calloc(size, ubyte.sizeof))[0..size];
        }
        void dispose() {
            free(data.ptr);
        }
        static Buffer* opCall(size_t size) {
            auto result=cast(Buffer*)(calloc(1, Buffer.sizeof));
            result.create(size);
            return result;
        }
        ~this() {
            dispose();
        }
    }
    protected {
        Buffer* root;
        Buffer* current;
        size_t index;
    }
    }
    protected {
        ubyte[] _data;
        size_t _index;
//        ubyte[] current;
    }
    enum DEFAULT_SIZE=256;
    this(size_t size) {
        if (size>0) {
            _data=create!(ubyte[])(size);
        }
    }
    private void append(scope const(ubyte[]) add, size_t* index) {
        if (_data is null) {
            const new_size=(add.length < DEFAULT_SIZE)?DEFAULT_SIZE:add.length;
            _data=create!(ubyte[])(new_size);
        }
        scope(exit) {
            *index+=add.length;
        }
        if (*index+add.length > _data.length) {
            const new_size=_data.length+((add.length < DEFAULT_SIZE)?DEFAULT_SIZE:add.length);
            _data.resize(new_size);
        }
        _data[*index..*index+add.length]=add;
    }


    void write(T)(const T x, size_t* index) if (isNumeric!T || is(Unqual!(T)==bool)) {
        const res=nativeToLittleEndian(x);
        append(res, index);
    }

    void write(const(ubyte[]) x, size_t* index) {
        append(x, index);
    }
    void write(T)(T x, size_t* index) if(isArray!T) {
        append(cast(ubyte[])x, index);
    }
    void write(T)(T x) {
        write(x, &_index);
    }
    void write(T)(T x, const size_t index) {
        size_t temp_index=index;
        write(x, &temp_index);
    }
    void dispose() {
        free(_data.ptr);
        scope(exit) {
            _data=null;
            _index=0;
        }
    }
    BinBuffer opSlice(const size_t from, const size_t to)
        in {
            assert(from<=to);
            assert(to <= _data.length);
        }
    do {
        auto result=Buffer(to-from);
        result.write(_data[from..to]);
        return opSlice;
    }

    immutable(ubyte[]) serialize() const {
        auto result=_data[0.._index];
        return assumeUnique(result);
    }
    ~this() {
        dispose;
    }
}


unittest {
    BinBuffer buf;
    buf.write(10);
    buf.write(10.0);
    buf.write("test");
    ubyte x=7;
    buf.write(x);

}
