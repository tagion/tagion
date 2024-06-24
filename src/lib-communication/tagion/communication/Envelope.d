module tagion.communication.Envelope;

import std.system;
import std.range;
import std.digest.crc;
import std.bitmanip;
import std.exception;
import std.zlib;
import std.format;
import std.algorithm.searching: find, boyerMooreFinder;

auto i2a(T)(const ref T val, bool asis = false) scope pure
{
    return (endian == Endian.bigEndian && !asis) ?
        nativeToLittleEndian!T(val) : cast(ubyte[T.sizeof])(cast(ubyte*) &val)[0 .. T.sizeof];
}

void makeFromLittleEndian(T)(scope ref T value) scope pure {
    if (endian == Endian.bigEndian) {
        value = littleEndianToNative!T(cast(ubyte[T.sizeof])i2a!T(value, true));
    }
}

T fromLittleEndian(T)(T val) @safe pure {
    return (endian == Endian.bigEndian) ? littleEndianToNative!T(cast(ubyte[T.sizeof])i2a!T(val, true)) : val;  
}
    
T fromBigEndian(T)(T val) pure {
    return (endian == Endian.bigEndian) ? bigEndianToNative!T(cast(ubyte[T.sizeof])i2a!T(val, true)) : val;  
}


// TODO: Test it with communication between little- and big endian platforms

// TODO: Add sequence number to handle chunked envelopes

static assert(ushort.sizeof + ushort.sizeof == uint.sizeof);


///
@safe
struct Envelope {
    EnvelopeHeader header;
    immutable(ubyte)[] data;
    immutable(ubyte)[] tail;
    bool errorstate = false;
    string[] errors;
    
    ///
    static align(1)
    struct EnvelopeHeader {
        bool isValid()  pure const {
            if(magic != MagicBytes)
                return false;
            if(hdrsum != getsum())
                return false;
            return true;                    
        }
        uint compression()  pure const {
            return level;
        }
    
    align(4):
        
        ///
        enum ubyte[4] MagicBytes = [0xDE, 0xAD, 0xBE, 0xEF];
        ///
        enum CompressionLevel : uint {
            none  = 0,
            zlib1 = 1,
            zlib2 = 2,
            zlib3 = 3,
            zlib4 = 4,
            zlib5 = 5,
            zlib6 = 6,
            zlib7 = 7,
            zlib8 = 8,
            zlib9 = 9,
        }
        
        immutable ubyte[4] magic = MagicBytes;  /// 4 byte magic
        uint schema;                            /// 4 byte schema/version
        CompressionLevel level;                 /// 4 byte CompressionLevel
        ulong datsize;                          /// 8 byte payload size
        ubyte[8] datsum;                        /// crc64 data checksum
        ubyte[4] hdrsum;                        /// crc32 header checksum

        static assert(this.sizeof == 32);

        ubyte[32] toBuffer() pure const scope {
            scope ubyte[32] b = magic ~ nativeToLittleEndian(schema) ~ nativeToLittleEndian(level) ~ nativeToLittleEndian(datsize) ~ datsum ~ hdrsum;
            return b;
        }

        ubyte[4] getsum() pure const scope {
            return crc32Of( magic ~ nativeToLittleEndian(schema) ~ nativeToLittleEndian(level) ~ nativeToLittleEndian(datsize) ~ datsum );
        }
        
        static EnvelopeHeader fromBuffer(const(ubyte)[] raw) @trusted pure {
            if(raw.length >= this.sizeof){
                scope ubyte[this.sizeof] head_buf = (raw[0..this.sizeof]).dup;
                EnvelopeHeader hdr = cast(EnvelopeHeader)head_buf;
                makeFromLittleEndian(hdr.schema);
                makeFromLittleEndian(hdr.level);
                makeFromLittleEndian(hdr.datsize);
                return hdr;
            } else {
                return EnvelopeHeader.init;
            }
        }
        
        this(uint schema, uint level) pure {
            this.schema = schema;
            static assert(level.sizeof == CompressionLevel.sizeof);
            this.level = cast(CompressionLevel)level;
        }

        string toString() pure const {
            return format("valid:\t%s\nschema:\t%d\nlevel:\t%d\nsize:\t%d\n"
                ,this.isValid()
                ,this.schema
                ,this.level
                ,this.datsize
                );
        }
        
    }   

    void error(string msg) pure {
        this.errorstate = true;
        this.errors ~= msg;
    }

