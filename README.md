[![Build Status](https://travis-ci.org/tchaloupka/vibe-mqtt.svg?branch=master)](https://travis-ci.org/tchaloupka/pbkdf2)
[![Dub downloads](https://img.shields.io/dub/dt/vibe-mqtt.svg)](http://code.dlang.org/packages/pbkdf2)
[![License](https://img.shields.io/dub/l/vibe-mqtt.svg)](http://code.dlang.org/packages/pbkdf2)
[![Latest version](https://img.shields.io/dub/v/vibe-mqtt.svg)](http://code.dlang.org/packages/pbkdf2)

PBKDF2 for D
============

D-language implementation of Password Based Key Derivation Function 2 [RFC2898](https://tools.ietf.org/html/rfc2898#section-5.2). 

Unlike bcrypt this is easy to understand, secure enough given a sufficently
random salt and implemented on top of the standard Phobos library.

It uses HMAC as a pseudorandom function, with SHA1 as a default hashing function.

Sample usage:
```D
import std.string : representation;
import std.digest.sha;
import kdf.pbkdf2;

auto dk = pbkdf2("password".representation, "salt".representation);
auto dk256 = pbkdf2!SHA256("password".representation, "salt".representation);
```

Test vectors for HMAC-SHA1 and HMAC-SHA256 are included.
