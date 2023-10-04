module tagion.pbkdf2.pbkdf2;

import std.digest.sha : SHA1;

static if (__VERSION__ >= 2080)
    import std.digest : isDigest, digestLength;
else
    import std.digest.digest : isDigest, digestLength;

/**
 * Returns a binary digest for the PBKDF2 hash algorithm of `data` with the given `salt`.
 * It iterates `iterations` time and produces a key of `dkLen` bytes.
 * By default SHA-1 is used as hash function.
 *
 * Params:
 * 		data = data to hash
 * 		salt = salt to use to hash data
 * 		iterations = number of iterations to create hash with
 * 		dkLen = intended length of the derived key, at most (2^32 - 1) * hLen
 *
 * Authors: T. Chaloupka
 */
@safe
ubyte[] pbkdf2(H = SHA1)(in ubyte[] data, in ubyte[] salt, uint iterations = 4096, uint dkLen = 256) pure nothrow
if (isDigest!H)
in {
    assert(dkLen < (2 ^ 32 - 1) * digestLength!H, "Derived key too long");
}
do {
    auto f(PRF)(PRF prf, in ubyte[] salt, uint c, uint block) {
        import std.bitmanip : nativeToBigEndian;

        auto res = prf.put(salt ~ nativeToBigEndian(block)).finish();
        auto prev = res;
        foreach (i; 1 .. c) {
            prev = prf.put(prev).finish();
            foreach (n, ref r; res)
                r ^= prev[n];
        }

        return res;
    }

    import std.digest.hmac;
    import std.range : iota;

    alias digestLength!H hLen;

    auto hmac = HMAC!H(data);
    auto l = cast(uint)((dkLen + hLen - 1) / hLen);

    uint idx;
    ubyte[] res = new ubyte[l * hLen];
    foreach (block; iota(1, l + 1)) {
        res[idx .. idx + hLen] = f(hmac, salt, iterations, block);
        idx += hLen;
    }

    return res[0 .. dkLen];
}

