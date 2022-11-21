// /// \file HashChain.d
module tagion.hashchain.HashChain;

import std.range : empty;
import std.range.primitives : back, popBack;

import tagion.basic.Types : Buffer;
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
    this(ref HashChainStorage!Block storage)
    {
        this._storage = storage;
        this._last_block = findLastBlock();
    }

    /** Method that finds the last block in chain
    *       \return last block or null if it haven't found
    */
    final protected Block findLastBlock()
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
    *       \return true is chain is valid, false - otherwise
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
        replayFrom(action, (block) => (block.getPrevious.empty));
    }

    void replayFrom(void delegate(Block) @safe action, bool delegate(Block) @safe condition)
    {
        // If we start from found block (not next after it) we possible can duplicate records

        Buffer[] hash_stack;

        // Go through hash chain until condition is triggered
        auto current_block = _last_block;
        while (current_block !is null)
        {
            hash_stack ~= current_block.getHash;

            if (condition(current_block))
            {
                break;
            }

            current_block = storage.read(current_block.getPrevious);
        }

        // Apply action in LIFO order
        while (!hash_stack.empty)
        {
            auto block = storage.read(hash_stack.back);
            assert(block !is null);

            action(block);

            hash_stack.popBack;
        }
    }

    HashChainStorage!Block storage()
    {
        return _storage;
    }
}
