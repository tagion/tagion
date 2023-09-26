module tagion.pbkdf2.pbkdf2;

import std.digest.sha : SHA1;
static if (__VERSION__ >= 2080) import std.digest : isDigest, digestLength;
else import std.digest.digest : isDigest, digestLength;

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
auto pbkdf2(H = SHA1)(in ubyte[] data, in ubyte[] salt, uint iterations = 4096, uint dkLen = 256)
	if (isDigest!H)
in
{
	import std.exception;
	enforce(dkLen < (2^32 - 1) * digestLength!H, "Derived key too long");
}
body
{
	auto f(PRF)(PRF prf, in ubyte[] salt, uint c, uint block)
	{
		import std.bitmanip : nativeToBigEndian;

		auto res = prf.put(salt ~ nativeToBigEndian(block)).finish();
		auto prev = res;
		foreach(i; 1..c)
		{
			prev = prf.put(prev).finish();
			foreach(n, ref r; res) r ^= prev[n];
		}

		return res;
	}

	import std.digest.hmac;
	import std.range : iota;

	alias digestLength!H hLen;

	auto hmac = HMAC!H(data);
	auto l = cast(uint)((dkLen + hLen - 1)/ hLen);

	uint idx;
	ubyte[] res = new ubyte[l * hLen];
	foreach(block; iota(1, l+1))
	{
		res[idx..idx+hLen] = f(hmac, salt, iterations, block);
		idx += hLen;
	}

	return res[0..dkLen];
}

unittest
{
	import std.string : representation;
	import std.format : format;
	static if (__VERSION__ >= 2080) import std.digest : toHexString, LetterCase;
	else import std.digest.digest : toHexString, LetterCase;
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
	version(LongTests)
	{
		res = pbkdf2("password".representation, "salt".representation, 16_777_216, 20).toHexString!(LetterCase.lower);
		assert(res == "eefe3d61cd4da4e4e9945b3d6ba2158c2634e984");
	}

	res = pbkdf2("passwordPASSWORDpassword".representation, "saltSALTsaltSALTsaltSALTsaltSALTsalt".representation, 4096, 25).toHexString!(LetterCase.lower);
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

	res = pbkdf2("password".representation, "ATHENA.MIT.EDUraeburn".representation, 1200, 32).toHexString!(LetterCase.lower);
	assert(res == "5c08eb61fdf71e4e4ec3cf6ba1f5512ba7e52ddbc5e5142f708a31e2e62b1e13");

	res = pbkdf2((cast(ubyte)'X').repeat.take(64).array, "pass phrase equals block size".representation, 1200, 32).toHexString!(LetterCase.lower);
	assert(res == "139c30c0966bc32ba55fdbf212530ac9c5ec59f1a452f5cc9ad940fea0598ed1");

	res = pbkdf2((cast(ubyte)'X').repeat.take(65).array, "pass phrase exceeds block size".representation, 1200, 32).toHexString!(LetterCase.lower);
	assert(res == "9ccad6d468770cd51b10e6a68721be611a8b4d282601db3b36be9246915ec82a");

	// Test vectors for SHA256

	res = pbkdf2!SHA256("password".representation, "salt".representation, 1, 32).toHexString!(LetterCase.lower);
	assert(res == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b");

	res = pbkdf2!SHA256("password".representation, "salt".representation, 2, 32).toHexString!(LetterCase.lower);
	assert(res == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43");

	res = pbkdf2!SHA256("password".representation, "salt".representation, 4096, 32).toHexString!(LetterCase.lower);
	assert(res == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a");

	//Takes too long so it s versioned out..
	version(LongTests)
	{
		res = pbkdf2!SHA256("password".representation, "salt".representation, 16_777_216, 32).toHexString!(LetterCase.lower);
		assert(res == "cf81c66fe8cfc04d1f31ecb65dab4089f7f179e89b3b0bcb17ad10e3ac6eba46");
	}

	res = pbkdf2!SHA256("passwordPASSWORDpassword".representation, "saltSALTsaltSALTsaltSALTsaltSALTsalt".representation, 4096, 40).toHexString!(LetterCase.lower);
	assert(res == "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9");

	res = pbkdf2!SHA256("pass\0word".representation, "sa\0lt".representation, 4096, 16).toHexString!(LetterCase.lower);
	assert(res == "89b69d0516f829893c696226650a8687");
}
