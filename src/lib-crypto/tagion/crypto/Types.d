/// Declared types used in the crypto package
module tagion.crypto.Types;

import std.typecons : Typedef;

import tagion.basic.Types : Buffer;

enum BufferType {
    PUBKEY, /// Public key buffer type
    PRIVKEY, /// Private key buffer type
    SIGNATURE, /// Signature buffer type
    HASHPOINTER, /// Hash pointre buffer type
    MESSAGE, /// Message buffer type
    //    PAYLOAD /// Payload buffer type
}

/** 
 * Defines the public-key
 */
alias Pubkey = Typedef!(Buffer, null, BufferType.PUBKEY.stringof); /// Buffer used for public keys
/**
 * Defines the private key
 */
alias Privkey = Typedef!(Buffer, null, BufferType.PRIVKEY.stringof); /// Private key

/**
 * Defines the digital signature
 */
alias Signature = Typedef!(Buffer, null, BufferType.SIGNATURE.stringof); /// Signarure of message

/**
* Used as hash-pointer of a Document and is used as index in the DART
* This document can contain a '#' value and there for it should not be used as a signed message.
*/
alias Fingerprint = Typedef!(Buffer, null, BufferType.MESSAGE.stringof);
