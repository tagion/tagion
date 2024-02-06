module tagion.communication.Envelope;

import std.system;
import std.range;
import std.digest.crc;
import std.bitmanip;
import std.exception;
import std.zlib;
import std.algorithm.searching: find, boyerMooreFinder;

auto i2a(T)(ref T val) 
{
    return cast(ubyte[T.sizeof])(cast(ubyte*) &val)[0 .. T.sizeof];
}

void makeBigEndian(T)(ref T value) {
    if (endian == Endian.littleEndian) {
        value = *cast(T*)nativeToBigEndian(value).ptr;
    }
}

void makeFromBigEndian(T)(ref T value) {
    if (endian == Endian.littleEndian) {
        value = *cast(T*)bigEndianToNative!T(cast(ubyte[T.sizeof])i2a(value)).ptr;
    }
}

T bigEndian(T)(T val) pure {
    return (endian == Endian.littleEndian) ? *cast(T*)nativeToBigEndian(val).ptr : val;  
}

T fromBigEndian(T)(T val) pure {
    return (endian == Endian.littleEndian) ? bigEndianToNative!T(cast(ubyte[T.sizeof])i2a(val)) : val;  
}

// TODO: Test it with communication between little- and big endian platforms


struct Envelope {
    EnvelopeHeader header;
    ubyte[] data;
    
    static align(1) struct EnvelopeHeader {
        bool isValid() pure {
            if(magic != MagicBytes)
                return false;
            if(hdrsum != getsum())
                return false;
            return true;                    
        }
        int compression() pure {
            return fromBigEndian(cast(int)level);
        }
    
    align(4):
        
        enum : ubyte[4] { MagicBytes = [0xDE, 0xAD, 0xBE, 0xEF] } ;
        enum CompressionLevel {
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
        int schema;
        CompressionLevel level;
        ulong datsize;
        ubyte[8] datsum;
        ubyte[4] hdrsum;

        ubyte[] toBuffer() pure {
            return (magic ~ i2a(schema) ~ i2a(level) ~ i2a(datsize) ~ datsum ~ hdrsum).dup;
        }

        ubyte[] getsum() pure {
            return crc32Of( magic ~ i2a(schema) ~ i2a(level) ~ i2a(datsize) ~ datsum ).dup;
        }
        
        static EnvelopeHeader fromBuffer (const ubyte[] raw) pure {
            enforce(raw.length >= this.sizeof);
            return *(cast(EnvelopeHeader*) raw[0..this.sizeof]);
        }
        
        this(int schema, int level){
            this.schema = bigEndian(schema);
            this.level = cast(CompressionLevel)bigEndian!int(level);
        }
        
    }   

    this(int schema, int level, ref ubyte[] data){
        this.header = EnvelopeHeader(schema, level);
        this.data = data;
    }
    
    ubyte[] toBuffer() {
        ubyte[] compressed;
        this.header.datsize = bigEndian(this.data.length);
        if(this.header.compression > 0){
            compressed = compress(this.data[0..$], this.header.compression);
            this.header.datsize = bigEndian(compressed.length);
            this.header.datsum = crc64ECMAOf(compressed);
        }else{
            this.header.datsum = crc64ECMAOf(this.data[0..$]);
        }
        this.header.hdrsum = this.header.getsum();
        if(this.header.compression > 0){
            return this.header.toBuffer() ~ compressed.dup;
        } else {
            return this.header.toBuffer() ~ this.data[0..$];
        }            
    }

    this ( ubyte[] raw ) pure {
        enforce(raw.length > EnvelopeHeader.sizeof, "Envelope too short");
        auto buf = find(raw,boyerMooreFinder(cast(ubyte[])EnvelopeHeader.MagicBytes));
        enforce(!buf.empty(), "Envelope header not found");
        this.header = EnvelopeHeader.fromBuffer(buf);
        enforce(this.header.isValid,"Envelope header invalid");
        this.data = buf[EnvelopeHeader.sizeof..$];
        enforce(fromBigEndian(this.header.datsize) == this.data.length, "Envelope data length invalid");
        auto ds = crc64ECMAOf(this.data[0..this.data.length]);
        enforce(this.header.datsum == ds, "Envelope data checksum invalid");
    }

    ubyte[] toData() {
        return  (this.header.compression > 0) ? cast(ubyte[])uncompress(this.data[0..$]) : this.data[0..$];
    }    
}


unittest {
    
    ubyte[] rawdata = cast(ubyte[])(
        "the quick brown fox jumps over the lazy dog\r
         the quick brown fox jumps over the lazy dog\r");
    
    Envelope e1 = Envelope(1,0,rawdata);
    ubyte[] b1 = e1.toBuffer();
    Envelope e2 = Envelope(b1);
    assert(e2.header.isValid());
    ubyte[] b2 = e2.toData();
    assert(b2 == rawdata);
    
    Envelope e3 = Envelope(1,9,rawdata);
    ubyte[] b3 = e3.toBuffer();
    Envelope e4 = Envelope(b3);
    assert(e4.header.isValid());
    ubyte[] b4 = e4.toData();
    assert(b4 == rawdata);
    
}
    


