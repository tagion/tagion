// /// \file HashChain.d
module tagion.hashchain.HashChain;

import std.range : empty;
import std.range.primitives : back, popBack;

import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Fingerprint;
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
@safe class HashChain(Block : HashChainBlock) if (isHiBONRecord!Block) {
    /** Handler of chain blocks storage */
    protected HashChainStorage!Block _storage;

    /** Last block in chain */
    protected Block _last_block;

    /** Ctor initializes database and reads existing data.
     *      @param folder_path - path to folder with chain files
     */
    this(ref HashChainStorage!Block storage) {
        this._storage = storage;
        this._last_block = findLastBlock();
    }

    /** Method that finds the last block in chain
    *       \return last block or null if it haven't found
    */
    final protected Block findLastBlock() {
        auto hashes = _storage.getHashes;

        // Table for searching where
        //      key: fingerprints of blocks
        //      value: previous hashes of this blocks
        Fingerprint[Fingerprint] link_table;
        foreach (hash; hashes) {
            link_table[hash] = _storage.read(hash).getPrevious;
        }

        foreach (fingerprint; link_table.keys) {
            bool is_last_block = true;

            // Search through all previous hashes for fixed fingerprint
            foreach (previous; link_table.values) {
                // Last block can't be previous for another block
                if (fingerprint == previous) {
                    is_last_block = false;
                    break;
                }
            }

            if (is_last_block) {
                return _storage.read(fingerprint);
            }
        }

        return null;
    }

    /** Get last block
     *      \return last block in chain
     */
    const(Block) getLastBlock() const pure nothrow @nogc {
        return _last_block;
    }

    /** Adds given block to the end of chain
     *      @param block - block to append to chain
     */
    void append(Block block)
    in {
        assert(block !is null);
        if (_last_block is null) {
            assert(block.isRoot);
        }
        else {
            assert(block.getPrevious == _last_block.getHash);
        }
    }
    do {
        _storage.write(block);
        _last_block = block;
    }

    /** Method that checks validity of chain
    *       \return true is chain is valid, false - otherwise
    */
    bool isValidChain() {
        try {
            auto blocks_count = _storage.getHashes.length;
            if (blocks_count == 0) {
                // Empty chain
                return true;
            }

            auto first_block = _storage.find((block) => block.isRoot);
            if (first_block is null || _last_block is null) {
                // Non-empty chain is invalid
                return false;
            }

            // Iterate from the last to the first block
            auto current_block = _last_block;
            foreach (i; 1 .. blocks_count) {
                auto block = _storage.read(current_block.getPrevious);
                if (block is null) {
                    return false;
                }
                current_block = block;
            }

            // If reached block is first block - chain is valid
            return current_block.toDoc.serialize == first_block.toDoc.serialize;
        }
        catch (Exception e) {
            // Any other scenario - chain is invalid
            return false;
        }
    }

    void replay(void delegate(Block) @safe action) {
        // Replay from beginning with no condition
        replayFrom(action, (block) => (false));
    }

    void replayFrom(void delegate(Block) @safe action, bool delegate(Block) @safe condition) {
        // If we start from found block (not next after it) we possible can duplicate records

        Fingerprint[] hash_stack;

        // Go through hash chain until condition is triggered
        auto current_block = _last_block;

        while (current_block !is null && !condition(current_block)) {
            hash_stack ~= current_block.getHash;
            current_block = storage.read(current_block.getPrevious);
        }

        // Apply action in LIFO order
        while (!hash_stack.empty) {
            auto block = storage.read(hash_stack.back);
            assert(block !is null);

            action(block);

            hash_stack.popBack;
        }
    }

    final HashChainStorage!Block storage() {
        return _storage;
    }
}

version (unittest) {
    import tagion.hibon.HiBONRecord : HiBONRecord, recordType, label, exclude;
    import tagion.crypto.SecureInterfaceNet : HashNet;

    @safe class DummyBlock : HashChainBlock {
        @exclude Fingerprint hash;
        @label("prev") Fingerprint previous;
        @label("dummy") int dummy;

        mixin HiBONRecord!(
                q{
            private this(
                Fingerprint previous,
                const(HashNet) net,
                int dummy = 0)
            {
                this.previous = previous;
                this.dummy = dummy;

                this.hash = net.calcHash(toDoc);
            }

            private this(
                const(Document) doc,
                const(HashNet) net)
            {
                this(doc);
                this.hash = net.calcHash(toDoc);
            }
        });

        Fingerprint getHash() const {
            return hash;
        }

        Fingerprint getPrevious() const {
            return previous;
        }
    }
}

