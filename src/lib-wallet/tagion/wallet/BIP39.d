module tagion.wallet.BIP39;

import std.string : representation;
import tagion.basic.Debug;
import tagion.basic.Version : ver;
import tagion.crypto.random.random;
import std.format;
import tagion.basic.tagionexceptions : Check, TagionException;
import std.uni;

/**
 * Exception type used in the BIP39 functions
 */
@safe
class BIP39Exception : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!(BIP39Exception);
static assert(ver.LittleEndian, "At the moment bip39 only supports Little Endian");

import std.algorithm;
import std.range;
import std.typecons;
import tagion.hibon.HiBONRecord;
import tagion.basic.Debug;

    
/**
 * BIP39 function collection 
 */
@safe
struct BIP39 {
    import tagion.crypto.pbkdf2;
    import std.digest.sha : SHA512, SHA256;

    alias pbkdf2_sha512 = pbkdf2!SHA512;
    const(ushort[string]) table; /// Table of all the mnemonic words
    const(string[]) words; /// Reverse lookup table of the mnemonic words
    enum presalt = "mnemonic";
    this(const(string[]) list) pure nothrow
    in (list.length == TOTAL_WORDS)
    do {
        words = list;
        table = list
            .enumerate!ushort
            .map!(w => tuple!("index", "value")(w.value, w.index))
            .assocArray;

    }

    deprecated("Should be removed when the passphrase function has been removed")
    private const(ushort[]) mnemonicNumbers(const(string[]) mnemonics) const pure {
        return mnemonics
            .map!(m => table.get(m, ushort.max))
            .array;
    }

    deprecated("Should use mnemonicToSeed instead")
    ubyte[] opCall(scope const(ushort[]) mnemonic_indices, scope const(char[]) password) const nothrow {
        scope word_list = mnemonic_indices[]
            .map!(mnemonic_code => words[mnemonic_code]);
        return opCall(word_list, password);
    }

    deprecated("Use the generateMnemonic instead")
    char[] passphrase(const uint number_of_words) const pure {
        return generateMnemonic(number_of_words).dup;
}

    enum count = 2048;
    enum dk_length = 64;
    deprecated("This should be update to use generateMnemonic and mnemonicToEntropy instead")
    ubyte[] opCall(R)(scope R mnemonics, scope const(char[]) passphrase) const nothrow if (isInputRange!R) {
        scope char[] salt = presalt ~ passphrase;
        const password_size = mnemonics.map!(m => m.length).sum + mnemonics.length - 1;
        scope password = new char[password_size];
        scope (exit) {
            password[] = 0;
            salt[] = 0;
        }
        password[] = ' ';
        uint index;
        foreach (mnemonic; mnemonics) {
            password[index .. index + mnemonic.length] = mnemonic;
            index += mnemonic.length + char.sizeof;
        }
        return pbkdf2_sha512(password.representation, salt.representation, count, dk_length);
    }

    enum MAX_WORDS = 24; /// Max number of mnemonic word in a string
    enum MNEMONIC_BITS = 11; /// Bit size of the word number 2^11=2048
    enum TOTAL_WORDS = 1 << MNEMONIC_BITS;
    enum MAX_BITS = MAX_WORDS * MNEMONIC_BITS; /// Total number of bits
    /**
     * Calculates the entropy of a list of mnemonic-indices without the checksum
     * This function should alo be used analize a mnemonic-indices list 
     * To produces a entropy the function mnemonicToEntropy should be used instead
     * Params:
     *   mnemonic_indices = list of mnemonic-indices
     * Returns: 
     *   An entropy byte array representation of the mnemonic-indices
     */
    static ubyte[] entropy(scope const(ushort[]) mnemonic_indices) pure nothrow {
        import std.bitmanip : nativeToBigEndian;
        import std.stdio;

        const total_bits = mnemonic_indices.length * MNEMONIC_BITS;
        const total_bytes = total_bits / 8 + ((total_bits & 7) != 0);
        ubyte[] result = new ubyte[total_bytes];

        foreach (i, mnemonic; mnemonic_indices) {
            const bit_pos = i * MNEMONIC_BITS;
            const byte_pos = bit_pos / 8;
            const shift_pos = 32 - (11 + (bit_pos & 7));
            const mnemonic_bytes = (uint(mnemonic) << shift_pos).nativeToBigEndian;
            result[byte_pos] |= mnemonic_bytes[0];
            result[byte_pos + 1] = mnemonic_bytes[1];
            if (mnemonic_bytes[2]) {
                result[byte_pos + 2] = mnemonic_bytes[2];
            }
        }
        return result;
    }

