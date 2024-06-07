//\file HiBONSpecificationTest.d

/** @brief HiBON tests of the specification
 */

import tagion.hibon.HiBON;
import tagion.hibon.HiBONException;

///HiBON: protocol_verification
/// DOC: HiBON v1.0| Draft: 6d56f2
unittest {
    enum SpecType : ubyte {
        String = 0x01,
        HiBON = 0x02,
        Binary = 0x03,
        Boolean = 0x08,
        Int32 = 0x11,
        Int64 = 0x12,
        UInt32 = 0x14,
        UInt64 = 0x15,
        Float32 = 0x17,
        Float64 = 0x18,
        BigInt = 0x1A
    }

    import tagion.basic.Types : Buffer;

    //! [U8 Number Test]
    {
        Buffer expectedResult = [4, SpecType.UInt32, 0, 0, 3];
        ubyte value = 3;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U8 MIN Number Test]
    {
        Buffer expectedResult = [4, SpecType.UInt32, 0, 0, 0];
        ubyte value = 0;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U8 MAX Number Test]
    {
        Buffer expectedResult = [5, SpecType.UInt32, 0, 0, 255, 1];
        ubyte value = 255;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [Boolean MIN Number Test]
    {
        Buffer expectedResult = [4, SpecType.Boolean, 0, 0, 0];
        bool value = false;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [Boolean MAX Number Test]
    {
        Buffer expectedResult = [4, SpecType.Boolean, 0, 0, 1];
        bool value = true;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [I32 Number Test]
    {
        int value = 9000;
        Buffer expectedResult = [6, SpecType.Int32, 0, 0, 168, 198, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [I32 MAX Number Test]
    {
        int value = int.max;
        Buffer expectedResult = [8, SpecType.Int32, 0, 0, 255, 255, 255, 255, 7];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U32 MAX Number Test]
    {
        uint value = uint.max;
        Buffer expectedResult = [8, SpecType.UInt32, 0, 0, 255, 255, 255, 255, 15];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U32 MIN Number Test]
    {
        uint value = uint.min;
        Buffer expectedResult = [4, SpecType.UInt32, 0, 0, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [I64 MAX Number Test]
    {
        long value = long.max;
        Buffer expectedResult = [13, SpecType.Int64, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [I64 MIN Number Test]
    {
        long value = long.min;
        Buffer expectedResult = [13, SpecType.Int64, 0, 0, 128, 128, 128, 128, 128, 128, 128, 128, 128, 127];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U64 MAX Number Test]
    {
        ulong value = ulong.max;
        Buffer expectedResult = [13, SpecType.UInt64, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 1];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [U64 MIN Number Test]
    {
        ulong value = ulong.min;
        Buffer expectedResult = [4, SpecType.UInt64, 0, 0, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [String Len Test]
    {
        Buffer expectedResult = [7, SpecType.String, 0, 0, 3, 97, 98, 99];
        auto value = "abc";
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [Dictionary String:String Test]
    {
        auto key = "key";
        Buffer expectedResult = [
            11, SpecType.String,
            3, 107, 101, 121, // Pascal string "key"
            5, 118, 97, 108, 117, 101
        ]; // Pascal string "value"
        auto value = "value";
        auto hibon = new HiBON;
        hibon[key] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [Dictionary Impossible Key 0x22 Test]
    {
        auto flag = false;
        auto key = "'''"; //0x22, 0x22, 0x22
        auto value = "value";
        auto hibon = new HiBON;
        try {
            hibon[key] = value;
        }
        catch (HiBONException e) {
            flag = true;
        }
        assert(flag);
    }

    //! [Dictionary Impossible Key 0x27 Test]
    {
        auto flag = false;
        auto key = "\"\"\""; //0x27, 0x27, 0x27
        auto value = "value";
        auto hibon = new HiBON;
        try {
            hibon[key] = value;
        }
        catch (HiBONException e) {
            flag = true;
        }
        assert(flag);
    }

    //! [Dictionary Impossible Key 0x60 Test]
    {
        auto flag = false;
        auto key = "‘‘‘"; //0x60, 0x60, 0x60
        auto value = "value";
        auto hibon = new HiBON;
        try {
            hibon[key] = value;
        }
        catch (HiBONException e) {
            flag = true;
        }
        assert(flag);
    }

    //! [Dictionary String:Int Test]
    {
        auto key = "key";
        Buffer expectedResult = [
            6, SpecType.Int32,
            3, 107, 101, 121, // Pascal string "key"
            9
        ]; // square size of key length"
        int value = cast(int)(key.length * key.length);
        auto hibon = new HiBON;
        hibon[key] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [Array U32 Test]
    {
        uint value = 217;
        Buffer expectedResult = [10, SpecType.UInt32, 0, 0, 217, 1, SpecType.UInt32, 0, 1, 218, 1];
        auto hibon = new HiBON;
        hibon[0] = value;
        hibon[1] = value + 1;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F32 Number Test]
    {
        float value = 9000.9000;
        Buffer expectedResult = [7, SpecType.Float32, 0, 0, 154, 163, 12, 70];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F32 Negative Number Test]
    {
        float value = -5000.4000;
        Buffer expectedResult = [7, SpecType.Float32, 0, 0, 51, 67, 156, 197];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F32 MAX Number Test]
    {
        float value = float.max;
        Buffer expectedResult = [7, SpecType.Float32, 0, 0, 255, 255, 127, 127];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F32 MIN Number Test]
    {
        import core.stdc.float_;

        float value = FLT_MIN;
        Buffer expectedResult = [7, SpecType.Float32, 0, 0, 0, 0, 128, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F64 Number Test]
    {
        double value = 10005000.4000;
        Buffer expectedResult = [11, SpecType.Float64, 0, 0, 205, 204, 204, 12, 65, 21, 99, 65];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F64 Negative Number Test]
    {
        double value = -5000000.4000;
        Buffer expectedResult = [11, SpecType.Float64, 0, 0, 154, 153, 153, 25, 208, 18, 83, 193];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F64 Max Number Test]
    {
        double value = double.max;
        Buffer expectedResult = [11, SpecType.Float64, 0, 0, 255, 255, 255, 255, 255, 255, 239, 127];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F64 Min Number Test]
    {
        double value = double.min_normal;
        Buffer expectedResult = [11, SpecType.Float64, 0, 0, 0, 0, 0, 0, 0, 0, 16, 0];
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }

    //! [F64 IEEE754 Number Test]
    {
        import std.bitmanip : nativeToLittleEndian;

        double value = 42.42;
        // convert to IEEE754 byte array representation
        Buffer rawRep = value.nativeToLittleEndian.idup;
        ubyte[] expectedResult = [11, SpecType.Float64, 0, 0];
        // concat head and tail as expected result
        expectedResult = expectedResult ~ rawRep;
        auto hibon = new HiBON;
        hibon[0] = value;
        assert(hibon.serialize() == expectedResult);
    }
}
