module tagion.communication.Envelope;

import std.system;
import std.range;
import std.digest.crc;
import std.bitmanip;
import std.exception;
import std.zlib;
import std.format;
import std.algorithm.searching: find, boyerMooreFinder;

import tagion.crypto.Cipher;

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

enum Schema : uint {
    none = 0,
    secp256k1_ECDH_AES256 = 2256,
}

struct Envelope {
    EnvelopeHeader header;
    const(ubyte)[] data;
    const(ubyte)[] tail;
    bool errorstate = false;
    string[] errors;
    
    static align(1) struct EnvelopeHeader {
        bool isValid() @safe pure const {
            if(magic != MagicBytes)
                return false;
            if(hdrsum != getsum())
                return false;
            return true;                    
        }
        uint compression() @safe pure const {
            return level;
        }
    
    align(4):
        
        enum ubyte[4] MagicBytes = [0xDE, 0xAD, 0xBE, 0xEF];
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
        
        ubyte[4] magic = MagicBytes;
        uint schema;
        CompressionLevel level;
        ulong datsize;
        ubyte[8] datsum;
        ubyte[4] hdrsum;

        ubyte[32] toBuffer() @safe pure const scope {
            scope ubyte[32] b = magic ~ nativeToLittleEndian(schema) ~ nativeToLittleEndian(level) ~ nativeToLittleEndian(datsize) ~ datsum ~ hdrsum;
            return b;
        }

        ubyte[4] getsum() @safe pure const scope {
            return crc32Of( magic ~ nativeToLittleEndian(schema) ~ nativeToLittleEndian(level) ~ nativeToLittleEndian(datsize) ~ datsum );
        }
        
        static EnvelopeHeader fromBuffer(const(ubyte)[] raw) @trusted pure {
            if(raw.length >= this.sizeof){
                scope ubyte[this.sizeof] head_buf = (raw[0..this.sizeof]).dup;
                EnvelopeHeader hdr = cast(EnvelopeHeader)head_buf;
                makeFromLittleEndian(hdr.level);
                makeFromLittleEndian(hdr.schema);
                makeFromLittleEndian(hdr.datsize);
                return hdr;
            } else {
                return EnvelopeHeader.init;
            }
        }
        
        this(uint schema, uint level) @safe pure {
            this.schema = schema;
            this.level = cast(CompressionLevel)level;
        }

        string toString() @safe pure const {
            return format("valid:\t%s\nschema:\t%d\nlevel:\t%d\nsize:\t%d\n"
                ,this.isValid()
                ,this.schema
                ,this.level
                ,this.datsize
                );
        }
        
    }   

    void error(string msg) @safe pure {
        this.errorstate = true;
        this.errors ~= msg;
    }

    this(uint schema, uint level, const(ubyte)[] data) @safe pure {
        this.header = EnvelopeHeader(schema, level);
        this.data = data;
        this.errorstate = false;
    }
    
    ubyte[] toBuffer() @safe {
        ubyte[] compressed;
        if(this.errorstate)
            return [];
        this.header.datsize = this.data.length;
        if(this.header.compression > 0){
            compressed = (() @trusted => compress(this.data[0..$], this.header.compression))();
            this.header.datsize = compressed.length;
            this.header.datsum = crc64ECMAOf(compressed);
        }else{
            this.header.datsum = crc64ECMAOf(this.data[0..$]);
        }
        this.header.hdrsum = this.header.getsum();
        if(this.header.compression > 0){
            return this.header.toBuffer() ~ compressed;
        } else {
            return this.header.toBuffer() ~ this.data[0..$];
        }            
    }

    this( const(ubyte)[] raw ) @safe pure {
        if(raw.length < EnvelopeHeader.sizeof){
            this.error("Buffer too short");
            return;
        }    
        auto buf = find(raw,boyerMooreFinder(cast(const(ubyte)[])EnvelopeHeader.MagicBytes));
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
        this.tail = buf[EnvelopeHeader.sizeof+dsize..$];
        auto dsum = crc64ECMAOf(this.data[0..this.data.length]);
        if(this.header.datsum != dsum){ 
            this.error("Envelope data checksum invalid");
            return;
        }
    }

    this( immutable(ubyte)[] raw ) @safe pure immutable {
        immutable(string)[] errs;
        scope(exit) {
            if(!errs.empty) {
                this.errors = errs;
                this.errorstate = true;
            }
        }

        if(raw.length < EnvelopeHeader.sizeof){
            errs ~= "Buffer too short";
            return;
        }    
        auto buf = find(raw,boyerMooreFinder(this.header.magic[0..4]));
        if(buf.empty()){
            errs  ~= "Header not found";
            return;
        }    
        this.header = EnvelopeHeader.fromBuffer(buf);
        if(!this.header.isValid){
            errs  ~= "Envelope header invalid";
            return;
        }    
        const dsize = this.header.datsize;
        if(buf.length - EnvelopeHeader.sizeof < dsize){
            errs ~= "Envelope data length invalid";
            return;
        }    
        this.data = buf[EnvelopeHeader.sizeof .. EnvelopeHeader.sizeof+dsize];
        this.tail = buf[EnvelopeHeader.sizeof+dsize..$];
        auto dsum = crc64ECMAOf(this.data[0..this.data.length]);
        if(this.header.datsum != dsum){ 
            errs ~= "Envelope data checksum invalid";
            return;
        }
    }

    const(ubyte)[] toData() @trusted const {
        return (this.errorstate) ? [] : (this.header.compression > 0) ? cast(const(ubyte)[])uncompress(this.data[0..$]) : this.data[0..$];
    }

    immutable(ubyte)[] toData() @trusted immutable {
        return (this.errorstate) ? [] : (this.header.compression > 0) ? cast(immutable(ubyte)[])uncompress(this.data[0..$]) : this.data[0..$];
    }    
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

    ubyte[] rawdata = cast(ubyte[])(
        "the quick brown fox jumps over the lazy dog\r
         the quick brown fox jumps over the lazy dog\r");
    
    Envelope e1 = Envelope(1,0,rawdata);
    ubyte[] b1 = e1.toBuffer();
    Envelope e2 = Envelope(b1);
    assert(!e2.errorstate);
    assert(e2.header.isValid);
    assert(e2.header.datsize == rawdata.length);
    assert(e2.header.schema == 1);
    const b2 = e2.toData();
    assert(b2 == rawdata);
    
    Envelope e3 = Envelope(1,9,rawdata);
    ubyte[] b3 = e3.toBuffer();
    Envelope e4 = Envelope(b3);
    assert(e4.header.isValid());
    const b4 = e4.toData();
    assert(b4 == rawdata);
    
}
    


