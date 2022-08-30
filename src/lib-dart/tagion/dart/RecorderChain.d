/// \file RecorderChain.d
module tagion.dart.RecorderChain;

import std.file : exists, mkdirRecurse, dirEntries, SpanMode;
import std.array : array;
import std.typecons : Tuple;
import std.path : buildPath, baseName, extension, setExtension, stripExtension;
import std.algorithm : filter, map;

import tagion.basic.Types : Buffer, FileExtension, withDot;
import tagion.basic.TagionExceptions : TagionException;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.RecorderChainBlock : RecorderChainBlock, RecorderChainBlockFactory;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONRecord : fread, fwrite;
import tagion.utils.Miscellaneous : toHexString, decode;

/** @brief File contains structure RecorderChain
 */

/**
 * \struct RecorderChain
 * Struct stores info and handles local files of recorder chain
 */
@safe class RecorderChain
{
    alias BlocksInfo = Tuple!(RecorderChainBlock, "first", RecorderChainBlock, "last", ulong, "amount");

    /** Path to local folder where recorder chain files are stored */
    const string folder_path;
    /** Hash net */
    const StdHashNet net;

    private
    {
        /** First block in local chain */
        RecorderChainBlock _first_block;
        /** Last block in local chain */
        RecorderChainBlock _last_block;
        /** Amount of files in local chain */
        ulong _amount;
    }

    enum EPOCH_BLOCK_FILENAME_LEN = StdHashNet.HASH_SIZE * 2;

    /** Ctor initializes database and reads existing data.
     *      @param folder_path - path to folder with block biles
     */
    this(string folder_path, const StdHashNet net)
    {
        this.net = net;
        this.folder_path = folder_path;

        if (!exists(this.folder_path))
            mkdirRecurse(this.folder_path);

        if (getBlockFilenames(folder_path).length)
        {
            auto info = getBlocksInfo(this.folder_path, this.net);
            this._first_block = info.first;
            this._last_block = info.last;
            this._amount = info.amount;
        }
    }

    /** Get amount
     *      \return member amount
     */
    @property ulong getAmount() const pure nothrow @nogc
    {
        return _amount;
    }

    /** Get first block
     *      \return member first block
     */
    @property const(RecorderChainBlock) getFirstBlock() const pure nothrow @nogc
    {
        return _first_block;
    }

    /** Get last block
     *      \return member last block
     */
    @property const(RecorderChainBlock) getLastBlock() const pure nothrow @nogc
    {
        return _last_block;
    }

    /** Adds given block to the end of recorder chain
     *      @param block - block to add to recorder chain
     */
    void push(RecorderChainBlock block)
    {
        fwrite(makePath(block.fingerprint, folder_path), block.toHiBON);

        _last_block = block;
        if (_amount == 0)
        {
            _first_block = block;
        }

        _amount++;
    }

    /** Static method that collects all block filenames in given folder 
     *      @param folder_path - path to folder with blocks
     *      \return array of block filenames in this folder
     */
    static string[] getBlockFilenames(string folder_path) @trusted
    {
        return folder_path.dirEntries(SpanMode.shallow)
            .filter!(a => a.isFile())
            .map!(a => baseName(a))
            .filter!(filename => filename.extension == FileExtension.recchainblock.withDot)
            .filter!(filename => filename.stripExtension.length == EPOCH_BLOCK_FILENAME_LEN)
            .array;
    }

    /** Static method that collects info about blocks in given folder 
     *      @param folder_path - path to folder with blocks
     *      @param net - hash net
     *      \return BlocksInfo - first, last blocks and amount
     */
    static BlocksInfo getBlocksInfo(string folder_path, const StdHashNet net)
    {
        BlocksInfo info;

        auto filenames = getBlockFilenames(folder_path);
        info.amount = filenames.length;

        // Map that stores fingerprints, where key - block, value - previous block
        Buffer[Buffer] link_table;
        foreach (block_filename; filenames)
        {
            auto fingerprint = decode(block_filename.stripExtension);
            auto block = readBlock(fingerprint, folder_path, net);

            link_table[fingerprint] = block.chain;
        }

        // search for the last block
        foreach (fingerprint; link_table.keys)
        {
            bool is_last_block = true;
            // search through all "previous" blocks with fixed block
            foreach (chain; link_table.values)
            {
                // last block can't be previous for another block
                if (fingerprint == chain)
                {
                    is_last_block = false;
                    break;
                }

            }

            if (is_last_block)
            {
                info.last = readBlock(fingerprint, folder_path, net);
                break;
            }
        }

        // search for the first block
        foreach (chain; link_table.values)
        {
            bool found_prev_block = false;
            // search through all blocks with fixed "previous" block
            foreach (fingerprint; link_table.keys)
            {
                // there's existent block for fixed "previous" block
                if (chain == fingerprint)
                {
                    found_prev_block = true;
                    break;
                }
            }
            if (!found_prev_block)
            {
                // search for block that has current chain
                foreach (fingerprint; link_table.keys)
                {
                    if (link_table[fingerprint] == chain)
                    {
                        info.first = readBlock(fingerprint, folder_path, net);
                    }
                }
            }
            found_prev_block = false;
        }

        return info;
    }

