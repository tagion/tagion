module tagion.wallet.BIP39;

@trusted
ubyte[] bip39(const(ushort[]) mnemonic) pure nothrow {
    pragma(msg, "fixme(cbr): Fake BIP39 must be fixed later");
    import std.digest.sha : SHA256;
    import std.digest;

    return digest!SHA256(cast(ubyte[]) mnemonic).dup;
}

/*
10001111110100110100110001011001100010111110011101010000101001000000110000011001101010001100001000011101110011000100000111111100
0111

more omit biology blind insect faith corn crush search unveil away wedding

1010010001011010010011001111111000111100011110010110110111110111011110101101101010000000010001010111111001100010011010101000110000110100110011100000010001010001010100110111101110001010011010100000101011000001101000110000010110001001100011100001110011010010
01001011


picture sponsor display jump nothing wing twin exotic earth vessel one blur erupt acquire earn hunt media expect race ecology flat shove infant enact

1137e53d16d7ce04339914da41bdeb24b246f0878494f066a145f8a7f43c8264e177873c54830fa9b0cafdf5846258521b208f6d7fcd0de78ac22bf51040efde
*/

import std.range;

@safe
struct WordList {
    protected ushort[string] table;
    this(sting[] list)
    in (list.length == 2048)
    do {

        list.enumerate.each!(word => table[cast(ushort) word.index) = word.value);

            }

            const(ushort[]) list(const(char[][]) mnemonics) {
                return mnemonics
                    .map!(m => table.get(m, short.max))
                    .array;

            }
            }
