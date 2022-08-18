/// \file RecorderChain.d
module tagion.dart.RecorderChain;

import std.file : exists, mkdirRecurse, remove, dirEntries, SpanMode;
import std.array : array;
import std.typecons : Tuple;
import std.path : buildPath, baseName, extension, setExtension, stripExtension;
import std.algorithm : filter, map, reverse;

import tagion.basic.Types : Buffer, FileExtension, withDot;
import tagion.basic.TagionExceptions : TagionException;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.RecorderChainBlock : RecorderChainBlock, RecorderChainBlockFactory;
import tagion.dart.Recorder : RecordFactory, Archive;
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
    import tagion.basic.Basic : tempfile;

    const temp_folder = tempfile ~ "/";
    scope (exit)
    {
        import std.file : rmdirRecurse;

        rmdirRecurse(temp_folder);
    }

    const net = new StdHashNet;

    auto factory = RecordFactory(net);
    immutable empty_recorder = cast(immutable) factory.recorder;
    const Buffer empty_bullseye = [];

    RecorderChain recorder_chain;

    /// RecorderChain_empty_folder
    {
        recorder_chain = new RecorderChain(temp_folder, net);

        assert(recorder_chain.getAmount == 0);
        assert(recorder_chain.getFirstBlock is null);
        assert(recorder_chain.getLastBlock is null);
    }

    /// RecorderChain_getBlockFilenames_empty
    {
        import std.range;

        assert(RecorderChain.getBlockFilenames(temp_folder).empty);
    }

    auto block_factory = RecorderChainBlockFactory(net);
    auto block0 = block_factory(empty_recorder, [], empty_bullseye);

    /// RecorderChain_single_block
    {
        recorder_chain.push(block0);

        assert(recorder_chain.getAmount == 1);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block0);
    }

    auto block1 = block_factory(empty_recorder, block0.fingerprint, empty_bullseye);
    auto block2 = block_factory(empty_recorder, block1.fingerprint, empty_bullseye);

    /// RecorderChain_many_blocks
    {
        recorder_chain.push(block1);
        recorder_chain.push(block2);

        assert(recorder_chain.getAmount == 3);
        assert(recorder_chain.getFirstBlock is block0);
        assert(recorder_chain.getLastBlock is block2);
    }

    /// RecorderChain_static_getBlocksInfo
    {
        auto info = RecorderChain.getBlocksInfo(temp_folder, net);

        assert(info.amount == 3);
        assert(info.first.toDoc.serialize == block0.toDoc.serialize);
        assert(info.last.toDoc.serialize == block2.toDoc.serialize);
    }

    /// RecorderChain_getBlockFilenames_non_empty
    {
        auto block_filenames = RecorderChain.getBlockFilenames(temp_folder);
        assert(block_filenames.length == 3);
        foreach (filename; block_filenames)
        {
            assert(filename.extension == FileExtension.recchainblock.withDot);
        }
    }
}
