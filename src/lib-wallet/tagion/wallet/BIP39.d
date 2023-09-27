module tagion.wallet.BIP39;

import tagion.basic.Version : ver;
import tagion.basic.Debug;
import tagion.utils.Miscellaneous : toHexString;
import tagion.crypto.random.random;

static assert(ver.LittleEndian, "At the moment bip39 only supports Little Endian");

@trusted
ubyte[] bip39(const(ushort[]) mnemonics) nothrow {
    pragma(msg, "fixme(cbr): Fake BIP39 must be fixed later");
    import std.digest.sha : SHA256;
    import std.digest;

    enum MAX_WORDS = 24; /// Max number of mnemonic word in a string
    enum MNEMONIC_BITS = 11; /// Bit size of the word number 2^11=2048
    enum MAX_BITS = MAX_WORDS * MNEMONIC_BITS; /// Total number of bits
    enum WORK_BITS = 8 * uint.sizeof;
    enum SIZE_OF_WORK_BUFFER = (MAX_BITS / WORK_BITS) + ((MAX_BITS % WORK_BITS) ? 1 : 0);
    const total_bits = mnemonics.length * MNEMONIC_BITS;
    uint[SIZE_OF_WORK_BUFFER] work_buffer;
    ulong* work_slide = cast(ulong*)&work_buffer[0];
    uint mnemonic_pos;
    size_t work_pos;
    foreach (mnemonic; mnemonics) {
        *work_slide |= ulong(mnemonic) << mnemonic_pos;
        mnemonic_pos += MNEMONIC_BITS;
        if (mnemonic_pos >= WORK_BITS) {
            work_pos++;
            mnemonic_pos -= WORK_BITS;
            work_slide = cast(ulong*)&work_buffer[work_pos];
        }
    }

    const result_buffer = (cast(ubyte*)&work_buffer[0])[0 .. SIZE_OF_WORK_BUFFER * uint.sizeof];

    pragma(msg, "fixme(cbr): PBKDF2 hmac function should be used");

    version (HASH_SECP256K1) {
        import tagion.crypto.secp256k1.NativeSecp256k1;

        return NativeSecp256k1.calcHash(result_buffer);
    }
    else {
        return digest!SHA256(cast(ubyte[]) result_buffer).dup;

    }

}

/*
https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
10001111110100110100110001011001100010111110011101010000101001000000110000011001101010001100001000011101110011000100000111111100
0111

more omit biology blind insect faith corn crush search unveil away wedding

1010010001011010010011001111111000111100011110010110110111110111011110101101101010000000010001010111111001100010011010101000110000110100110011100000010001010001010100110111101110001010011010100000101011000001101000110000010110001001100011100001110011010010
01001011


picture sponsor display jump nothing wing twin exotic earth vessel one blur erupt acquire earn hunt media expect race ecology flat shove infant enact

1137e53d16d7ce04339914da41bdeb24b246f0878494f066a145f8a7f43c8264e177873c54830fa9b0cafdf5846258521b208f6d7fcd0de78ac22bf51040efde
*/

import std.range;
import std.algorithm;
import std.typecons;
import tagion.hibon.HiBONRecord;

@safe
struct WordList {
    protected ushort[string] table;
    this(const(string[]) list)
    in (list.length == 2048)
    do {
        table = list
            .enumerate!ushort
            .map!(w => tuple!("index", "value")(w.value, w.index))
            .assocArray;

    }

    void gen(ref scope ushort[] words) const {
        foreach (ref word; words) {
            word = getRandom!ushort & 0x800;
        }
    }

    const(ushort[]) opCall(const(string[]) mnemonics) const {

        return mnemonics
            .map!(m => table.get(m, ushort.max))
            .array;

    }

