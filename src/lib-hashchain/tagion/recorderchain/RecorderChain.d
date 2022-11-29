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
    import std.file : rmdirRecurse, copy;
    import std.range : empty;

    import tagion.basic.Basic : tempfile;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.dart.DART : DART;
    import tagion.dart.Recorder;
    import tagion.script.StandardRecords : StandardBill;
    import tagion.script.TagionCurrency : TGN;

    const temp_folder = tempfile ~ "/";
    const chain_folder = temp_folder ~ "chain/";

    const dart_filename = temp_folder ~ "dart.drt";
    const dart_recovered_filename = temp_folder ~ "recovered.drt";
    const dart_genesis_filename = temp_folder ~ "genesis.drt";

    SecureNet net = new StdSecureNet;
    auto factory = RecordFactory(net);

    net.generateKeyPair("very secret password");

    StandardBill[] makeBills(uint seed)
    {
        SecureNet secure_net = new StdSecureNet;
        {
            secure_net.generateKeyPair("secure_net secret password");
        }

        uint epoch = 42;
        StandardBill[] bills;

        bills ~= StandardBill((1000 + seed * 10).TGN, epoch, secure_net.pubkey, null);
        bills ~= StandardBill((1200 + seed * 10).TGN, epoch, secure_net.derivePubkey("secure_net0"), null);
        bills ~= StandardBill((3000 + seed * 10).TGN, epoch, secure_net.derivePubkey("secure_net1"), null);
        bills ~= StandardBill((4300 + seed * 10).TGN, epoch, secure_net.derivePubkey("secure_net2"), null);

        return bills;
    }

    /// RecorderChain_replay_no_genesis
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(chain_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // In loop fill DART and add blocks
        enum blocks_count = 10;
        foreach (i; 0 .. blocks_count)
        {
            const bills_recorder = factory.recorder(makeBills(i));
            dart.modify(bills_recorder, Add);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? [] : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(bills_recorder.toDoc, previous_hash, dart.fingerprint, net));
        }

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain.storage.find(
                (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                block_last_bullseye.toDoc.serialize == recorder_chain.getLastBlock.toDoc.serialize);
        }

        // Create new empty DART for recovery
        DART.create(dart_recovered_filename);
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks
        {
            recorder_chain.replay((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            });
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_replay_genesis
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(chain_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // Add something to DART and make genesis
        const genesis_recorder = factory.recorder(makeBills(11));
        dart.modify(genesis_recorder, Add);
        dart_filename.copy(dart_genesis_filename);

        // In loop fill DART and add blocks
        enum blocks_count = 10;
        foreach (i; 0 .. blocks_count)
        {
            const bills_recorder = factory.recorder(makeBills(i));
            dart.modify(bills_recorder, Add);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? [] : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(bills_recorder.toDoc, previous_hash, dart.fingerprint, net));
        }

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain.storage.find(
                (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                block_last_bullseye.toDoc.serialize == recorder_chain.getLastBlock.toDoc.serialize);
        }

        // Create new empty DART for recovery from saved genesis DART
        dart_genesis_filename.copy(dart_recovered_filename);
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks
        {
            recorder_chain.replay((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            });
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_replayFrom
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(chain_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // In loop fill DART and add blocks
        enum blocks_count = 10;
        enum some_block_index = 4;
        foreach (i; 0 .. blocks_count)
        {
            const bills_recorder = factory.recorder(makeBills(i));
            dart.modify(bills_recorder, Add);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? [] : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(bills_recorder.toDoc, previous_hash, dart.fingerprint, net));

            // In the middle of the chain copy dart that will be "outdated"
            if (i == some_block_index)
            {
                dart_filename.copy(dart_recovered_filename);
            }
        }

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain.storage.find(
                (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                block_last_bullseye.toDoc.serialize == recorder_chain.getLastBlock.toDoc.serialize);
        }

        // Open outdated DART for recovery
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks from the middle of chain
        {
            recorder_chain.replayFrom((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            },
                (b) => (b.bullseye == dart_recovered.fingerprint));
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
    }
}
