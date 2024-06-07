module tagion.crypto.aes.tiny_aes.tiny_aes;
/*

  This is an implementation of the AES algorithm, specifically ECB, CTR and CBC mode.
  Block size can be chosen in aes.h - available choices are AES128, AES192, AES256.

  The implementation is verified against the test vectors in:
  National Institute of Standards and Technology Special Publication 800-38A 2001 ED

  ECB-AES128
  ----------

  plain-text:
  6bc1bee22e409f96e93d7e117393172a
  ae2d8a571e03ac9c9eb76fac45af8e51
  30c81c46a35ce411e5fbc1191a0a52ef
  f69f2445df4f9b17ad2b417be66c3710

  key:
  2b7e151628aed2a6abf7158809cf4f3c

  resulting cipher
  3ad77bb40d7a3660a89ecaf32466ef97
  f5d3d58503b9699de785895a96fdbaaf
  43b1cd7f598ece23881b00e3ed030688
  7b0c785e27e8ad3f8223207104725dd4


  NOTE:   String length must be evenly divisible by 16byte (str_len % 16 == 0)
  You should pad the end of the string with zeros if this is not the case.
  For AES192/256 the key size is proportionally larger.

*/

//version = PRINT;

/+
The different modes is explained in
https://www.highgo.ca/2019/08/08/the-difference-in-five-modes-in-the-aes-encryption-algorithm/
+/
enum Mode {
    ECB, /// mode: Electronic Code Book mode
    CBC, /// mode: Cipher Block Chaining mode
    CFB, /// mode: Cipher FeedBack mode
    //    OFB, /// mode: Output FeedBack mode
    CTR /// mode: Counter mode

}