    /** Static method that reads files with given fingerprint and creates block
     *      @param net - hash net
     *      @param fingerprint - fingerprint of block to read
     *      @param folder_path - path to folder with blocks
     *      \return recorder chain block, or null if block file doesn't exist
     */
    static RecorderChainBlock readBlock(Buffer fingerprint, string folder_path, const StdHashNet net)
    {
        const block_filename = makePath(fingerprint, folder_path);
        if (!block_filename.exists)
        {
            return null;
        }

        try
        {
            auto doc = fread(block_filename);
            auto factory = RecorderChainBlockFactory(net);
            return factory(doc);

        }
        catch (TagionException e)
        {
            return null;
        }
    }

<<<<<<< HEAD
    /** 
    * Used find next block in recorder block chain
    * @param cur_fingerprint - fingerprint of current block from recorder block chain
    * @param folder_path - folder with blocks from recorder block chain
    * @param net - to read block from file
    * @return block from recorder block chain
    */
    static RecorderChainBlock findNextDARTBlock(Buffer cur_fingerprint, string folder_path, const StdHashNet net) 
    {
        auto block_filenames = RecorderChain.getBlockFilenames(folder_path);
        foreach (filename; block_filenames)
        {
            auto fingerprint = decode(filename.stripExtension);
            auto block = RecorderChain.readBlock(fingerprint, folder_path, net);
            if(block.chain) 
            {
                if (block.chain == cur_fingerprint)
                {
                    return block;
                }
            }
        }
        throw new TagionException("Next block not exist");
        return null;
    }
    
    /** 
     * Used find current block in recorder block chain
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
        throw new TagionException("Current block not exist");
        return null;
    }
    
    static bool isValidChain(string folder_path, const StdHashNet net)
    {
        try
        {
            auto info = getBlocksInfo(folder_path, net);
            if (info.amount == 0 && info.first is null && info.last is null)
            {
                // empty chain
                return true;
            }

            if (info.first is null || info.last is null)
            {
                // chain is invalid
                return false;
            }

            RecorderChainBlock cur_block = info.last;
            // iterate to the first block
            foreach (i; 1 .. info.amount)
            {
                auto block = readBlock(cur_block.chain, folder_path, net);
                if (block is null)
                {
                    return false;
                }
                cur_block = block;
            }
            // if reached block is first block - chain is valid
            return cur_block.toDoc.serialize == info.first.toDoc.serialize;
        }
        catch (Exception e)
        {
            // any other scenario - chain is invalid
            return false;
        }
    }

    /** Static method that creates path to block with given fingerprint
     *      @param fingerprint - fingerprint of block to make path
     *      @param folder_path - path to folder with blocks
     *      \return recorder chain block
     */
    static string makePath(Buffer fingerprint, string folder_path)
    {
        return buildPath(
            folder_path,
            fingerprint.toHexString.setExtension(FileExtension.recchainblock));
    }
}

unittest
{
    import std.range;
    import std.file : rmdirRecurse;
    import tagion.basic.Basic : tempfile;

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

    /// RecorderChain_findNextDARTBlock
    {
        recorder_chain = new RecorderChain(temp_folder, net);    

        auto block_next = RecorderChain.findNextDARTBlock(block0.fingerprint, temp_folder, net);
        assert(block_next.fingerprint ==  block1.fingerprint);
        block_next = RecorderChain.findNextDARTBlock(block_next.fingerprint, temp_folder, net);
        assert(block_next.fingerprint ==  block2.fingerprint);
    }

    /// RecorderChain_findCurrentDARTBlock
    {
        import tagion.dart.DART;
        import tagion.communication.HiRPC;
        import tagion.crypto.SecureNet;
        import tagion.dart.BlockFile;
        import tagion.dart.DARTFile;
        import tagion.crypto.SecureInterfaceNet : SecureNet;

        import std.stdio;

        SecureNet secure_net = new StdSecureNet;
        string passphrase = "verysecret";
        secure_net.generateKeyPair(passphrase);
        auto hirpc = HiRPC(secure_net);
        string dart_file = "tmp_DART";
        enum BLOCK_SIZE = 0x80;
        BlockFile.create(dart_file, DARTFile.stringof, BLOCK_SIZE);
        DART db = new DART(secure_net, dart_file, 0, 0);
        
        {
            auto recorder = factory.recorder(block0.recorder_doc);
            auto sended = DART.dartModify(recorder, hirpc);
            auto received = hirpc.receive(sended);
            db(received, false);
            auto current_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, temp_folder, net);
            assert(db.fingerprint == current_block.bullseye);
        }

        {
            auto recorder = factory.recorder(block1.recorder_doc);
            auto sended = DART.dartModify(recorder, hirpc);
            auto received = hirpc.receive(sended);
            db(received, false);
            auto current_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, temp_folder, net);
            assert(db.fingerprint == current_block.bullseye);
        }

        {
            auto recorder = factory.recorder(block2.recorder_doc);
            auto sended = DART.dartModify(recorder, hirpc);
            auto received = hirpc.receive(sended);
            db(received, false);
            auto current_block = RecorderChain.findCurrentDARTBlock(db.fingerprint, temp_folder, net);
            assert(db.fingerprint == current_block.bullseye);
        }
    }
}
