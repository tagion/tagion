module tagion.communication.Envelope;

import std.system;
import std.digest.crc;
import std.bitmanip;
import std.exception;
import std.zlib;

void makeBigEndian(T)(ref T value) {
    if (endian == Endian.littleEndian) {
        value = *cast(T*)nativeToBigEndian(value).ptr;
    }
}

auto bigEndian(T)(T val) pure {
    return (endian == Endian.littleEndian) ? cast(T)nativeToBigEndian(val) : val;  
}

ubyte[] i2a(T)(ref T val) {
    return (cast(ubyte*) &val)[0 .. T.sizeof];
}

struct Envelope {
    EnvelopeHeader header;
    ubyte *data;
    size_t size;
    
    static align(1) struct EnvelopeHeader {
        bool isValid() pure {
            if(magic != [0xDE, 0xAD, 0xBE, 0xEF])
                return false;
            if(hdrsum != getsum())
                return false;
            return true;                    
        }
    align(1):
        static {
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
        }
        
        ubyte[4] magic = [0xDE, 0xAD, 0xBE, 0xEF];
        uint schema;
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
        
        this(uint schema, uint level){
            this.schema = schema;
            this.level = cast(CompressionLevel)level;
        }
        
    }   

    this(uint schema, uint level, ref ubyte[] data){
        this.header = EnvelopeHeader(schema, level);
        this.data = data.ptr;
        this.size = data.length;        
    }
    
    ubyte[] toBuffer() {
        ubyte[] compressed;
        this.header.datsize = this.size;
        if(cast(uint)this.header.level > 0){
            compressed = compress(this.data[0..this.size], cast(int)this.header.level);
            this.header.datsize = compressed.length;
            this.header.datsum = crc64ECMAOf(compressed);
        }else{
            this.header.datsum = crc64ECMAOf(this.data[0..this.size]);
        }
        this.header.hdrsum = this.header.getsum();
        if(cast(uint)this.header.level > 0){
            return this.header.toBuffer() ~ compressed.dup;
        } else {
            return this.header.toBuffer() ~ this.data[0..this.size];
        }            
    }

    this ( const ubyte[] raw ) pure {
        enforce(raw.length > EnvelopeHeader.sizeof, "Envelope too short");
        this.header = EnvelopeHeader.fromBuffer(raw);
        enforce(this.header.isValid,"Envelope header invalid");
        this.data = cast(ubyte*)raw[EnvelopeHeader.sizeof..$].ptr;
        this.size = raw[EnvelopeHeader.sizeof..$].length;
        enforce(this.header.datsize == this.size, "Envelope data length invalid");
        auto ds = crc64ECMAOf(this.data[0..this.size]);
        enforce(this.header.datsum == ds, "Envelope data checksum invalid");
    }

    ubyte[] toData() {
        return  (cast(uint)this.header.level > 0) ? cast(ubyte[])uncompress(this.data[0..this.size]) : this.data[0..this.size].dup;
    }    

}


unittest {
    ubyte[] rawdata = cast(ubyte[])(
        "the quick brown fox jumps over the lazy dog\r
         the quick brown fox jumps over the lazy dog\r");
    
    Envelope e1 = Envelope(1U,0U,rawdata);
    ubyte[] b1 = e1.toBuffer();
    Envelope e2 = Envelope(b1);
    assert(e2.header.isValid());
    ubyte[] b2 = e2.toData();
    assert(b2 == rawdata);
    
    Envelope e3 = Envelope(1U,9U,rawdata);
    ubyte[] b3 = e3.toBuffer();
    Envelope e4 = Envelope(b3);
    assert(e4.header.isValid());
    ubyte[] b4 = e4.toData();
    assert(b4 == rawdata);
    
}
    


