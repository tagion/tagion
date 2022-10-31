/// \file RecorderChain.d
module tagion.recorderchain.RecorderChain;

import std.file : exists, mkdirRecurse, dirEntries, SpanMode;
import std.array : array;
import std.typecons : Tuple;
import std.path : buildPath, baseName, extension, setExtension, stripExtension;
import std.algorithm : filter, map;

import tagion.basic.Types : Buffer, FileExtension, withDot;
import tagion.basic.TagionExceptions : TagionException;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock, RecorderChainBlockFactory;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONRecord : fread, fwrite;
import tagion.utils.Miscellaneous : toHexString, decode; // TODO review imports

import tagion.hashchain.HashChain : HashChain;

/** @brief File contains class RecorderChain
 */

/**
 * \class RecorderChain
 * Class stores info and handles local files of recorder chain
 */
@safe final class RecorderChain : HashChain!(RecorderChainBlock, RecorderChainBlockFactory)
{
    /** Ctor initializes database and reads existing data.
     *      @param folder_path - path to folder with block biles
     */
    this(string folder_path, const StdHashNet net)
    {
        super(folder_path, net);
    }

    /** 
     * Used to find current block in recorder block chain, 
     * after block pushed to DART database, 
     * fingerprint of that DART becomes the bullseye of the block
     * @param cur_bullseye - bullseye of DART database
     * @param folder_path - folder with blocks from recorder block chain
     * @param net - to read block from file
     * @return block from recorder block chain
     */
    static RecorderChainBlock findCurrentDARTBlock(Buffer cur_bullseye, string folder_path, const StdHashNet net)
    {
        auto block_filenames = RecorderChain.getBlockFilenames(folder_path);
        foreach (filename; block_filenames)
        {
            auto fingerprint = decode(filename.stripExtension);
            auto block = RecorderChain.readBlock(fingerprint, folder_path, net);

            if (block.bullseye == cur_bullseye)
            {
                return block;
            }
        }
        return null;
    }
}