    /**
     * Helper function to generated the mnemonic salt 
     * Params:
     *   password = text of the password 
     * Returns: 
     *   The NFKD normalize string
     */
    static string salt(scope string password) pure {
        return normalize!NFKD(presalt ~ password);
    }

    /**
     * Reverse function of entropy
     * This function should only be used to analize an entropy buffer
     * Params:
     *   entropy_buf = byte array of an entropy buffer 
     * Returns: 
     *   an array of mnemonic-indices   
    */
    static ushort[] dentropy(scope const(ubyte)[] entropy_buf) pure nothrow {
        import std.bitmanip : bigEndianToNative, peek, Endian;

        const total_bits = entropy_buf.length * 8;
        const number_of_mnemonics = total_bits / MNEMONIC_BITS;
        entropy_buf.length = (number_of_mnemonics - 1) * MNEMONIC_BITS / 8 + uint.sizeof;
        ushort[] result;
        result.length = number_of_mnemonics;
        enum normalize_mnemonic = uint.sizeof * 8 - MNEMONIC_BITS;
        foreach (i, ref mnemonic_number; result) {
            const bit_pos = i * MNEMONIC_BITS;
            const byte_pos = bit_pos / 8;
            const shift_pos = bit_pos % 8;
            const bit_slice = (entropy_buf.peek!(uint, Endian.bigEndian)(byte_pos));
            mnemonic_number = (bit_slice << shift_pos) >> normalize_mnemonic;
        }
        return result;
    }

    /**
     * Helper function to check if the entropy length is correct 
     * Params:
     *   len = length of an entropy buffer 
     * Returns: 
     *   true of the length is correct
    */
    static bool checkEntropyLength(const size_t len) pure nothrow @nogc {
        return (len >= 16) && (len <= 32) && (len % 4 == 0);
    }

    /**
     * Helper function which appends the checksum the entropy_buf 
     * Params:
     *   entropy_buf = entropy buffer
     */
    static void addCheckSumBits(ref scope ubyte[] entropy_buf) pure nothrow
    in (checkEntropyLength(entropy_buf.length))
    do {
        auto words = dentropy(entropy_buf);
        const total_bits = entropy_buf.length * 8;
        const CS = total_bits / 32;
        const checksum = deriveChecksumBits(entropy_buf);
        entropy_buf ~= checksum;
    }

    /** 
     * Calculates the checksum of an entropy buffer
     * Params:
     *   entropy_buf = entropy buffer 
     * Returns: 
     *   checkout as a single byte 
    */
    static const(ubyte) deriveChecksumBits(scope const(ubyte[]) entropy_buf) pure nothrow scope
    in (checkEntropyLength(entropy_buf.length))
    do {
        import std.digest;

        const CS = entropy_buf.length / 4;
        const mask = ubyte.max << (8 - CS);
        const hash = entropy_buf.digest!SHA256;
        return hash[0] & mask;
    }

    /**
     * Generated the mnemonic-sentence from an entropy buffer without the salt
     * This function also generates the correct checkout (Last word of the sentence)
     * Params:
     *   entropy_buf = entropy buffer 
     * Returns:
     *   Mnemonic-sentence
     */
    string entropyToMnemonic(scope const(ubyte[]) entropy_buf) const pure {
        check(checkEntropyLength(entropy_buf.length),
                format("entropy length of %d is invalid", entropy_buf.length));
        const checksum = deriveChecksumBits(entropy_buf);
        const bits = entropy_buf ~ checksum;
        const mnemonic_indices = dentropy(bits);
        return mnemonic_indices.map!(mnemonic => words[mnemonic]).join(" ");
    }