@safe
unittest {
    import std.string : representation;
    import std.format : format;

    static if (__VERSION__ >= 2080)
        import std.digest : toHexString, LetterCase;
    else
        import std.digest.digest : toHexString, LetterCase;
    import std.range : repeat, take;
    import std.array;
    import std.digest.sha;

    // Test vectors from rfc6070

    auto res = pbkdf2("password".representation, "salt".representation, 1, 20).toHexString!(LetterCase.lower);
    assert(res == "0c60c80f961f0e71f3a9b524af6012062fe037a6");

    res = pbkdf2("password".representation, "salt".representation, 2, 20).toHexString!(LetterCase.lower);
    assert(res == "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957");

    res = pbkdf2("password".representation, "salt".representation, 4096, 20).toHexString!(LetterCase.lower);
    assert(res == "4b007901b765489abead49d926f721d065a429c1");

    //Takes too long so it s versioned out..
    version (LongTests) {
        res = pbkdf2("password".representation, "salt".representation, 16_777_216, 20).toHexString!(LetterCase.lower);
        assert(res == "eefe3d61cd4da4e4e9945b3d6ba2158c2634e984");
    }

    res = pbkdf2("passwordPASSWORDpassword".representation, "saltSALTsaltSALTsaltSALTsaltSALTsalt".representation, 4096, 25)
        .toHexString!(LetterCase.lower);
    assert(res == "3d2eec4fe41c849b80c8d83662c0e44a8b291a964cf2f07038");

    res = pbkdf2("pass\0word".representation, "sa\0lt".representation, 4096, 16).toHexString!(LetterCase.lower);
    assert(res == "56fa6aa75548099dcc37d7f03425e0c3");

    // Test vectors from Crypt-PBKDF2

    res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 1, 16).toHexString!(LetterCase.lower);
    assert(res == "cdedb5281bb2f801565a1122b2563515");

    res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 1, 32).toHexString!(LetterCase.lower);
    assert(res == "cdedb5281bb2f801565a1122b25635150ad1f7a04bb9f3a333ecc0e2e1f70837");

    res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 2, 16).toHexString!(LetterCase.lower);
    assert(res == "01dbee7f4a9e243e988b62c73cda935d");

    res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 2, 32).toHexString!(LetterCase.lower);
    assert(res == "01dbee7f4a9e243e988b62c73cda935da05378b93244ec8f48a99e61ad799d86");

    res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 1200, 32).toHexString!(LetterCase
            .lower);
    assert(res == "5c08eb61fdf71e4e4ec3cf6ba1f5512ba7e52ddbc5e5142f708a31e2e62b1e13");

    res = pbkdf2((cast(ubyte) 'X').repeat.take(64).array, "pass phrase equals block size".representation, 1200, 32)
        .toHexString!(LetterCase.lower);
    assert(res == "139c30c0966bc32ba55fdbf212530ac9c5ec59f1a452f5cc9ad940fea0598ed1");

    res = pbkdf2((cast(ubyte) 'X').repeat.take(65).array, "pass phrase exceeds block size".representation, 1200, 32)
        .toHexString!(LetterCase.lower);
    assert(res == "9ccad6d468770cd51b10e6a68721be611a8b4d282601db3b36be9246915ec82a");

    // Test vectors for SHA256

    res = pbkdf2!SHA256("password".representation, "salt".representation, 1, 32).toHexString!(LetterCase.lower);
    assert(res == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b");

    res = pbkdf2!SHA256("password".representation, "salt".representation, 2, 32).toHexString!(LetterCase.lower);
    assert(res == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43");

    res = pbkdf2!SHA256("password".representation, "salt".representation, 4096, 32).toHexString!(LetterCase.lower);
    assert(res == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a");

    //Takes too long so it s versioned out..
    version (LongTests) {
        res = pbkdf2!SHA256("password".representation, "salt".representation, 16_777_216, 32).toHexString!(LetterCase
                .lower);
        assert(res == "cf81c66fe8cfc04d1f31ecb65dab4089f7f179e89b3b0bcb17ad10e3ac6eba46");
    }

    res = pbkdf2!SHA256("passwordPASSWORDpassword".representation, "saltSALTsaltSALTsaltSALTsaltSALTsalt".representation, 4096, 40)
        .toHexString!(LetterCase.lower);
    assert(res == "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9");

    res = pbkdf2!SHA256("pass\0word".representation, "sa\0lt".representation, 4096, 16).toHexString!(LetterCase.lower);
    assert(res == "89b69d0516f829893c696226650a8687");
}

@safe
unittest {
    /// pbkdf2 SHA512 test-sample taken from
    /// https://stackoverflow.com/questions/15593184/pbkdf2-hmac-sha-512-test-vectors
    import std.digest.sha; // : SHA512;
    import std.stdio;
    import std.string : representation;

    alias pbkdf2_sha256 = pbkdf2!SHA512;
    auto password = "password".representation;
    auto salt = "salt".representation;
    {
        /*
Input:
  P = "password"
  S = "salt"
  c = 1
  dkLen = 64

Output:
  DK = 86 7f 70 cf 1a de 02 cf 
       f3 75 25 99 a3 a5 3d c4 
       af 34 c7 a6 69 81 5a e5 
       d5 13 55 4e 1c 8c f2 52 
       c0 2d 47 0a 28 5a 05 01 
       ba d9 99 bf e9 43 c0 8f 
       05 02 35 d7 d6 8b 1d a5 
       5e 63 f7 3b 60 a5 7f ce 
*/
        immutable(ubyte[]) expected = [
            0x86, 0x7f, 0x70, 0xcf, 0x1a, 0xde, 0x02, 0xcf,
            0xf3, 0x75, 0x25, 0x99, 0xa3, 0xa5, 0x3d, 0xc4,
            0xaf, 0x34, 0xc7, 0xa6, 0x69, 0x81, 0x5a, 0xe5,
            0xd5, 0x13, 0x55, 0x4e, 0x1c, 0x8c, 0xf2, 0x52,
            0xc0, 0x2d, 0x47, 0x0a, 0x28, 0x5a, 0x05, 0x01,
            0xba, 0xd9, 0x99, 0xbf, 0xe9, 0x43, 0xc0, 0x8f,
            0x05, 0x02, 0x35, 0xd7, 0xd6, 0x8b, 0x1d, 0xa5,
            0x5e, 0x63, 0xf7, 0x3b, 0x60, 0xa5, 0x7f, 0xce,
        ];
        const count = 1;
        const result =
            pbkdf2_sha256(password, salt, count, 64);
        assert(result == expected);
    }
    {
        /*
Input:
  P = "password"
  S = "salt"
  c = 2
  dkLen = 64

Output:
  DK = e1 d9 c1 6a a6 81 70 8a 
       45 f5 c7 c4 e2 15 ce b6 
       6e 01 1a 2e 9f 00 40 71 
       3f 18 ae fd b8 66 d5 3c 
       f7 6c ab 28 68 a3 9b 9f 
       78 40 ed ce 4f ef 5a 82 
       be 67 33 5c 77 a6 06 8e 
       04 11 27 54 f2 7c cf 4e 
*/
        immutable(ubyte[]) expected = [
            0xe1, 0xd9, 0xc1, 0x6a, 0xa6, 0x81, 0x70, 0x8a,
            0x45, 0xf5, 0xc7, 0xc4, 0xe2, 0x15, 0xce, 0xb6,
            0x6e, 0x01, 0x1a, 0x2e, 0x9f, 0x00, 0x40, 0x71,
            0x3f, 0x18, 0xae, 0xfd, 0xb8, 0x66, 0xd5, 0x3c,
            0xf7, 0x6c, 0xab, 0x28, 0x68, 0xa3, 0x9b, 0x9f,
            0x78, 0x40, 0xed, 0xce, 0x4f, 0xef, 0x5a, 0x82,
            0xbe, 0x67, 0x33, 0x5c, 0x77, 0xa6, 0x06, 0x8e,
            0x04, 0x11, 0x27, 0x54, 0xf2, 0x7c, 0xcf, 0x4e,
        ];
        const count = 2;
        const result =
            pbkdf2_sha256(password, salt, count, 64);
        assert(result == expected);
    }
    {
        /*
Input:
  P = "password"
  S = "salt"
  c = 4096
  dkLen = 64

Output:
  DK = d1 97 b1 b3 3d b0 14 3e 
       01 8b 12 f3 d1 d1 47 9e 
       6c de bd cc 97 c5 c0 f8 
       7f 69 02 e0 72 f4 57 b5 
       14 3f 30 60 26 41 b3 d5 
       5c d3 35 98 8c b3 6b 84 
       37 60 60 ec d5 32 e0 39 
       b7 42 a2 39 43 4a f2 d5 
*/
        immutable(ubyte[]) expected = [
            0xd1, 0x97, 0xb1, 0xb3, 0x3d, 0xb0, 0x14, 0x3e,
            0x01, 0x8b, 0x12, 0xf3, 0xd1, 0xd1, 0x47, 0x9e,
            0x6c, 0xde, 0xbd, 0xcc, 0x97, 0xc5, 0xc0, 0xf8,
            0x7f, 0x69, 0x02, 0xe0, 0x72, 0xf4, 0x57, 0xb5,
            0x14, 0x3f, 0x30, 0x60, 0x26, 0x41, 0xb3, 0xd5,
            0x5c, 0xd3, 0x35, 0x98, 0x8c, 0xb3, 0x6b, 0x84,
            0x37, 0x60, 0x60, 0xec, 0xd5, 0x32, 0xe0, 0x39,
            0xb7, 0x42, 0xa2, 0x39, 0x43, 0x4a, 0xf2, 0xd5,
        ];
        const count = 4096;
        const result =
            pbkdf2_sha256(password, salt, count, 64);
        assert(result == expected);

    }
    {
        /*
Input:
  P = "passwordPASSWORDpassword"
  S = "saltSALTsaltSALTsaltSALTsaltSALTsalt"
  c = 4096
  dkLen = 64


Output:
  DK = 8c 05 11 f4 c6 e5 97 c6 
       ac 63 15 d8 f0 36 2e 22 
       5f 3c 50 14 95 ba 23 b8 
       68 c0 05 17 4d c4 ee 71 
       11 5b 59 f9 e6 0c d9 53 
       2f a3 3e 0f 75 ae fe 30 
       22 5c 58 3a 18 6c d8 2b 
       d4 da ea 97 24 a3 d3 b8 
*/
        immutable(ubyte[]) expected = [
            0x8c, 0x05, 0x11, 0xf4, 0xc6, 0xe5, 0x97, 0xc6,
            0xac, 0x63, 0x15, 0xd8, 0xf0, 0x36, 0x2e, 0x22,
            0x5f, 0x3c, 0x50, 0x14, 0x95, 0xba, 0x23, 0xb8,
            0x68, 0xc0, 0x05, 0x17, 0x4d, 0xc4, 0xee, 0x71,
            0x11, 0x5b, 0x59, 0xf9, 0xe6, 0x0c, 0xd9, 0x53,
            0x2f, 0xa3, 0x3e, 0x0f, 0x75, 0xae, 0xfe, 0x30,
            0x22, 0x5c, 0x58, 0x3a, 0x18, 0x6c, 0xd8, 0x2b,
            0xd4, 0xda, 0xea, 0x97, 0x24, 0xa3, 0xd3, 0xb8,
        ];
        password = "passwordPASSWORDpassword".representation;
        salt = "saltSALTsaltSALTsaltSALTsaltSALTsalt".representation;
        const count = 4096;
        const result =
            pbkdf2_sha256(password, salt, count, 64);
        assert(result == expected);
    }
}
