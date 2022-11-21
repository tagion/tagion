// /// \file HashChain.d
module tagion.hashchain.HashChain;

import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.utils.Miscellaneous : decode;

/** @brief File contains class HashChain
 */

/**
 * \class HashChain
 * Class stores dynamic info and handles local files of hash chain
 */
@safe class HashChain(Block : HashChainBlock) if (isHiBONRecord!Block)
{
    /** Handler of chain blocks storage */
    protected HashChainStorage!Block _storage;

    /** Last block in chain */
    protected Block _last_block;

    /** Ctor initializes database and reads existing data.
     *      @param folder_path - path to folder with chain files
     */
    this(ref HashChainStorage!Block storage, const HashNet net)
    {
        this._storage = storage;

        @safe Block findLastBlock()
        {
            auto hashes = _storage.getHashes;

            // Table for searching where
            //      key: fingerprints of blocks
            //      value: previous hashes of this blocks
            Buffer[Buffer] link_table;
            foreach (hash; hashes)
            {
                Buffer fingerprint = decode(hash);
                auto block = _storage.read(fingerprint);

                link_table[fingerprint] = block.getPrevious;
            }

            foreach (fingerprint; link_table.keys)
            {
                bool is_last_block = true;

                // Search through all previous hashes for fixed fingerprint
                foreach (previous; link_table.values)
                {
                    // Last block can't be previous for another block
                    if (fingerprint == previous)
                    {
                        is_last_block = false;
                        break;
                    }
                }

                if (is_last_block)
                {
                    return _storage.read(fingerprint);
                }
            }

            return null;
        }

        this._last_block = findLastBlock();
    }

    /** Get last block
     *      \return last block in chain
     */
    const(Block) getLastBlock() const pure nothrow @nogc
    {
        return _last_block;
    }

    /** Adds given block to the end of chain
     *      @param block - block to append to chain
     */
    void append(Block block)
    {
        _storage.write(block);
        _last_block = block;
    }

    /** Method that checks validity of chain
    *       @return true is chain is valid, false - otherwise
    */
    bool isValidChain()
    {
        try
        {
            auto blocks_count = _storage.getHashes.length;
            auto first_block = _storage.find((block) => block.getPrevious == []);
            if (blocks_count == 0 && first_block is null && _last_block is null)
            {
                // Empty chain
                return true;
            }

            if (first_block is null || _last_block is null)
            {
                // Chain is invalid
                return false;
            }

            // Iterate from the last to the first block
            auto current_block = _last_block;
            foreach (i; 1 .. blocks_count)
            {
                auto block = _storage.read(current_block.getPrevious);
                if (block is null)
                {
                    return false;
                }
                current_block = block;
            }

            // If reached block is first block - chain is valid
            return current_block.toDoc.serialize == first_block.toDoc.serialize;
        }
        catch (Exception e)
        {
            // Any other scenario - chain is invalid
            return false;
        }
    }

    void replay(void delegate(Block) @safe action)
    {
        // TODO: foreach block action
    }

    void replayFrom(void delegate(Block) @safe action, bool delegate(Block) @safe condition)
    {
        // TODO: search from last to first until condition(block) and then foreach block action(block)
    }

    HashChainStorage!Block storage()
    {
        return _storage;
    }
}
