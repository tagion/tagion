module tagion.wallet.BIP39;

import tagion.basic.Version : ver;
import tagion.basic.Debug;
import tagion.utils.Miscellaneous : toHexString;

static assert(ver.LittleEndian, "At the moment bip39 only supports Little Endian");

@trusted
ubyte[] bip39(const(ushort[]) mnemonics) pure nothrow {
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
    return digest!SHA256(cast(ubyte[]) result_buffer).dup;
}

/*
https://github.com/bitcoin/bips/blob/master/bip-0039.mediawikiP
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
    this(string[] list)
    in (list.length == 2048)
    do {
        table = list
            .enumerate!ushort
            .map!(w => tuple!("index", "value")(w.value, w.index))
            .assocArray;

    }

    const(ushort[]) list(const(string[]) mnemonics) {

        return mnemonics
            .map!(m => table.get(m, ushort.max))
            .array;

    }
}