    this(uint schema, uint level, immutable(ubyte)[] data)  pure {
        this.header = EnvelopeHeader(schema, level);
        this.data = data;
        this.errorstate = false;
    }

    immutable(ubyte)[] toBuffer()  {
        immutable(ubyte)[] result_data = this.data;
        if(this.errorstate)
            return [];
        if(this.header.compression > 0){
            result_data = (() @trusted => cast(immutable)compress(result_data, this.header.compression))();
        }
        this.header.datsize = result_data.length;
        this.header.datsum = crc64ECMAOf(result_data);
        this.header.hdrsum = this.header.getsum();
        immutable buf_header = this.header.toBuffer();
        return buf_header ~ result_data;
    }

    this( immutable(ubyte)[] raw ) pure {
        if(raw.length < EnvelopeHeader.sizeof){
            this.error("Buffer too short");
            return;
        }    
        auto buf = find(raw,boyerMooreFinder(cast(immutable(ubyte)[])this.header.magic));
        if(buf.empty()){
            this.error("Header not found");
            return;
        }    
        this.header = EnvelopeHeader.fromBuffer(buf);
        if(!this.header.isValid){
            this.error("Envelope header invalid");
            return;
        }    
        const dsize = this.header.datsize;
        if(buf.length - EnvelopeHeader.sizeof < dsize){
            this.error("Envelope data length invalid");
            return;
        }    
        this.data = buf[EnvelopeHeader.sizeof .. EnvelopeHeader.sizeof+dsize];
        this.tail = buf[EnvelopeHeader.sizeof+dsize .. $];
        auto dsum = crc64ECMAOf(this.data[0..this.data.length]);
        if(this.header.datsum != dsum){ 
            this.error("Envelope data checksum invalid");
            return;
        }
    }

    immutable(ubyte)[] toData() @trusted const {
        return (this.errorstate)? [] : (this.header.compression > 0) ? cast(immutable(ubyte)[])uncompress(this.data[0..$]) : this.data[0..$];
    }    
}

///
unittest {
 
    pragma(msg, "Envelope: TODO: make test for endian change case ");
    
    uint x1 = 12345;
    uint x2 = x1;
    uint x3 = 0;
    uint x4 = x1;
    
    static if (endian == Endian.littleEndian) {
        makeFromBigEndian!uint(x2);
        x3 = x2;
        makeBigEndian!uint(x3);
        makeFromLittleEndian!uint(x4);
        makeLittleEndian!uint(x4);
    } else {        
        makeFromLittleEndian!uint(x2);
        x3 = x2;
        makeLittleEndian!uint(x3);
        makeFromBigEndian!uint(x4);
        makeBigEndian!uint(x4);
    }    
    assert(x1 != x2);
    assert(x1 == x3);
    assert(x4 == x1);

    immutable rawdata = cast(immutable(ubyte)[])(
        "the quick brown fox jumps over the lazy dog\r
         the quick brown fox jumps over the lazy dog\r");
    
    Envelope e1 = Envelope(1,0,rawdata);
    immutable b1 = e1.toBuffer();
    Envelope e2 = Envelope(b1);
    assert(!e2.errorstate, e2.errors[0]);
    assert(e2.header.isValid);
    assert(e2.header.datsize == rawdata.length);
    assert(e2.header.schema == 1);
    const b2 = e2.toData();
    assert(b2 == rawdata);
    
    Envelope e3 = Envelope(1,9,rawdata);
    immutable b3 = e3.toBuffer();
    Envelope e4 = Envelope(b3);
    assert(e4.header.isValid());
    const b4 = e4.toData();
    assert(b4 == rawdata);
}

version(unittest) {
    T littleEndian(T)(T val) pure {
        return (endian == Endian.bigEndian) ? *cast(T*)nativeToLittleEndian(val).ptr : val;  
    }

    void makeBigEndian(T)(ref T value) {
        if (endian == Endian.littleEndian) {
            value = *cast(T*)nativeToBigEndian(value).ptr;
        }
    }

    void makeLittleEndian(T)(ref T value) {
        if (endian == Endian.bigEndian) {
            value = *cast(T*)nativeToLittleEndian(value).ptr;
        }
    }

    void makeFromBigEndian(T)(ref T value) {
        if (endian == Endian.littleEndian) {
            value = bigEndianToNative!T(cast(ubyte[T.sizeof])i2a!T(value));
        }
    }

    T bigEndian(T)(T val) pure {
        return (endian == Endian.littleEndian) ? *cast(T*)nativeToBigEndian(val).ptr : val;  
    }

}