    /**
     * The reverse function of entropyToMnemonic
     * This function converts a mnemonic sentence to an entropy buffer
     * The function also check if the words in the sentence are in the word table
     * and it check if the checksum is correct
     * if this is not the case the it throws an BIP39Exception
     * Because this function also appends the checksum to the entropy buffer
     * to reverse the mnemonic-sentence the entropyToMnemonic should called with entropy_buf[0..$-1] (without the checksum)
     * Params:
     *   mnemonic_sentence = mnemonic sentence as a text string 
     * Returns: 
     *   entropy buffer in encluding the checksum
     * 
     */
    const(ubyte[]) mnemonicToEntropy(string mnemonic_sentence) const pure {
        import std.array : split;

        auto words = mnemonic_sentence.normalize!(NFKD)
            .split!(isWhite);
        check(words.length % 3 == 0, format("The number of words in the mnemonic should be a multiple of 3 but is %d", words
                .length));
        auto mnemonic_indices = words.map!(m => table.get(m, ushort.max)).array;
        const position_of_bad_word = mnemonic_indices.countUntil!(num => num >= TOTAL_WORDS);
        check(position_of_bad_word < 0, format("Word %s number %d was invalid", words[position_of_bad_word], position_of_bad_word));
        const entropy_buf = entropy(mnemonic_indices);

        // Subtract 1 because the last bute of entropy_buf includes the checksum 
        check(checkEntropyLength(entropy_buf.length - 1),
                format("entropy length of %d is invalid", entropy_buf.length));
        const checksum = entropy_buf[$ - 1];
        const entropy_len = entropy_buf.length / uint.sizeof * uint.sizeof;
        // calculate the checksum and compare
        const newChecksum = deriveChecksumBits(entropy_buf[0 .. entropy_len]);
        check(newChecksum == checksum, format("Wrong checksum of the entropy"));
        return entropy_buf;
    }

    /**
     * Generated the 512bits seed from a mnemonic-sentence and an optional password
     * Both the mnemonic_sentence and the password are NFKD normalized.
     * Params:
     *   mnemonic_sentence = mnemonic sentence as a text string
     *   password = optional password 
     * Returns: 
     *   the seed as a 64bytes buffer
     */
    ubyte[] mnemonicToSeed(string mnemonic_sentence, string password = null) const pure {
        import tagion.crypto.pbkdf2;
        import std.digest.sha : SHA512;

        alias pbkdf2_sha512 = pbkdf2!SHA512;
        return pbkdf2_sha512(mnemonic_sentence.normalize!(NFKD).representation, salt(password).representation, count, dk_length);
    }

    /**
     * Prime function to generate a mnemonic sentence  
     * Params:
     *   number_of_words = number of word in the sentence 
     * Returns: 
     *   the mnemonic sentence
     */
    string generateMnemonic(const uint number_of_words) const pure {
        check(number_of_words % 3 == 0, "The number of words need to be multiple of 3");
        ubyte[] entropy_buf;
        entropy_buf.length = number_of_words * MNEMONIC_BITS / 8;
        getRandom(entropy_buf);
        return entropyToMnemonic(entropy_buf);
    }

    /**
     * Check if the mnemonic sentence has the correct words and the correct checksum
     * Params:
     *   mnemonic_sentence = mnemonic-sentence
     * Returns: 
     *   true if the mnemonic-sentence is correct
     */
    bool validateMnemonic(string mnemonic_sentence) const pure nothrow {
        try {
            const entropy_buf = mnemonicToEntropy(mnemonic_sentence);
            return entropy_buf[$ - 1] == deriveChecksumBits(entropy_buf[0 .. $ - 1]);
        }
        catch (Exception e) {
            return false;
        }
        assert(0);
    }
}
/** Test sample of bip39
https://learnmeabitcoin.com/technical/mnemonic
later echo alcohol essence charge eight feel sweet nephew apple aerobic device
01111101010010001011110000011000001001101010001001101000100011011101010100110110110111011001010001000001010101000001000010011110
0101
*/

