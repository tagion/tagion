/**********************************************************************
 * Copyright (c) 2016 Andrew Poelstra                                 *
 * Distributed under the MIT software license, see the accompanying   *
 * file COPYING or http://www.opensource.org/licenses/mit-license.php.*
 **********************************************************************/

module tagion.crypto.secp256k1.c.secp256k1_whitelist;

extern (C):
nothrow:
@nogc:

enum SECP256K1_WHITELIST_MAX_N_KEYS = 255;

/** Opaque data structure that holds a parsed whitelist proof
 *
 *  The exact representation of data inside is implementation defined and not
 *  guaranteed to be portable between different platforms or versions. Nor is
 *  it guaranteed to have any particular size, nor that identical signatures
 *  will have identical representation. (That is, memcmp may return nonzero
 *  even for identical signatures.)
 *
 *  To obtain these properties, instead use secp256k1_whitelist_signature_parse
 *  and secp256k1_whitelist_signature_serialize to encode/decode signatures
 *  into a well-defined format.
 *
 *  The representation is exposed to allow creation of these objects on the
 *  stack; please *do not* use these internals directly. To learn the number
 *  of keys for a signature, use `secp256k1_whitelist_signature_n_keys`.
 */
struct secp256k1_whitelist_signature
{
    size_t n_keys;
    /* e0, scalars */
    ubyte[8192] data;
}

/** Parse a whitelist signature
 *
 *  Returns: 1 when the signature could be parsed, 0 otherwise.
 *  Args: ctx:    a secp256k1 context object
 *  Out:  sig:    a pointer to a signature object
 *  In:   input:  a pointer to the array to parse
 *    input_len:  the length of the above array
 *
 *  The signature must consist of a 1-byte n_keys value, followed by a 32-byte
 *  big endian e0 value, followed by n_keys many 32-byte big endian s values.
 *  If n_keys falls outside of [0..SECP256K1_WHITELIST_MAX_N_KEYS] the encoding
 *  is invalid.
 *
 *  The total length of the input array must therefore be 33 + 32 * n_keys.
 *  If the length `input_len` does not match this value, parsing will fail.
 *
 *  After the call, sig will always be initialized. If parsing failed or any
 *  scalar values overflow or are zero, the resulting sig value is guaranteed
 *  to fail validation for any set of keys.
 */
int secp256k1_whitelist_signature_parse (
    const(secp256k1_context)* ctx,
    secp256k1_whitelist_signature* sig,
    const(ubyte)* input,
    size_t input_len);

/** Returns the number of keys a signature expects to have.
 *
 *  Returns: the number of keys for the given signature
 *  In: sig: a pointer to a signature object
 */
size_t secp256k1_whitelist_signature_n_keys (
    const(secp256k1_whitelist_signature)* sig);

/** Serialize a whitelist signature
 *
 *  Returns: 1
 *  Args:   ctx:        a secp256k1 context object
 *  Out:    output64:   a pointer to an array to store the serialization
 *  In/Out: output_len: length of the above array, updated with the actual serialized length
 *  In:     sig:        a pointer to an initialized signature object
 *
 *  See secp256k1_whitelist_signature_parse for details about the encoding.
 */
int secp256k1_whitelist_signature_serialize (
    const(secp256k1_context)* ctx,
    ubyte* output,
    size_t* output_len,
    const(secp256k1_whitelist_signature)* sig);

/** Compute a whitelist signature
 * Returns 1: signature was successfully created
 *         0: signature was not successfully created
 * In:     ctx: pointer to a context object (not secp256k1_context_static)
 *         online_pubkeys: list of all online pubkeys
 *         offline_pubkeys: list of all offline pubkeys
 *         n_keys: the number of entries in each of the above two arrays
 *         sub_pubkey: the key to be whitelisted
 *         online_seckey: the secret key to the signer's online pubkey
 *         summed_seckey: the secret key to the sum of (whitelisted key, signer's offline pubkey)
 *         index: the signer's index in the lists of keys
 * Out:    sig: The produced signature.
 *
 * The signatures are of the list of all passed pubkeys in the order
 *     ( whitelist, online_1, offline_1, online_2, offline_2, ... )
 * The verification key list consists of
 *     online_i + H(offline_i + whitelist)(offline_i + whitelist)
 * for each public key pair (offline_i, offline_i). Here H means sha256 of the
 * compressed serialization of the key.
 */
int secp256k1_whitelist_sign (
    const(secp256k1_context)* ctx,
    secp256k1_whitelist_signature* sig,
    const(secp256k1_pubkey)* online_pubkeys,
    const(secp256k1_pubkey)* offline_pubkeys,
    const size_t n_keys,
    const(secp256k1_pubkey)* sub_pubkey,
    const(ubyte)* online_seckey,
    const(ubyte)* summed_seckeyx,
    const size_t index);

/** Verify a whitelist signature
 * Returns 1: signature is valid
 *         0: signature is not valid
 * In:     ctx: pointer to a context object (not secp256k1_context_static)
 *         sig: the signature to be verified
 *         online_pubkeys: list of all online pubkeys
 *         offline_pubkeys: list of all offline pubkeys
 *         n_keys: the number of entries in each of the above two arrays
 *         sub_pubkey: the key to be whitelisted
 */
int secp256k1_whitelist_verify (
    const(secp256k1_context)* ctx,
    const(secp256k1_whitelist_signature)* sig,
    const(secp256k1_pubkey)* online_pubkeys,
    const(secp256k1_pubkey)* offline_pubkeys,
    const size_t n_keys,
    const(secp256k1_pubkey)* sub_pubkey);

