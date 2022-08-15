/// \file RecorderChain.d
module tagion.dart.RecorderChain;

import std.file : exists, mkdirRecurse, remove, dirEntries, SpanMode;
import std.array : array;
import std.typecons : Tuple;
import std.path : buildPath, baseName;
import std.algorithm : filter, map, reverse;

import tagion.basic.Types : Buffer;
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

    public
    {
        /** Path to local folder where recorder chain files are stored */
        const string folder_path;
        /** Hash net */
        const StdHashNet net;
    }

    /** First block in local chain */
    RecorderChainBlock m_first_block;
    /** Last block in local chain */
    RecorderChainBlock m_last_block;
    /** Amount of files in local chain */
    ulong m_amount;

    enum EPOCH_BLOCK_FILENAME_LEN = 64;

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
            this.m_first_block = info.first;
            this.m_last_block = info.last;
            this.m_amount = info.amount;
        }
    }

    /** Get amount
     *      \return member amount
     */
    @property ulong amount() const pure nothrow @nogc
    {
        return m_amount;
    }

    /** Get first block
     *      \return member first block
     */
    @property const(RecorderChainBlock) first_block() const pure nothrow @nogc
    {
        return m_first_block;
    }

    /** Get last block
     *      \return member last block
     */
    @property const(RecorderChainBlock) last_block() const pure nothrow @nogc
    {
        return m_last_block;
    }

    /** Adds given block to the end of recorder chain
     *      @param block - block to add to recorder chain
     */
    void push(RecorderChainBlock block)
    {
        fwrite(makePath(block.fingerprint, folder_path), block.toHiBON);

        m_last_block = block;
        if (m_amount == 0)
        {
            m_first_block = block;
        }

        m_amount++;
    }

    /** Static method that collects all block filenames in given folder 
     *      @param folder_path - path to folder with blocks
     *      \return array of block filenames in this folder
     */
    static string[] getBlockFilenames(string folder_path) @trusted
    {
        string[] block_filenames;

        auto all_filenames = dirEntries(folder_path, SpanMode.shallow).filter!(a => a.isFile())
            .map!(a => baseName(a));
        foreach (filename; all_filenames)
        {
            if (filename.length == EPOCH_BLOCK_FILENAME_LEN)
            {
                block_filenames ~= filename;
            }
        }
        return block_filenames;
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
            auto fingerprint = decode(block_filename);
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
        return buildPath(folder_path, fingerprint.toHexString);
    }
}