unittest
{
    import std.range;
    import std.file : rmdirRecurse;
    import tagion.basic.Basic : tempfile;
    import tagion.dart.DART;
    import tagion.communication.HiRPC;
    import tagion.crypto.SecureNet;
    import tagion.dart.BlockFile;
    import tagion.dart.DARTFile;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.hibon.HiBON : HiBON;
    import tagion.hibon.Document : Document;

    const net = new StdHashNet;

    auto factory = RecordFactory(net);
    immutable empty_recorder = cast(immutable) factory.recorder;
    const Buffer empty_bullseye = [];

    auto block_factory = RecorderChainBlockFactory(net);

    const temp_folder = tempfile ~ "/";

    /// RecorderChain_empty_folder
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        assert(recorder_chain.getAmount == 0);
        assert(recorder_chain.getFirstBlock is null);
        assert(recorder_chain.getLastBlock is null);

        assert(RecorderChain.getBlockFilenames(temp_folder).empty);
        assert(RecorderChain.isValidChain(temp_folder, net));

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_single_block
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        recorder_chain.push(block0);

        assert(recorder_chain.getAmount == 1);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block0);

        assert(RecorderChain.isValidChain(temp_folder, net));

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_many_blocks
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        recorder_chain.push(block0);
        auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
        recorder_chain.push(block1);
        auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);
        recorder_chain.push(block2);

        // Check chain info
        assert(recorder_chain.getAmount == 3);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block2);

        // Chain validity
        assert(RecorderChain.isValidChain(temp_folder, net));

        // Static info
        auto info = RecorderChain.getBlocksInfo(temp_folder, net);
        assert(info.amount == 3);
        assert(info.first.toDoc.serialize == block0.toDoc.serialize);
        assert(info.last.toDoc.serialize == block2.toDoc.serialize);

        // Files in folder
        auto block_filenames = RecorderChain.getBlockFilenames(temp_folder);
        assert(block_filenames.length == 3);
        foreach (filename; block_filenames)
        {
            assert(filename.extension == FileExtension.recchainblock.withDot);
        }

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_isValidChain_branch_chain
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        recorder_chain.push(block0);
        auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
        recorder_chain.push(block1);
        auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);
        recorder_chain.push(block2);

        // create another block that points to some block in the middle of chain
        // thus we have Y-style linked list which is invalid chain
        Buffer another_bullseye = [0, 1, 2, 3];
        auto block1_branch = block_factory(empty_recorder, block0.fingerprint, another_bullseye);
        recorder_chain.push(block1_branch);
        auto block2_branch = block_factory(empty_recorder, block1_branch.fingerprint, empty_bullseye);
        recorder_chain.push(block2_branch);

        // chain should be invalid
        assert(!RecorderChain.isValidChain(temp_folder, net));

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_loop_blocks
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
        auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);

        // create looped linked list where the first block points on the last one
        block0.chain = block2.fingerprint;

        recorder_chain.push(block0);
        recorder_chain.push(block1);
        recorder_chain.push(block2);

        // chain should be invalid
        assert(!RecorderChain.isValidChain(temp_folder, net));

        auto info = RecorderChain.getBlocksInfo(temp_folder, net);

        // amount not 0, but chain can't find first and last blocks
        assert(info.amount > 0);
        assert(info.first is null);
        assert(info.last is null);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_findNextBlock_valid_chain
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
        auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);

        recorder_chain.push(block0);
        recorder_chain.push(block1);
        recorder_chain.push(block2);

        auto block_next = RecorderChain.findNextBlock(block0.fingerprint, temp_folder, net);
        assert(block_next.fingerprint == block1.fingerprint);
        block_next = RecorderChain.findNextBlock(block_next.fingerprint, temp_folder, net);
        assert(block_next.fingerprint == block2.fingerprint);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_findNextBlock_not_valid_chain
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto block0 = block_factory(empty_recorder, [], empty_bullseye);
        auto block1 = block_factory(empty_recorder, [], empty_bullseye);

        recorder_chain.push(block0);
        recorder_chain.push(block1);

        auto block_next = RecorderChain.findNextBlock(block0.fingerprint, temp_folder, net);
        assert(block_next is null);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_findNextBlock_empty_chain
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);
        assert(RecorderChain.findNextBlock([], temp_folder, net) is null);
    }

    string dart_file = "tmp_DART";
    SecureNet secure_net = new StdSecureNet;
    string passphrase = "verysecret";
    secure_net.generateKeyPair(passphrase);
    BlockFile.create(dart_file, DARTFile.stringof, BLOCK_SIZE);
    DART db = new DART(secure_net, dart_file, 0, 0);

    /// RecorderChain_findCurrentDARTBlock_valid_chain
    {
        auto hirpc = HiRPC(secure_net);

        Buffer checkCurrentBlock(RecordFactory.Recorder recorder,
            DART db,
            HiRPC hirpc,
            RecorderChain recorder_chain,
            Buffer chain) const @trusted
        {
            immutable recorder_im = cast(immutable) recorder;
            auto sent = DART.dartModify(recorder_im, hirpc);
            auto received = hirpc.receive(sent);
            db(received, false);

            auto block = block_factory(recorder_im, chain, db.fingerprint);
            recorder_chain.push(block);
            // auto current_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, temp_folder, net);

            // assert(current_block.fingerprint == block.fingerprint);
            // assert(current_block.chain == block.chain);
            // assert(current_block.bullseye == block.bullseye);
            // assert(current_block.recorder_doc == block.recorder_doc);

            return block.fingerprint;
        }

        auto recorder_chain = new RecorderChain(temp_folder, net);

        auto recorder1_test = factory.recorder;
        auto recorder2_test = factory.recorder;
        auto recorder3_test = factory.recorder;

        HiBON h1 = new HiBON;
        h1["t"] = "test";
        HiBON h2 = new HiBON;
        h2["tt"] = "ttest";
        HiBON h3 = new HiBON;
        h3["ttt"] = "tttest";
        recorder1_test.add(Document(h1));
        recorder2_test.add(Document(h2));
        recorder3_test.add(Document(h3));

        Buffer fingerprint_1 = checkCurrentBlock(recorder1_test, db, hirpc, recorder_chain, [
            ]);
        Buffer fingerprint_2 = checkCurrentBlock(recorder2_test, db, hirpc, recorder_chain, fingerprint_1);
        checkCurrentBlock(recorder3_test, db, hirpc, recorder_chain, fingerprint_2);

        rmdirRecurse(temp_folder);
    }

    /// RecorderChain_findCurrentDARTBlock_empty_chain
    {
        auto recorder_chain = new RecorderChain(temp_folder, net);
        auto current_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, temp_folder, net);
        assert(current_block is null);

        rmdirRecurse(temp_folder);
    }
}
