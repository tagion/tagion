/// \file RecorderChain.d
module tagion.recorderchain.RecorderChain;

import tagion.hashchain.HashChain : HashChain;
import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hashchain.HashChainFileStorage : HashChainFileStorage;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;

/** @brief File contains class RecorderChain
 */

/**
 * \class RecorderChain
 * Class stores info and handles local files of recorder chain
 */

alias RecorderChain = HashChain!(RecorderChainBlock);
alias RecorderChainStorage = HashChainStorage!RecorderChainBlock;
alias RecorderChainFileStorage = HashChainFileStorage!RecorderChainBlock;

unittest
{
    // import std.range;
    import std.file : rmdirRecurse;
    import std.path : extension, stripExtension;

    import tagion.basic.Basic : tempfile;
    import tagion.basic.Types : Buffer, FileExtension, withDot;
    import tagion.communication.HiRPC : HiRPC;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.crypto.SecureInterfaceNet : HashNet;
    import tagion.dart.Recorder : RecordFactory;

    // import tagion.dart.DART;
    // import tagion.dart.BlockFile;
    // import tagion.dart.DARTFile;
    // import tagion.hibon.HiBON : HiBON;
    // import tagion.hibon.Document : Document;

    HashNet net = new StdHashNet;

    auto factory = RecordFactory(net);
    immutable empty_recorder = cast(immutable) factory.recorder.toDoc;
    const Buffer empty_bullseye = [];
    const Buffer empty_hash = [];

    const temp_folder = tempfile ~ "/";

    /// RecorderChain_empty_folder
    {
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage, net);

        assert(recorder_chain.getLastBlock is null);
        assert(recorder_chain.isValidChain);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_single_block
    {
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage, net);

        auto block0 = new RecorderChainBlock(empty_recorder, empty_hash, empty_bullseye, net);
        recorder_chain.append(block0);

        assert(recorder_chain.getLastBlock.toDoc.serialize == block0.toDoc.serialize);
        assert(recorder_chain.isValidChain);

        // Amount of blocks
        assert(recorder_chain.storage.getHashes.length == 1);

        // Find block with given hash
        auto found_block = recorder_chain.storage.find((b) => (b.getHash == block0.getHash));
        assert(found_block !is null && found_block.toDoc.serialize == block0.toDoc.serialize);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_many_blocks
    {
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage, net);

        auto block0 = new RecorderChainBlock(empty_recorder, [], empty_bullseye, net);
        recorder_chain.append(block0);
        auto block1 = new RecorderChainBlock(empty_recorder, recorder_chain.getLastBlock.getHash, empty_bullseye, net);
        recorder_chain.append(block1);
        auto block2 = new RecorderChainBlock(empty_recorder, recorder_chain.getLastBlock.getHash, empty_bullseye, net);
        recorder_chain.append(block2);

        assert(recorder_chain.getLastBlock.toDoc.serialize == block2.toDoc.serialize);
        assert(recorder_chain.isValidChain);

        // Amount of blocks
        assert(recorder_chain.storage.getHashes.length == 3);

        // Find block with empty previous field
        auto found_block = recorder_chain.storage.find(
            (b) => b.getPrevious == []
        );
        assert(found_block !is null && found_block.toDoc.serialize == block0.toDoc.serialize);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_isValidChain_branch_chain
    {
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage, net);

        auto block0 = new RecorderChainBlock(empty_recorder, [], empty_bullseye, net);
        recorder_chain.append(block0);

        auto block1 = new RecorderChainBlock(empty_recorder, block0.getHash, empty_bullseye, net);
        recorder_chain.append(block1);

        auto block2 = new RecorderChainBlock(empty_recorder, block1.getHash, empty_bullseye, net);
        recorder_chain.append(block2);

        // create another block that points to some block in the middle of chain
        // thus we have Y-style linked list which is invalid chain
        Buffer another_bullseye = [0, 1, 2, 3];
        auto block1_branch = new RecorderChainBlock(empty_recorder, block0.getHash, another_bullseye, net);
        recorder_chain.append(block1_branch);

        auto block2_branch = new RecorderChainBlock(empty_recorder, block1_branch.getHash, empty_bullseye, net);
        recorder_chain.append(block2_branch);

        // chain should be invalid
        assert(!recorder_chain.isValidChain);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_loop_blocks
    {
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage, net);

        auto block0 = new RecorderChainBlock(empty_recorder, [], empty_bullseye, net);
        auto block1 = new RecorderChainBlock(empty_recorder, block0.getHash, empty_bullseye, net);
        auto block2 = new RecorderChainBlock(empty_recorder, block1.getHash, empty_bullseye, net);

        // create looped linked list where the first block points on the last one
        block0.previous = block2.getHash;

        recorder_chain.append(block0);
        recorder_chain.append(block1);
        recorder_chain.append(block2);

        // chain should be invalid
        assert(!recorder_chain.isValidChain);

        rmdirRecurse(temp_folder);
    }
}
