PBKDF2 for D
============

D-language implementation of Password Based Key Derivation Function 2 [RFC2898](https://tools.ietf.org/html/rfc2898#section-5.2). 

Unlike bcrypt this is easy to understand, secure enough given a sufficently
random salt and implemented on top of the standard Phobos library.

It uses HMAC as a pseudorandom function, with SHA1 hashing function as a default.

Test vectors for HMAC-SHA1 and HMAC-SHA256 are included.