///Examples: how to use the BIP39 function collection
@safe
unittest {
    import std.stdio;
    import tagion.wallet.bip39_english;
    import std.format;
    import std.string : representation;
    import tagion.hibon.HiBONtoText : decode;

    const bip39 = BIP39(words);
    { // Test of entropy and dentropy
        const(ushort[]) expected_mnemonic_codes = [1390, 1586, 604, 1202, 689, 900];
        immutable expected_entropy = "101011011101100011001001001011100100101100100101011000101110000100";
        const entropy_bytes = bip39.entropy(expected_mnemonic_codes);
        assert(expected_entropy == format("%(%011b%)", expected_mnemonic_codes));
        const dentropy_codes = bip39.dentropy(entropy_bytes);
        assert(equal(expected_mnemonic_codes, dentropy_codes));
    }
    {
        // All zeros
        auto entropy_bytes = ubyte(0).repeat(16).array; // All zeros
        const ubyte expected_checksum = 0b00110000;
        const checksum = bip39.deriveChecksumBits(entropy_bytes);
        assert(expected_checksum == checksum);
        bip39.addCheckSumBits(entropy_bytes);
        const dentropy = bip39.dentropy(entropy_bytes);

        const expected_words = ("abandon".repeat(11).array ~ "about").join(" ");
        const generated_words = dentropy.map!(no => bip39.words[no]).join(" ");
        assert(expected_words == generated_words);
        assert(entropy_bytes == bip39.mnemonicToEntropy(generated_words));

    }
    {
        // All zeros
        auto entropy_bytes = ubyte(0).repeat(32).array; // All zeros
        const ubyte expected_checksum = 0b01100110;
        //const entropy_bytes = format("
        const checksum = bip39.deriveChecksumBits(entropy_bytes);
        assert(expected_checksum == checksum);
        bip39.addCheckSumBits(entropy_bytes);
        const dentropy = bip39.dentropy(entropy_bytes);
        const expected_words = ("abandon".repeat(23).array ~ "art").join(" ");
        const generated_words = dentropy.map!(no => bip39.words[no]).join(" ");
        assert(expected_words == generated_words);
        assert(entropy_bytes == bip39.mnemonicToEntropy(generated_words));
    }
    {
        const mnemonic = [
            "punch",
            "shock",
            "entire",
            "north",
            "file",
            "identify"
        ];
        const(ushort[]) expected_mnemonic_codes = [1390, 1586, 604, 1202, 689, 900];
        immutable expected_entropy = "101011011101100011001001001011100100101100100101011000101110000100";
        const mnemonic_codes = bip39.mnemonicNumbers(mnemonic);
        assert(expected_mnemonic_codes == mnemonic_codes);
        string mnemonic_codes_bits = format("%(%011b%)", mnemonic_codes);
        assert(expected_entropy == mnemonic_codes_bits);
        const entropy = bip39.entropy(mnemonic_codes);
        string entropy_bits = format("%(%08b%)", entropy)[0 .. 11 * expected_mnemonic_codes.length];
        assert(expected_entropy == entropy_bits);
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
        const mnemonic_codes = bip39.mnemonicNumbers(mnemonic);
        string entropy_bits = format("%(%011b%)", bip39.mnemonicNumbers(mnemonic));
        assert(expected_entropy == entropy_bits);

    }
    { /// PBKDF2 BIP39
        const mnemonic = [
            "basket",
            "actual"
        ];

        import tagion.crypto.pbkdf2;
        import std.bitmanip : nativeToBigEndian;
        import std.digest.sha : SHA512;

        const mnemonic_codes = bip39.mnemonicNumbers(mnemonic);

        const entropy = bip39.entropy(mnemonic_codes);
        string mnemonic_codes_bits = format("%(%011b%)", mnemonic_codes);
        string entropy_bits = format("%(%08b%)", entropy); //[0 .. 12 * mnemonic_codes.length];
        alias pbkdf2_sha512 = pbkdf2!SHA512;
        string salt = "mnemonic"; //.representation;
        const entropy1 = "basket actual".representation;
        const result1 = pbkdf2_sha512(entropy1, salt.representation, 2048, 64);
    }

    {
    }
    /* 
    // The flowing list has been generated from
    // from nodejs using 
    // https://github.com/bitcoinjs/bip39.git 
    const bip39 = require('bip39')
    bip39.wordlists.english;
    --- the bip39_english_test_list here
    for(let i=0; i<bip39_english_test_list.length; i++) {
        const words=bip39.entropyToMnemonic(bip39_english_test_list[i][0]);
        const seed=bip39.mnemonicToSeedSync(words);
        bip39_english_test_list[i][1]=words;
        bip39_english_test_list[i][2]=seed.toString('hex');
    }
    const content= JSON.stringify(bip39_english_test_list, null, 4);
    const fs = require('node:fs');
    fs.writeFile('testvector.json', content, err => {
        if (err) {
            console.error(err);
    }
    }); 
    */
    const bip39_english_test_list = [

        [
            "00000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank yellow",
            "878386efb78845b3355bd15ea4d39ef97d179cb712b77d5c12b6be415fffeffe5f377ba02bf3f8544ab800b955e51fbff09828f682052a20faa6addbbddfb096"
        ],
        [
            "80808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage above",
            "77d6be9708c8218738934f84bbbb78a2e048ca007746cb764f0673e4b1812d176bbb173e1a291f31cf633f1d0bad7d3cf071c30e98cd0688b5bcce65ecaceb36"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong",
            "b6a6d8921942dd9806607ebc2750416b289adea669198769f2e15ed926c3aa92bf88ece232317b4ea463e84b0fcd3b53577812ee449ccc448eb45e6f544e25b6"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent",
            "4975bb3d1faf5308c86a30893ee903a976296609db223fd717e227da5a813a34dc1428b71c84a787fc51f3b9f9dc28e9459f48c08bd9578e9d1b170f2d7ea506"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal will",
            "b059400ce0f55498a5527667e77048bb482ff6daa16c37b4b9e8af70c85b3f4df588004f19812a1a027c9a51e5e94259a560268e91cd10e206451a129826e740"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter always",
            "04d5f77103510c41d610f7f5fb3f0badc77c377090815cee808ea5d2f264fdfabf7c7ded4be6d4c6d7cdb021ba4c777b0b7e57ca8aa6de15aeb9905dba674d66"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo when",
            "d2911131a6dda23ac4441d1b66e2113ec6324354523acfa20899a2dcb3087849264e91f8ec5d75355f0f617be15369ffa13c3d18c8156b97cd2618ac693f759f"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art",
            "408b285c123836004f4b8842c89324c1f01382450c0d439af345ba7fc49acf705489c6fc77dbd4e3dc1dd8cc6bc9f043db8ada1e243c4a0eafb290d399480840"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth title",
            "761914478ebf6fe16185749372e91549361af22b386de46322cf8b1ba7e92e80c4af05196f742be1e63aab603899842ddadf4e7248d8e43870a4b6ff9bf16324"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless",
            "848bbe19cad445e46f35fd3d1a89463583ac2b60b5eb4cfcf955731775a5d9e17a81a71613fed83f1ae27b408478fdec2bbc75b5161d1937aa7cdf4ad686ef5f"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote",
            "e28a37058c7f5112ec9e16a3437cf363a2572d70b6ceb3b6965447623d620f14d06bb321a26b33ec15fcd84a3b5ddfd5520e230c924c87aaa0d559749e044fef"
        ],
        [
            "77c2b00716cec7213839159e404db50d",
            "jelly better achieve collect unaware mountain thought cargo oxygen act hood bridge",
            "c7b8fbb38c1abe38dfc0fea9797804558dfac244cd7737ae3a1b619991e0ad520155d982f906629639dc39e440520f98f820bea4f886a63a45923a63441f25ef"
        ],
        [
            "b63a9c59a6e641f288ebc103017f1da9f8290b3da6bdef7b",
            "renew stay biology evidence goat welcome casual join adapt armor shuffle fault little machine walk stumble urge swap",
            "b1a1f06f175feccc998684667474b3d83efa57a0f39bb3a6cf3a3350ee7a6638ae6d15c4622c8252efe5aa319b026db1d4c91a80661ed34da1f2fb7d381224c8"
        ],
        [
            "3e141609b97933b66a060dcddc71fad1d91677db872031e85f4c015c5e7e8982",
            "dignity pass list indicate nasty swamp pool script soccer toe leaf photo multiply desk host tomato cradle drill spread actor shine dismiss champion exotic",
            "ecf9632e864630c00be4ca3d752d4f19a852cd628d9bbc3309a4c1a2f39801461a6816ca52793ddd3dacb242e207ad48e8bfde3afd0e8f978ad0e8cc4dd276c1"
        ],
        [
            "0460ef47585604c5660618db2e6a7e7f",
            "afford alter spike radar gate glance object seek swamp infant panel yellow",
            "3ddfd060236156416f8915ed6ced01c3316292aec7250434f7e32cda2338e76399874787257acad15618c81bcddd88714f8c0d316140dad809f0ca8b1a971679"
        ],
        [
            "72f60ebac5dd8add8d2a25a797102c3ce21bc029c200076f",
            "indicate race push merry suffer human cruise dwarf pole review arch keep canvas theme poem divorce alter left",
            "fe34200c8c3781f81f48d19f628a7370eb25c94c75077c9a6d4a1ef30fd9cc2f29f8ea7ef52bb765c5278413c19b7b2854b62cb3591ce4d749cd7f497da436a6"
        ],
        [
            "2c85efc7f24ee4573d2b81a6ec66cee209b2dcbd09d8eddc51e0215b0b68e416",
            "clutch control vehicle tonight unusual clog visa ice plunge glimpse recipe series open hour vintage deposit universe tip job dress radar refuse motion taste",
            "fa9ca5ef1ebfcb5e945091d413843bf7ce748d27b8b99bb5373d34b9a6b1450d2a2d7f04480904b29c78a41a6ea949288f687f72b5b8e322193a7eae8151f109"
        ],
        [
            "eaebabb2383351fd31d703840b32e9e2",
            "turtle front uncle idea crush write shrug there lottery flower risk shell",
            "4ef6e8484a846392f996b15283906b73be4ec100859ce68689d5a0fad7f761745b86d70ea5f5c43e4cc93ce4b82b3d9aeed7f85d503fac00b10ebbc150399100"
        ],
        [
            "7ac45cfe7722ee6c7ba84fbc2d5bd61b45cb2fe5eb65aa78",
            "kiss carry display unusual confirm curtain upgrade antique rotate hello void custom frequent obey nut hole price segment",
            "f0b24a453174e3c4f27634f3e2be07c069328f7cbaa24f695cbeb79a39e79f05154bddbabec57b832a46813d2e49e7b33f438e79cc566f78a3179dbce86cdd84"
        ],
        [
            "4fa1a8bc3e6d80ee1316050e862c1812031493212b7ec3f3bb1b08f168cabeef",
            "exile ask congress lamp submit jacket era scheme attend cousin alcohol catch course end lucky hurt sentence oven short ball bird grab wing top",
            "8a91a843ad4fede95f23937099a94f117115a369903603761ecabae734b5d501ddba04b1a3c9f2256437ef2d230f295d8f08676e5de93ad5190da6645ded8160"
        ],
        [
            "18ab19a9f54a9274f03e5209a2ac8a91",
            "board flee heavy tunnel powder denial science ski answer betray cargo cat",
            "22087755f76d6fb93ddd19e71106d4d4146f48424a241c0eda88787227827166223f61860d53652b635f360b5a37dd26c8aed3fa10b6f8e95be18f1913f4ca88"
        ],
        [
            "18a2e1d81b8ecfb2a333adcb0c17a5b9eb76cc5d05db91a4",
            "board blade invite damage undo sun mimic interest slam gaze truly inherit resist great inject rocket museum chief",
            "99539dbb0a15a76cdadd9cc066bae337a006823fa3439b42656fd0fca3d48afe6a0ca6f7a1d10412df611c32e18669a29bc0494de61b4c36730a5c31045464e2"
        ],
        [
            "15da872c95a13dd738fbf50e427583ad61f18fd99f628c417a61cf8343c90419",
            "beyond stage sleep clip because twist token leaf atom beauty genius food business side grid unable middle armed observe pair crouch tonight away coconut",
            "898c7388d88e3a5b3b2922a0f03f95c8e61aeadba9fa8a7b0b5629d7c98e1e0aec53f0b10fcbd4a913b4b8c985028b0026ec6fdb0a4442ee18344ca3fac4d692"
        ]
    ];
    {
        foreach (i, test_data; bip39_english_test_list) {
            const entropy_buf = test_data[0].decode;
            const expected_sentence = test_data[1];
            const expected_seed = test_data[2].decode;
            assert(bip39.validateMnemonic(expected_sentence));
            const generated_sentence = bip39.entropyToMnemonic(entropy_buf);
            assert(expected_sentence == generated_sentence);
            const generated_entropy_buf = bip39.mnemonicToEntropy(expected_sentence);
            const generated_entropy_buf_without_checksum = generated_entropy_buf[0 .. $ - 1];
            assert(entropy_buf == generated_entropy_buf_without_checksum);
            const generated_seed = bip39.mnemonicToSeed(generated_sentence);
            assert(expected_seed == generated_seed);
            const generated_checksum = bip39.deriveChecksumBits(entropy_buf);
            assert(generated_checksum == generated_entropy_buf[$ - 1]);
        }
    }

    { /// Check valid mnemonic sentences
        assert(!bip39.validateMnemonic(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"),
                "Should failed on checksum");
        assert(!bip39.validateMnemonic("abandon abandon ability"), "Word list to short");
        assert(bip39.validateMnemonic(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"),
                "Word list should be correct");

    }
}
