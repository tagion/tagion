# Change log

## Change log from alpha-one

- Options for the different part of the network has been divider up and moved to the different modules in related to the module.

- JSONCommon which takes care of the options .json file. Has been moved to it own module.

- Side channel problem in KeyRecorer has been fix (Still missing  second review)

- Consensus order for HashGraph Event has been changed to fix ambiguous comparator. 

- All the Wallet functions has been moved into one module SecureWallet.

- Data type handle Currency types has been add prevent illegal currency operations. The implementation can be found in TagionCurrency module.

- Bugs. HiBON valid function has been corrected.

- Hashgraph stability has been improved specially concerning the scrapping on used event. 

- Node address-book has been moved into a one shared object instead of make immutable copies between the threads.

- Boot strapping of the network in mode 1 has been changed.

- DART Recorder has been improved to support better range support.

- HiBONRecord has been removed

- HiBON types has been change to enable support of other key types then number and strings. (Support for other key types has not been implemented yet).

- Support for '#' keys in DART has been implemented, which enables support for NameRecords and other hash-key records.

- The statistician is now a HiBONRecord.

- Old funnel scripting has been removed opening up of TVM support.

- Asymmetric encryption module has been add base on secp256k1 DH.

- HiRPC has been improved to make it easier to create a sender and receiver.

- The build flow has been improved to enable easier build and test.

- The tools dartutil, hibonutil, tagionboot, tagionwave and tagionwallet has been re-factored to make it more readable.

  

  