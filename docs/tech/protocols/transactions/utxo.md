---
sidebar_position: 1
---

# UTXO's

Tagion uses a UTXO (Unspent Transaction Output) model as opposed to an account model.
This means that assets are stored in individual documents that each define an owner, instead of a single account document that changes state.
When a transaction occurs input UTXOs are deleted and outputs UTXOs are created.

In tagion a UTXO is a hibon document which defines the owner key `$Y`.

The owner key is a 33 byte public key.
Anyone who can proof that the public key is theirs by digitally signing a Contract(SMC) which includes the dartIndex of the archive,
can delete the archive and thereby spend it.

The most ubiquitous UTXO in tagion is the [tagion bill](/tech/protocols/transactions/bill)
