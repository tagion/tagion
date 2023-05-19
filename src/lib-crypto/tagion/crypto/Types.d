/// Declared types used in the crypto package
module tagion.crypto.Types;

import std.typecons : Typedef;

import tagion.basic.Types : Buffer;

/** 
 * Defines the public-key
 */
alias Pubkey = Typedef!(Buffer, null, "PUBKEY"); /// Buffer used for public keys
/**
 * Defines the private key
 */
alias Privkey = Typedef!(Buffer, null, "PRIVKEY"); /// Private key

/**
 * Defines the digital signature
 */
alias Signature = Typedef!(Buffer, null, "SIGNATURE"); /// Signarure of message

/**
* Used as hash-pointer of a Document and is used as index in the DART
* This document can contain a '#' value and there for it should not be used as a signed message.
*/
alias Fingerprint = Typedef!(Buffer, null, "MESSAGE");

