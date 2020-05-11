module hibon.utils.BinBuffer;

extern(C):
@nogc:
import core.stdc.stdlib : calloc, malloc, realloc, free;
import std.bitmanip : nativeToLittleEndian, nativeToBigEndian;
import std.traits : isNumeric, isArray, Unqual;
import hibon.utils.Memory;
import hibon.utils.utc;

struct BinBuffer {
    @nogc:
    protected {
        ubyte[] _data;
        size_t _index;
    }

    enum DEFAULT_SIZE=256;
    this(const size_t size) {
        if (size>0) {
            _data.create(size);
        }
    }

   ~this() {
        dispose;
    }

    void dispose() {
        _data.dispose;
        scope(exit) {
            _index=0;
        }
    }

    void recreate(const size_t size) {
        if (_data !is null) {
            dispose;
        }
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

    void write(utc_t utc, size_t* index) {
        write(utc.time, index);
    }

    void write(T)(T x) {
        write(x, &_index);
    }

    void write(T)(T x, const size_t index) {
        size_t temp_index=index;
        write(x, &temp_index);
    }

    BinBuffer opSlice(const size_t from, const size_t to)
        in {
            assert(from<=to);
            assert(to <= _data.length);
        }
    do {
        auto result=BinBuffer(to-from);
        result.write(_data[from..to]);
        return result;
    }

    @property size_t length() const pure {
        return _index;
    }

    immutable(ubyte[]) serialize() const {
        return cast(immutable)_data[0.._index];
    }
}

unittest {
    string text="text";
    import core.stdc.stdio;
    auto buf=BinBuffer(100);

    buf.write(42);
    size_t size=int.sizeof;
    assert(buf.length == size);
    buf.write(10.1);
    size+=double.sizeof;
    assert(buf.length == size);
    buf.write(text);
    size+=text.length;
    assert(buf.length == size);
    ubyte x=7;
    buf.write(x);
    size+=ubyte.sizeof;
    assert(buf.length == size);
    printf("size=%d\n", size);
    assert(size == 17);

    ubyte[17] check;

    size=0;
    check[size..size+int.sizeof]=nativeToLittleEndian(42);
    size+=int.sizeof;
    check[size..size+double.sizeof]=nativeToLittleEndian(10.1);
    size+=double.sizeof;
    check[size..size+text.length]=cast(const(ubyte[]))text;
    size+=text.length;
    check[size]=x;

    foreach(i, a; buf.serialize) {
        assert(a == check[i]);
    }
    assert(check == buf.serialize);
}
