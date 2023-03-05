/// \file HashChainStorage.d
module tagion.hashchain.HashChainStorage;

import tagion.crypto.Types : Fingerprint;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONRecord : isHiBONType;

/** @brief File contains interface for HashChainStorage
 */

/**
 * \interface HashChainStorage
 * Interface represents entity that provides access to storage of hash chain blocks
 */
@safe interface HashChainStorage(Block : HashChainBlock) if (isHiBONType!Block) {
    /** Writes given block to storage 
     *      @param block - block to write
     */
    void write(const(Block) block);

    /** Reads block with given fingerprint from storage 
     *      @param fingerprint - fingerprint of block to read
     *      \return block with given fingerprint, null - if such block doesn't exist
     */
    Block read(Fingerprint fingerprint);

    /** Finds block that satisfies given predicate 
     *      @param predicate - predicate for block
     *      \return block if search was successfull, null - if such block doesn't exist
     */
    Block find(bool delegate(Block) @safe predicate);

    /** Return list of all hashes in storage
     *      \return list of hashes
     */
    Fingerprint[] getHashes();
}