unittest {
    import std.file : rmdirRecurse;
    import std.path : extension, stripExtension;
    import std.range.primitives : back;

    import tagion.basic.basic : tempfile;
    import tagion.basic.Types : Buffer, FileExtension;
    import tagion.communication.HiRPC : HiRPC;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.dart.Recorder : RecordFactory;
    import tagion.hashchain.HashChainFileStorage;

    HashNet net = new StdHashNet;

    const empty_hash = Fingerprint.init;
    const temp_folder = tempfile ~ "/";

    alias Storage = HashChainStorage!DummyBlock;
    alias StorageImpl = HashChainFileStorage!DummyBlock;
    alias ChainImpl = HashChain!DummyBlock;

    /// HashChain_empty_folder
    {
        Storage storage = new StorageImpl(temp_folder, net);
        auto chain = new ChainImpl(storage);

        assert(chain.getLastBlock is null);
        assert(chain.isValidChain);

        rmdirRecurse(temp_folder);
    }

    /// HashChain_single_block
    {
        Storage storage = new StorageImpl(temp_folder, net);
        auto chain = new ChainImpl(storage);

        auto block0 = new DummyBlock(empty_hash, net);
        chain.append(block0);

        assert(chain.getLastBlock.toDoc.serialize == block0.toDoc.serialize);
        assert(chain.isValidChain);

        // Amount of blocks
        assert(chain.storage.getHashes.length == 1);

        // Find block with given hash
        auto found_block = chain.storage.find((b) => (b.getHash == block0.getHash));
        assert(found_block !is null && found_block.toDoc.serialize == block0.toDoc.serialize);

        rmdirRecurse(temp_folder);
    }

    /// HashChain_many_blocks
    {
        Storage storage = new StorageImpl(temp_folder, net);
        auto chain = new ChainImpl(storage);

        auto block0 = new DummyBlock(Fingerprint.init, net);
        chain.append(block0);
        auto block1 = new DummyBlock(chain.getLastBlock.getHash, net);
        chain.append(block1);
        auto block2 = new DummyBlock(chain.getLastBlock.getHash, net);
        chain.append(block2);

        assert(chain.getLastBlock.toDoc.serialize == block2.toDoc.serialize);
        assert(chain.isValidChain);

        // Amount of blocks
        assert(chain.storage.getHashes.length == 3);

        // Find root block
        auto found_block = chain.storage.find((b) => b.isRoot);
        assert(found_block !is null && found_block.toDoc.serialize == block0.toDoc.serialize);

        rmdirRecurse(temp_folder);
    }

    /// HashChain_replay
    {
        Storage storage = new StorageImpl(temp_folder, net);
        auto chain = new ChainImpl(storage);

        auto block0 = new DummyBlock(Fingerprint.init, net);
        chain.append(block0);
        auto block1 = new DummyBlock(chain.getLastBlock.getHash, net);
        chain.append(block1);
        auto block2 = new DummyBlock(chain.getLastBlock.getHash, net);
        chain.append(block2);

        assert(chain.isValidChain);

        Fingerprint[] hashes;

        chain.replay((DummyBlock b) @safe { hashes ~= b.getHash; });

        assert(hashes.length == 3);
        assert(hashes[0] == block0.getHash);
        assert(hashes[1] == block1.getHash);
        assert(hashes[2] == block2.getHash);

        rmdirRecurse(temp_folder);
    }

    /// HashChain_replayFrom
    {
        Storage storage = new StorageImpl(temp_folder, net);
        auto chain = new ChainImpl(storage);

        enum blocks_count = 10;
        DummyBlock[] blocks;

        // Add blocks
        foreach (i; 0 .. blocks_count) {
            auto last_block = chain.getLastBlock;

            blocks ~= new DummyBlock(last_block is null ? Fingerprint.init : last_block.getHash, net);

            chain.append(blocks.back);
        }
        assert(chain.isValidChain);

        enum some_block_index = 2;
        Fingerprint[] hashes;

        // Replay from block with specified index
        chain.replayFrom((DummyBlock b) @safe { hashes ~= b.getHash; }, (b) => b.getHash == blocks[some_block_index]
            .getHash);

        // Check array with hashes
        assert(hashes.length == blocks_count - some_block_index - 1);
        foreach (i, hash; hashes) {
            assert(hashes[i] == blocks[i + some_block_index + 1].getHash);
        }

        rmdirRecurse(temp_folder);
    }
}
