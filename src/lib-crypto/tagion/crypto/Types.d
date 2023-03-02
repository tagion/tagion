module tagion.crypto.Types;

import std.typecons : Typedef;

import tagion.basic.Types : Buffer;

alias Pubkey = Typedef!(Buffer, null, "PUBKEY"); /// Buffer used for public keys
alias Signature = Typedef!(Buffer, null, "SIGNATURE"); /// Signarure of message
alias Privkey = Typedef!(Buffer, null, "PRIVKEY"); /// Private key

/**
* Used as hash-pointer of a Document and is used as index in the DART
* This document can contain a '#' value and there for it should not be used as a signed message.
*/
alias Fingerprint = Typedef!(Buffer, null, "MESSAGE");