    @trusted
    ubyte[] entropy(const(ushort[]) mnemonic_codes) const {
        import std.bitmanip : nativeToBigEndian, nativeToLittleEndian;
        import std.stdio;

        enum MAX_WORDS = 24; /// Max number of mnemonic word in a string
        enum MNEMONIC_BITS = 11; /// Bit size of the word number 2^11=2048
        enum MAX_BITS = MAX_WORDS * MNEMONIC_BITS; /// Total number of bits
        enum WORK_BITS = 8 * uint.sizeof;
        enum SIZE_OF_WORK_BUFFER = (MAX_BITS / WORK_BITS) + ((MAX_BITS % WORK_BITS) ? 1 : 0);
        const total_bits = mnemonic_codes.length * MNEMONIC_BITS;
        uint[] work_buffer = new uint[SIZE_OF_WORK_BUFFER];
        ulong* work_slide = cast(ulong*)&work_buffer[0];
        uint mnemonic_pos;
        size_t work_pos;
        ubyte[] result = new ubyte[32];
        foreach (i, mnemonic; mnemonic_codes) {
            const bit_pos = i * MNEMONIC_BITS;
            const byte_pos = bit_pos / 8;
            const shift_pos = 32 - (11 + (bit_pos & 7)); // & 7; //+MNEMONIC_BITS) & 15));
            //const mnemonic_bytes=mnemonic.nativeToBigEndian;
            const mnemonic_bytes = (uint(mnemonic) << shift_pos).nativeToBigEndian;
            pragma(msg, "mnemonic_bytes ", typeof(mnemonic_bytes));
            writefln("byte_pos = %d, bit_pos = %d, shift_pos = %d", byte_pos, bit_pos, shift_pos);
            writefln("mnemonic       %011b", mnemonic);
            writefln("mnemonic_bytes %(%08b %) %2$04x %2$s", mnemonic_bytes, mnemonic);
            // writefln("mnemonic_bytes %032b", mnemonic_bytes[0] << 8 | mnemonic_bytes[1]);
            *work_slide |= (ulong(mnemonic_bytes[0]) << 8 | ulong(mnemonic_bytes[1])) << mnemonic_pos;
            writefln("slice          %032b", *work_slide);
            writefln("slice          %(%08b %)",
                    (cast(ubyte*)&work_buffer[0])[0 .. 4]);

            result[byte_pos] |= mnemonic_bytes[0];
            result[byte_pos + 1] = mnemonic_bytes[1];
            if (byte_pos + 2 < result.length) {
                result[byte_pos + 2] = mnemonic_bytes[2];

            }
            version (none)
                foreach (mnemonic_index, mnemonic_byte; mnemonic_bytes[0 .. 3]) {
                result[byte_pos + mnemonic_index] |= mnemonic_byte;
            }
            writefln("new slice      %(%08b %)", result[0 .. 6]);
            mnemonic_pos += MNEMONIC_BITS;
            if (mnemonic_pos >= WORK_BITS) {
                work_pos++;
                mnemonic_pos -= WORK_BITS;
                work_slide = cast(ulong*)&work_buffer[work_pos];
            }
        }

        return (cast(ubyte*)&work_buffer[0])[0 .. SIZE_OF_WORK_BUFFER * uint.sizeof];

    }

}

/*
https://learnmeabitcoin.com/technical/mnemonic
later echo alcohol essence charge eight feel sweet nephew apple aerobic device
01111101010010001011110000011000001001101010001001101000100011011101010100110110110111011001010001000001010101000001000010011110
0101
*/

@safe
unittest {
    import std.stdio;
    import tagion.wallet.bip39_english;
    import std.format;

    const wordlist = WordList(words);
    {
        const mnemonic = [
            "punch", "shock", "entire", "north", "file",
            "identify" /*    
        "echo",
            "alcohol",

            "essence",
            "charge",
            "eight",
            "feel",
            "sweet",
            "nephew",
            "apple",
            "aerobic",
            "device"
        */
        ];
        const(ushort[]) mnemonic_code = [1390, 1586, 604, 1202, 689, 900];
        immutable expected_entropy = "101011011101100011001001001011100100101100100101011000101110000100";
        assert(wordlist(mnemonic) == mnemonic_code);
        const mnemonic_codes = wordlist(mnemonic);
        writefln("%(%d %)", mnemonic_codes);
        writefln("%(%011b%)", mnemonic_codes);
        writefln("%s", expected_entropy);
        string mnemonic_codes_bits = format("%(%011b%)", mnemonic_codes);
        assert(expected_entropy == mnemonic_codes_bits);
        const entropy = wordlist.entropy(mnemonic_codes);
        string entropy_bits = format("%(%b%)", entropy); //[0 .. 12 * mnemonic_code.length];
        writefln("%s", entropy_bits);
        //        assert(expected_entropy == entropy_bits);

        //        const =0 
    }
    {
        const mnemonic = [
            "later",
            "echo",
            "alcohol",

            "essence",
            "charge",
            "eight",
            "feel",
            "sweet",
            "nephew",
            "apple",
            "aerobic",
            "device"
        ];
        //        const(ushort[]) mnemonic_code =[1390, 1586, 604, 1202, 689, 900];
        immutable expected_entropy = "011111010100100010111100000110000010011010100010011010001000110111010101001101101101110110010100010000010101010000010000100111100101";
        //assert(wordlist(mnemonic) == mnemonic_code);
        writefln("%(%d %)", wordlist(mnemonic));
        writefln("%(%011b%)", wordlist(mnemonic));
        writefln("%s", expected_entropy);
        string entropy_bits = format("%(%011b%)", wordlist(mnemonic));
        assert(expected_entropy == entropy_bits);

    }
    { /// PBKDF2 BIP39
        const mnemonic = [
            //"basket"//, "actual"
            "nephew",
        ];

        writefln("%(%d %)", wordlist(mnemonic));
        import tagion.pbkdf2.pbkdf2;
        import std.digest.sha : SHA512;
        import std.bitmanip : nativeToBigEndian;

        const mnemonic_codes = wordlist(mnemonic);

        const entropy = wordlist.entropy(mnemonic_codes);
        string mnemonic_codes_bits = format("%(%011b%)", mnemonic_codes);
        string entropy_bits = format("%(%08b %)", entropy); //[0 .. 12 * mnemonic_codes.length];
        writefln("%s", mnemonic_codes_bits);
        writefln("%s", entropy_bits);
        writefln("%(%02x %)", entropy);
        writefln("%s", mnemonic_codes[0].nativeToBigEndian);

        //        alias pbkdf2_sha512 = pbkdf2!SHA512;
        //5cf2d4a8b0355e90295bdfc565a022a409af063d5365bb57bf74d9528f494bfa4400f53d8349b80fdae44082d7f9541e1dba2b003bcfec9d0d53781ca676651f
    }

}