@safe @nogc
struct Tiny_AES(int KEY_LENGTH, Mode mode = Mode.CBC) {
    pure nothrow {
        enum KEY_SIZE = KEY_LENGTH >> 3;
        enum BLOCK_SIZE = 16; // Block length in bytes - AES is 128b block only

        enum Nb = 4;
        static if (KEY_LENGTH is 256) {
            enum Nk = 8;
            enum Nr = 14;
            enum keyExpSize = 240;

        }
        else static if (KEY_LENGTH is 192) {
            enum Nk = 6;
            enum Nr = 12;
            enum keyExpSize = 208;

        }
        else static if (KEY_LENGTH is 128) {
            enum Nk = 4; // The number of 32 bit words in a key.
            enum Nr = 10; // The number of rounds in AES Cipher.
            enum keyExpSize = 176;
        }

        struct Context {
            ubyte[keyExpSize] round_key;
            static if (mode !is Mode.ECB) {
                ubyte[BLOCK_SIZE] Iv;
            }
        }

        // jcallan@github points out that declaring Multiply as a function
        // reduces code size considerably with the Keil ARM compiler.
        // See this link for more information: https://github.com/kokke/tiny-AES-C/pull/3
        // #ifndef MULTIPLY_AS_A_FUNCTION
        //   #define MULTIPLY_AS_A_FUNCTION 0
        // #endif

        /*****************************************************************************/
        /* Private variables:                                                        */
        /*****************************************************************************/
        // state - array holding the intermediate results during decryption.
        alias state_t = ubyte[4][4];
        union State {
            state_t* state_p;
            protected ubyte* buf_p;
            @trusted
            static ref state_t opCall(ref return scope ubyte[] buf)
            in {
                assert(buf.length >= state_t.sizeof);
            }
            do {
                State state;
                state.buf_p = buf.ptr;
                return *state.state_p;
            }

            @trusted
            static ref state_t opCall(ref return scope ubyte[BLOCK_SIZE] buf) {
                State state;
                state.buf_p = cast(ubyte*)&buf;
                return *state.state_p;
            }

            static assert(state_t.sizeof is BLOCK_SIZE);
        }

        // The lookup-tables are marked const so they can be placed in read-only storage instead of RAM
        // The numbers below can be computed dynamically trading ROM for RAM -
        // This can be useful in (embedded) bootloader applications, where ROM is often limited.
        shared static immutable(ubyte[256]) sbox;
        shared static immutable(ubyte[256]) rsbox;
        shared static this() {
            // The sbox was changed to from enum to immutable because of some odd segment fault
            sbox = [
                //0     1    2      3     4    5     6     7      8    9     A      B    C     D     E     F
                0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67,
                0x2b, 0xfe, 0xd7, 0xab, 0x76,
                0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2,
                0xaf, 0x9c, 0xa4, 0x72, 0xc0,
                0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5,
                0xf1, 0x71, 0xd8, 0x31, 0x15,
                0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80,
                0xe2, 0xeb, 0x27, 0xb2, 0x75,
                0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6,
                0xb3, 0x29, 0xe3, 0x2f, 0x84,
                0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe,
                0x39, 0x4a, 0x4c, 0x58, 0xcf,
                0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02,
                0x7f, 0x50, 0x3c, 0x9f, 0xa8,
                0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda,
                0x21, 0x10, 0xff, 0xf3, 0xd2,
                0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e,
                0x3d, 0x64, 0x5d, 0x19, 0x73,
                0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8,
                0x14, 0xde, 0x5e, 0x0b, 0xdb,
                0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac,
                0x62, 0x91, 0x95, 0xe4, 0x79,
                0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4,
                0xea, 0x65, 0x7a, 0xae, 0x08,
                0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74,
                0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
                0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57,
                0xb9, 0x86, 0xc1, 0x1d, 0x9e,
                0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87,
                0xe9, 0xce, 0x55, 0x28, 0xdf,
                0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d,
                0x0f, 0xb0, 0x54, 0xbb, 0x16
            ];
            static immutable(ubyte[256]) _reverse_sbox() {
                ubyte[256] result;
                static foreach (i; 0 .. 256) {
                    result[sbox[i]] = i;
                }
                return result;
            }
            // Generate the reverse sbox
            rsbox = _reverse_sbox();
        }

        // The round constant word array, Rcon[i], contains the values given by
        // x to the power (i-1) being powers of x (x is denoted as {02}) in the field GF(2^8)
        enum Rcon = cast(ubyte[11])[
                0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
            ];

        /*
 * Jordan Goulder points out in PR #12 (https://github.com/kokke/tiny-AES-C/pull/12),
 * that you can remove most of the elements in the Rcon array, because they are unused.
 *
 * From Wikipedia's article on the Rijndael key schedule @ https://en.wikipedia.org/wiki/Rijndael_key_schedule#Rcon
 *
 * "Only the first some of these constants are actually used – up to rcon[10] for AES-128 (as 11 round keys are needed),
 *  up to rcon[8] for AES-192, up to rcon[7] for AES-256. rcon[0] is not used in AES algorithm."
 */

        // This function produces Nb(Nr+1) round keys. The round keys are used in each round to decrypt the states.
        private void keyExpansion(ref const(ubyte[KEY_SIZE]) Key) {
            ubyte[4] tempa; // Used for the column/row operations
            foreach (i; 0 .. Nk) {
                static foreach (j; 0 .. 4) {
                    ctx.round_key[(i * 4) + j] = Key[(i * 4) + j];
                }
            }
            // All other round keys are found from the previous round keys.
            static foreach (i; Nk .. Nb * (Nr + 1)) {
                static foreach (j; 0 .. 4) {
                    {
                        const k = (i - 1) * 4;
                        tempa[j] = ctx.round_key[k + j];
                    }
                }

                if (i % Nk == 0) {
                    // This function shifts the 4 bytes in a word to the left once.
                    // [a0,a1,a2,a3] becomes [a1,a2,a3,a0]

                    // Function RotWord()
                    {
                        const ubyte u8tmp = tempa[0];
                        tempa[0] = tempa[1];
                        tempa[1] = tempa[2];
                        tempa[2] = tempa[3];
                        tempa[3] = u8tmp;
                    }

                    // SubWord() is a function that takes a four-byte input word and
                    // applies the S-box to each of the four bytes to produce an output word.

                    // Function Subword()
                    static foreach (j; 0 .. 4) {
                        tempa[j] = sbox[tempa[j]];
                    }

                    tempa[0] = tempa[0] ^ Rcon[i / Nk];
                }
                static if (KEY_LENGTH == 256) {
                    if (i % Nk is 4) {
                        // Function Subword()
                        static foreach (j; 0 .. 4) {
                            tempa[j] = sbox[tempa[j]];
                        }
                    }
                }
                {
                    const j = i * 4;
                    const k = (i - Nk) * 4;
                    static foreach (l; 0 .. 4) {
                        ctx.round_key[j + l] = ctx.round_key[k + l] ^ tempa[l];
                    }
                }
            }
        }

        Context ctx;
        static if (mode is Mode.ECB) {
            this(ref const(ubyte[KEY_SIZE]) key) {
                keyExpansion(key);
            }
        }
        else {
            this(ref const(ubyte[KEY_SIZE]) key, ref const(ubyte[BLOCK_SIZE]) iv) {
                keyExpansion(key);
                ctx.Iv = iv;
            }

            void iv(ref const(ubyte[BLOCK_SIZE]) iv) {
                ctx.Iv = iv;
            }
        }

        private {
            // This function adds the round key to state.
            // The round key is added to the state by an XOR function.
            void addRoundKey(ubyte round, ref scope state_t state) const {
                static foreach (i; 0 .. 4) {
                    static foreach (j; 0 .. 4) {
                        state[i][j] ^= ctx.round_key[(round * Nb * 4) + (i * Nb) + j];
                    }
                }
            }

            // The SubBytes Function Substitutes the values in the
            // state matrix with values in an S-box.
            static void SubBytes(ref scope state_t state) {
                static foreach (i; 0 .. 4) {
                    static foreach (j; 0 .. 4) {
                        state[j][i] = sbox[state[j][i]];
                    }
                }
            }

            // The ShiftRows() function shifts the rows in the state to the left.
            // Each row is shifted with different offset.
            // Offset = Row number. So the first row is not shifted.
            static void ShiftRows(ref scope state_t state) {
                ubyte temp;
                // Rotate first row 1 columns to left
                temp = state[0][1];
                state[0][1] = state[1][1];
                state[1][1] = state[2][1];
                state[2][1] = state[3][1];
                state[3][1] = temp;

                // Rotate second row 2 columns to left
                temp = state[0][2];
                state[0][2] = state[2][2];
                state[2][2] = temp;

                temp = state[1][2];
                state[1][2] = state[3][2];
                state[3][2] = temp;

                // Rotate third row 3 columns to left
                temp = state[0][3];
                state[0][3] = state[3][3];
                state[3][3] = state[2][3];
                state[2][3] = state[1][3];
                state[1][3] = temp;
            }

            static ubyte xtime(ubyte x) {
                return ((x << 1) ^ (((x >> 7) & 1) * 0x1b)) & ubyte.max;
            }

            // MixColumns function mixes the columns of the state matrix
            static void MixColumns(ref scope state_t state) {
                ubyte Tmp, Tm;
                static foreach (i; 0 .. 4) {
                    {
                        const t = state[i][0];
                        Tmp = state[i][0] ^ state[i][1] ^ state[i][2] ^ state[i][3];
                        Tm = state[i][0] ^ state[i][1];
                        Tm = xtime(Tm);
                        state[i][0] ^= Tm ^ Tmp;
                        Tm = state[i][1] ^ state[i][2];
                        Tm = xtime(Tm);
                        state[i][1] ^= Tm ^ Tmp;
                        Tm = state[i][2] ^ state[i][3];
                        Tm = xtime(Tm);
                        state[i][2] ^= Tm ^ Tmp;
                        Tm = state[i][3] ^ t;
                        Tm = xtime(Tm);
                        state[i][3] ^= Tm ^ Tmp;
                    }
                }
            }

            // Multiply is used to multiply numbers in the field GF(2^8)
            // Note: The last call to xtime() is unneeded, but often ends up generating a smaller binary
            //       The compiler seems to be able to vectorize the operation better this way.
            //       See https://github.com/kokke/tiny-AES-c/pull/34
            static ubyte Multiply(ubyte x, ubyte y) {
                return (((y & 1) * x) ^
                        ((y >> 1 & 1) * xtime(x)) ^
                        ((y >> 2 & 1) * xtime(xtime(x))) ^
                        ((y >> 3 & 1) * xtime(xtime(xtime(x)))) ^
                        ((y >> 4 & 1) * xtime(xtime(xtime(xtime(x))))));
                /* this last call to xtime() can be omitted */
            }

            //    static ubyte getSBoxInvert(ubyte num) {return rsbox[num];};

            // MixColumns function mixes the columns of the state matrix.
            // The method used to multiply may be difficult to understand for the inexperienced.
            // Please use the references to gain more information.
            static void InvMixColumns(ref scope state_t state) {
                static foreach (i; 0 .. 4) {
                    {
                        const a = state[i][0];
                        const b = state[i][1];
                        const c = state[i][2];
                        const d = state[i][3];

                        state[i][0] = Multiply(a, 0x0e) ^ Multiply(b, 0x0b) ^ Multiply(c, 0x0d) ^ Multiply(d, 0x09);
                        state[i][1] = Multiply(a, 0x09) ^ Multiply(b, 0x0e) ^ Multiply(c, 0x0b) ^ Multiply(d, 0x0d);
                        state[i][2] = Multiply(a, 0x0d) ^ Multiply(b, 0x09) ^ Multiply(c, 0x0e) ^ Multiply(d, 0x0b);
                        state[i][3] = Multiply(a, 0x0b) ^ Multiply(b, 0x0d) ^ Multiply(c, 0x09) ^ Multiply(d, 0x0e);
                    }
                }
            }

            // The SubBytes Function Substitutes the values in the
            // state matrix with values in an S-box.
            static void InvSubBytes(ref scope state_t state) {
                static foreach (i; 0 .. 4) {
                    static foreach (j; 0 .. 4) {
                        state[j][i] = rsbox[state[j][i]];
                    }
                }
            }

            static void InvShiftRows(ref scope state_t state) {
                ubyte temp;

                // Rotate first row 1 columns to right
                temp = state[3][1];
                state[3][1] = state[2][1];
                state[2][1] = state[1][1];
                state[1][1] = state[0][1];
                state[0][1] = temp;

                // Rotate second row 2 columns to right
                temp = state[0][2];
                state[0][2] = state[2][2];
                state[2][2] = temp;

                temp = state[1][2];
                state[1][2] = state[3][2];
                state[3][2] = temp;

                // Rotate third row 3 columns to right
                temp = state[0][3];
                state[0][3] = state[1][3];
                state[1][3] = state[2][3];
                state[2][3] = state[3][3];
                state[3][3] = temp;
            }

            // Cipher is the main function that encrypts the PlainText.
            void cipher(ref scope state_t state) {
                ubyte round = 0;

                // Add the First round key to the state before starting the rounds.
                addRoundKey(0, state);

                // There will be Nr rounds.
                // The first Nr-1 rounds are identical.
                // These Nr rounds are executed in the loop below.
                // Last one without MixColumns()
                for (round = 1;; ++round) {
                    SubBytes(state);
                    ShiftRows(state);
                    if (round == Nr) {
                        break;
                    }
                    MixColumns(state);
                    addRoundKey(round, state);
                }
                // Add round key to last round
                addRoundKey(Nr, state);
            }

            void InvCipher(ref scope state_t state) {
                ubyte round = 0;

                // Add the First round key to the state before starting the rounds.
                addRoundKey(Nr, state);

                // There will be Nr rounds.
                // The first Nr-1 rounds are identical.
                // These Nr rounds are executed in the loop below.
                // Last one without InvMixColumn()
                for (round = (Nr - 1);; --round) {
                    InvShiftRows(state);
                    InvSubBytes(state);
                    addRoundKey(round, state);
                    if (round == 0) {
                        break;
                    }
                    InvMixColumns(state);
                }

            }

            static void xorWithIv(ubyte[] buf, ref const(ubyte[BLOCK_SIZE]) Iv) {
                static foreach (i; 0 .. BLOCK_SIZE) {
                    buf[i] ^= Iv[i];
                }
            }

        }
        /*****************************************************************************/
        /* Public functions:                                                         */
        /*****************************************************************************/

        //        version(unittest) {
        static if (mode is Mode.ECB) {
            void encrypt(scope ubyte[] buf) {
                // The next function call encrypts the PlainText with the Key using AES algorithm.
                while (buf.length) {
                    cipher(State(buf));
                    buf = buf[BLOCK_SIZE .. $];
                }
            }

            void decrypt(scope ubyte[] buf) {
                // The next function call decrypts the PlainText with the Key using AES algorithm.
                while (buf.length) {
                    InvCipher(State(buf));
                    buf = buf[BLOCK_SIZE .. $];
                }
            }
        }

        static if (mode is Mode.CBC) {
            void encrypt(scope ubyte[] buf) {
                auto Iv = ctx.Iv;
                while (buf.length) {
                    xorWithIv(buf, Iv);
                    cipher(State(buf));
                    Iv = buf[0 .. BLOCK_SIZE];
                    buf = buf[BLOCK_SIZE .. $];
                }
                /* store Iv in ctx for next call */
                ctx.Iv = Iv;
            }

            void decrypt(scope ubyte[] buf) {
                ubyte[BLOCK_SIZE] storeNextIv;
                while (buf.length) {
                    storeNextIv = buf[0 .. BLOCK_SIZE];
                    InvCipher(State(buf));
                    xorWithIv(buf, ctx.Iv);
                    ctx.Iv = storeNextIv;
                    buf = buf[BLOCK_SIZE .. $];
                }
            }
        }

        static if (mode is Mode.CFB) {
            void encrypt(scope ubyte[] buf) {
                scope storeNextIv = ctx.Iv;
                while (buf.length) {
                    cipher(State(storeNextIv));
                    xorWithIv(buf, storeNextIv);
                    storeNextIv = buf[0 .. BLOCK_SIZE];
                    buf = buf[BLOCK_SIZE .. $];
                }
            }

            void decrypt(scope ubyte[] buf) {
                scope storeNextIv = ctx.Iv;
                while (buf.length) {
                    cipher(State(storeNextIv));
                    const xor = storeNextIv;
                    storeNextIv = buf[0 .. BLOCK_SIZE];
                    xorWithIv(buf, xor);
                    buf = buf[BLOCK_SIZE .. $];
                }
            }
        }

        /* Symmetrical operation: same function for encrypting as for decrypting. Note any IV/nonce should never be reused with the same key */
        static if (mode is Mode.CTR) {
            alias encrypt = xcrypt;
            alias decrypt = xcrypt;
            void xcrypt(scope ubyte[] buf) {
                ubyte[BLOCK_SIZE] buffer;
                size_t bi; //=BLOCK_SIZE;
                foreach (i; 0 .. buf.length) {
                    if (i % BLOCK_SIZE == 0) { //bi == BLOCK_SIZE) { /* we need to regen xor compliment in buffer */
                        buffer[0 .. BLOCK_SIZE] = ctx.Iv;
                        cipher(State(buffer));

                        /* Increment Iv and handle overflow */
                        foreach_reverse (j; 0 .. BLOCK_SIZE) {
                            /* inc will overflow */
                            if (ctx.Iv[j] == 255) {
                                ctx.Iv[j] = 0;
                                continue;
                            }
                            ctx.Iv[j] += 1;
                            break;
                        }
                        bi = 0;
                    }

                    buf[i] ^= buffer[bi];
                    bi++;
                }
            }
        }

    }
    unittest {
        version (PRINT) import std.stdio;

        version (PRINT)
            writefln("Start unittest %s %s", KEY_LENGTH, mode);
        // prints string as hex
        static void phex(ubyte[] str) {
            version (PRINT) {
                ubyte len = KEY_SIZE;
                ubyte i;
                for (i = 0; i < len; ++i)
                    writef("%.2x", str[i]);
                writeln;
            }
        }

        version (PRINT)
            static if (mode is Mode.ECB && KEY_LENGTH is 128) {
                {
                    // Example of more verbose verification

                    // 128bit key
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    // 512bit text
                    ubyte[64] plain_text = [
                        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                        0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
                        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7,
                        0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
                        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb,
                        0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
                        0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b,
                        0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10
                    ];

                    // print text to encrypt, key and IV
                    writeln("ECB encrypt verbose:\n");
                    writeln("plain text:\n");
                    foreach (i; 0 .. 4) {
                        phex(plain_text[i * 16 .. $]);
                    }
                    writeln();

                    write("key:");
                    phex(key);
                    writeln();

                    // print the resulting cipher as 4 x 16 byte strings
                    writeln("ciphertext:");
                    //ctx ctx;
                    auto aes = Tiny_AES(key);

                    foreach (i; 0 .. 4) {
                        aes.encrypt(plain_text[i * 16 .. $]);
                        phex(plain_text[i * 16 .. $]);
                    }
                    writeln();
                }
            }

        static if (mode is Mode.ECB) {
            { // test_encrypt_ecb
                static if (KEY_LENGTH is 256) {
                    ubyte[KEY_SIZE] key = [
                        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
                        0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98,
                        0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
                    ];
                    ubyte[] outdata = [
                        0xf3, 0xee, 0xd1, 0xbd, 0xb5, 0xd2, 0xa0, 0x3c, 0x06, 0x4b,
                        0x5a, 0x7e, 0x3d, 0xb1, 0x81, 0xf8
                    ];
                }
                else static if (KEY_LENGTH is 192) {
                    ubyte[KEY_SIZE] key = [
                        0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10,
                        0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                        0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b
                    ];
                    ubyte[] outdata = [
                        0xbd, 0x33, 0x4f, 0x1d, 0x6e, 0x45, 0xf2, 0x5f, 0xf7, 0x12,
                        0xa2, 0x14, 0x57, 0x1f, 0xa5, 0xcc
                    ];
                }
                else static if (KEY_LENGTH is 128) {
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    ubyte[] outdata = [
                        0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60, 0xa8, 0x9e,
                        0xca, 0xf3, 0x24, 0x66, 0xef, 0x97
                    ];
                }

                ubyte[] indata = [
                    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                    0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
                ];
                //Tiny_AES aes;
                auto aes = Tiny_AES(key);
                aes.encrypt(indata);

                version (PRINT)
                    writeln("ECB encrypt: ");

                assert(outdata == indata);
            }
        }

        static if (mode is Mode.CBC) {
            { // test_decrypt_cbc
                static if (KEY_LENGTH is 256) {
                    ubyte[KEY_SIZE] key = [
                        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
                        0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98,
                        0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
                    ];
                    ubyte[] indata = [
                        0xf5, 0x8c, 0x4c, 0x04, 0xd6, 0xe5, 0xf1, 0xba, 0x77, 0x9e,
                        0xab, 0xfb, 0x5f, 0x7b, 0xfb, 0xd6,
                        0x9c, 0xfc, 0x4e, 0x96, 0x7e, 0xdb, 0x80, 0x8d, 0x67, 0x9f,
                        0x77, 0x7b, 0xc6, 0x70, 0x2c, 0x7d,
                        0x39, 0xf2, 0x33, 0x69, 0xa9, 0xd9, 0xba, 0xcf, 0xa5, 0x30,
                        0xe2, 0x63, 0x04, 0x23, 0x14, 0x61,
                        0xb2, 0xeb, 0x05, 0xe2, 0xc3, 0x9b, 0xe9, 0xfc, 0xda, 0x6c,
                        0x19, 0x07, 0x8c, 0x6a, 0x9d, 0x1b
                    ];
                }
                else static if (KEY_LENGTH is 192) {
                    ubyte[KEY_SIZE] key = [
                        0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10,
                        0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                        0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b
                    ];
                    ubyte[] indata = [
                        0x4f, 0x02, 0x1d, 0xb2, 0x43, 0xbc, 0x63, 0x3d, 0x71, 0x78,
                        0x18, 0x3a, 0x9f, 0xa0, 0x71, 0xe8,
                        0xb4, 0xd9, 0xad, 0xa9, 0xad, 0x7d, 0xed, 0xf4, 0xe5, 0xe7,
                        0x38, 0x76, 0x3f, 0x69, 0x14, 0x5a,
                        0x57, 0x1b, 0x24, 0x20, 0x12, 0xfb, 0x7a, 0xe0, 0x7f, 0xa9,
                        0xba, 0xac, 0x3d, 0xf1, 0x02, 0xe0,
                        0x08, 0xb0, 0xe2, 0x79, 0x88, 0x59, 0x88, 0x81, 0xd9, 0x20,
                        0xa9, 0xe6, 0x4f, 0x56, 0x15, 0xcd
                    ];
                }
                else static if (KEY_LENGTH is 128) {
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    ubyte[] indata = [
                        0x76, 0x49, 0xab, 0xac, 0x81, 0x19, 0xb2, 0x46, 0xce, 0xe9,
                        0x8e, 0x9b, 0x12, 0xe9, 0x19, 0x7d,
                        0x50, 0x86, 0xcb, 0x9b, 0x50, 0x72, 0x19, 0xee, 0x95, 0xdb,
                        0x11, 0x3a, 0x91, 0x76, 0x78, 0xb2,
                        0x73, 0xbe, 0xd6, 0xb8, 0xe3, 0xc1, 0x74, 0x3b, 0x71, 0x16,
                        0xe6, 0x9e, 0x22, 0x22, 0x95, 0x16,
                        0x3f, 0xf1, 0xca, 0xa1, 0x68, 0x1f, 0xac, 0x09, 0x12, 0x0e,
                        0xca, 0x30, 0x75, 0x86, 0xe1, 0xa7
                    ];
                }

                ubyte[BLOCK_SIZE] iv = [
                    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
                    0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
                ];
                ubyte[] outdata = [
                    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                    0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
                    0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7,
                    0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
                    0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb,
                    0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
                    0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b,
                    0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10
                ];

                //Tiny_AES aes;
                auto aes = Tiny_AES(key, iv);
                aes.decrypt(indata);

                version (PRINT)
                    writeln("CBC decrypt: ");

                assert(outdata == indata);
            }
        }

        static if (mode is Mode.CBC) {
            { // test_encrypt_cbc
                static if (KEY_LENGTH is 256) {
                    ubyte[KEY_SIZE] key = [
                        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
                        0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98,
                        0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
                    ];
                    ubyte[] outdata = [
                        0xf5, 0x8c, 0x4c, 0x04, 0xd6, 0xe5, 0xf1, 0xba, 0x77, 0x9e,
                        0xab, 0xfb, 0x5f, 0x7b, 0xfb, 0xd6,
                        0x9c, 0xfc, 0x4e, 0x96, 0x7e, 0xdb, 0x80, 0x8d, 0x67, 0x9f,
                        0x77, 0x7b, 0xc6, 0x70, 0x2c, 0x7d,
                        0x39, 0xf2, 0x33, 0x69, 0xa9, 0xd9, 0xba, 0xcf, 0xa5, 0x30,
                        0xe2, 0x63, 0x04, 0x23, 0x14, 0x61,
                        0xb2, 0xeb, 0x05, 0xe2, 0xc3, 0x9b, 0xe9, 0xfc, 0xda, 0x6c,
                        0x19, 0x07, 0x8c, 0x6a, 0x9d, 0x1b
                    ];
                }
                else static if (KEY_LENGTH is 192) {

                    ubyte[KEY_SIZE] key = [
                        0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10,
                        0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                        0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b
                    ];
                    ubyte[] outdata = [
                        0x4f, 0x02, 0x1d, 0xb2, 0x43, 0xbc, 0x63, 0x3d, 0x71, 0x78,
                        0x18, 0x3a, 0x9f, 0xa0, 0x71, 0xe8,
                        0xb4, 0xd9, 0xad, 0xa9, 0xad, 0x7d, 0xed, 0xf4, 0xe5, 0xe7,
                        0x38, 0x76, 0x3f, 0x69, 0x14, 0x5a,
                        0x57, 0x1b, 0x24, 0x20, 0x12, 0xfb, 0x7a, 0xe0, 0x7f, 0xa9,
                        0xba, 0xac, 0x3d, 0xf1, 0x02, 0xe0,
                        0x08, 0xb0, 0xe2, 0x79, 0x88, 0x59, 0x88, 0x81, 0xd9, 0x20,
                        0xa9, 0xe6, 0x4f, 0x56, 0x15, 0xcd
                    ];
                }
                else static if (KEY_LENGTH is 128) {
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    ubyte[] outdata = [
                        0x76, 0x49, 0xab, 0xac, 0x81, 0x19, 0xb2, 0x46, 0xce, 0xe9,
                        0x8e, 0x9b, 0x12, 0xe9, 0x19, 0x7d,
                        0x50, 0x86, 0xcb, 0x9b, 0x50, 0x72, 0x19, 0xee, 0x95, 0xdb,
                        0x11, 0x3a, 0x91, 0x76, 0x78, 0xb2,
                        0x73, 0xbe, 0xd6, 0xb8, 0xe3, 0xc1, 0x74, 0x3b, 0x71, 0x16,
                        0xe6, 0x9e, 0x22, 0x22, 0x95, 0x16,
                        0x3f, 0xf1, 0xca, 0xa1, 0x68, 0x1f, 0xac, 0x09, 0x12, 0x0e,
                        0xca, 0x30, 0x75, 0x86, 0xe1, 0xa7
                    ];
                }

                ubyte[BLOCK_SIZE] iv = [
                    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
                    0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
                ];
                ubyte[] indata = [
                    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                    0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
                    0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7,
                    0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
                    0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb,
                    0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
                    0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b,
                    0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10
                ];
                //            ctx ctx;
                //Tiny_AES aes;
                auto aes = Tiny_AES(key, iv);
                aes.encrypt(indata);

                version (PRINT)
                    writeln("CBC encrypt: ");

                assert(outdata == indata);
            }
        }

        static if (mode is Mode.CTR) {
            { // test ctr
                static if (KEY_LENGTH is 256) {
                    ubyte[KEY_SIZE] key = [
                        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
                        0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98,
                        0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
                    ];
                    ubyte[64] indata = [
                        0x60, 0x1e, 0xc3, 0x13, 0x77, 0x57, 0x89, 0xa5, 0xb7, 0xa7,
                        0xf5, 0x04, 0xbb, 0xf3, 0xd2, 0x28,
                        0xf4, 0x43, 0xe3, 0xca, 0x4d, 0x62, 0xb5, 0x9a, 0xca, 0x84,
                        0xe9, 0x90, 0xca, 0xca, 0xf5, 0xc5,
                        0x2b, 0x09, 0x30, 0xda, 0xa2, 0x3d, 0xe9, 0x4c, 0xe8, 0x70,
                        0x17, 0xba, 0x2d, 0x84, 0x98, 0x8d,
                        0xdf, 0xc9, 0xc5, 0x8d, 0xb6, 0x7a, 0xad, 0xa6, 0x13, 0xc2,
                        0xdd, 0x08, 0x45, 0x79, 0x41, 0xa6
                    ];
                }
                else static if (KEY_LENGTH is 192) {
                    ubyte[KEY_SIZE] key = [
                        0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10,
                        0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                        0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b
                    ];
                    ubyte[64] indata = [
                        0x1a, 0xbc, 0x93, 0x24, 0x17, 0x52, 0x1c, 0xa2, 0x4f, 0x2b,
                        0x04, 0x59, 0xfe, 0x7e, 0x6e, 0x0b,
                        0x09, 0x03, 0x39, 0xec, 0x0a, 0xa6, 0xfa, 0xef, 0xd5, 0xcc,
                        0xc2, 0xc6, 0xf4, 0xce, 0x8e, 0x94,
                        0x1e, 0x36, 0xb2, 0x6b, 0xd1, 0xeb, 0xc6, 0x70, 0xd1, 0xbd,
                        0x1d, 0x66, 0x56, 0x20, 0xab, 0xf7,
                        0x4f, 0x78, 0xa7, 0xf6, 0xd2, 0x98, 0x09, 0x58, 0x5a, 0x97,
                        0xda, 0xec, 0x58, 0xc6, 0xb0, 0x50
                    ];
                }
                else static if (KEY_LENGTH is 128) {
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    ubyte[64] indata = [
                        0x87, 0x4d, 0x61, 0x91, 0xb6, 0x20, 0xe3, 0x26, 0x1b, 0xef,
                        0x68, 0x64, 0x99, 0x0d, 0xb6, 0xce,
                        0x98, 0x06, 0xf6, 0x6b, 0x79, 0x70, 0xfd, 0xff, 0x86, 0x17,
                        0x18, 0x7b, 0xb9, 0xff, 0xfd, 0xff,
                        0x5a, 0xe4, 0xdf, 0x3e, 0xdb, 0xd5, 0xd3, 0x5e, 0x5b, 0x4f,
                        0x09, 0x02, 0x0d, 0xb0, 0x3e, 0xab,
                        0x1e, 0x03, 0x1d, 0xda, 0x2f, 0xbe, 0x03, 0xd1, 0x79, 0x21,
                        0x70, 0xa0, 0xf3, 0x00, 0x9c, 0xee
                    ];
                }
                ubyte[16] iv = [
                    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9,
                    0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff
                ];
                ubyte[64] outdata = [
                    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                    0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
                    0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7,
                    0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
                    0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb,
                    0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
                    0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b,
                    0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10
                ];
                //Tiny_AES aes;
                auto aes = Tiny_AES(key, iv);
                aes.xcrypt(indata);

                assert(outdata == indata);
            }
        }

        static if (mode is Mode.ECB) {
            { // test_decrypt_ecb
                static if (KEY_LENGTH is 256) {
                    ubyte[KEY_SIZE] key = [
                        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73,
                        0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98,
                        0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
                    ];
                    ubyte[] indata = [
                        0xf3, 0xee, 0xd1, 0xbd, 0xb5, 0xd2, 0xa0, 0x3c, 0x06, 0x4b,
                        0x5a, 0x7e, 0x3d, 0xb1, 0x81, 0xf8
                    ];
                }
                else static if (KEY_LENGTH is 192) {
                    ubyte[KEY_SIZE] key = [
                        0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10,
                        0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                        0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b
                    ];
                    ubyte[] indata = [
                        0xbd, 0x33, 0x4f, 0x1d, 0x6e, 0x45, 0xf2, 0x5f, 0xf7, 0x12,
                        0xa2, 0x14, 0x57, 0x1f, 0xa5, 0xcc
                    ];
                }
                else static if (KEY_LENGTH is 128) {
                    ubyte[KEY_SIZE] key = [
                        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7,
                        0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
                    ];
                    ubyte[] indata = [
                        0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60, 0xa8, 0x9e,
                        0xca, 0xf3, 0x24, 0x66, 0xef, 0x97
                    ];
                }

                ubyte[] outdata = [
                    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d,
                    0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
                ];
                //Tiny_AES aes;
                auto aes = Tiny_AES(key);
                aes.decrypt(indata);

                version (PRINT)
                    writeln("ECB decrypt: ");

                assert(outdata == indata);
            }
        }
    }
}

unittest {
    version (PRINT) import std.stdio;
    import std.traits : EnumMembers;

    static foreach (key_size; [128, 192, 256]) {
        static foreach (mode; EnumMembers!Mode) {
            {
                alias AES = Tiny_AES!(key_size, mode);
                AES aes;
                version (PRINT)
                    writefln("%s", AES.stringof);
            }
        }
    }
}
