// /// \file HashChain.d
module tagion.hashchain.HashChain;

import std.algorithm : filter, map;
import std.array : array;
import std.file : exists, mkdirRecurse, dirEntries, SpanMode;
import std.path : buildPath, baseName, extension, setExtension, stripExtension;
import std.typecons : Tuple;

import tagion.basic.Types : Buffer, FileExtension, withDot;
import tagion.basic.TagionExceptions : TagionException;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.dart.Recorder : RecordFactory;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONRecord : fread, fwrite, isHiBONRecord;
import tagion.utils.Miscellaneous : toHexString, decode;

/** @brief File contains class HashChain
 */

// TODO: temp soultion
@safe FileExtension getExtension()
{
    return FileExtension.recchainblock;
}

/**
 * \class HashChain
 * Class stores dynamic info and handles local files of hash chain
 */
@safe class HashChain(Block : HashChainBlock) if (isHiBONRecord!Block)
{
    alias BlocksInfo = Tuple!(Block, "first", Block, "last", ulong, "amount");

    /** Path to local folder where chain files are stored */
    const string folder_path;
    /** Hash net */
    const HashNet net;

    protected
    {
        /** First block in chain */
        Block _first_block;
        /** Last block in chain */
        Block _last_block;
        /** Amount of files in chain */
        ulong _amount;
    }

    enum EPOCH_BLOCK_FILENAME_LEN = StdHashNet.HASH_SIZE * 2;

    /** Ctor initializes database and reads existing data.
     *      @param folder_path - path to folder with chain files
     */
    this(string folder_path, const HashNet net)
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
     *      \return amount of blocks in chain
     */
    @property ulong getAmount() const pure nothrow @nogc
    {
        return _amount;
    }

    /** Get first block
     *      \return first block in chain
     */
    @property const(Block) getFirstBlock() const pure nothrow @nogc
    {
        return _first_block;
    }

    /** Get last block
     *      \return last block in chain
     */
    @property const(Block) getLastBlock() const pure nothrow @nogc
    {
        return _last_block;
    }

    /** Adds given block to the end of chain
     *      @param block - block to append to chain
     */
    void push(Block block)
    {
        fwrite(makePath(block.getHash, folder_path), block.toHiBON);

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
            .filter!(filename => filename.extension == getExtension.withDot)
            .filter!(filename => filename.stripExtension.length == EPOCH_BLOCK_FILENAME_LEN)
            .array;
    }

    /** Static method that collects info about blocks in given folder 
     *      @param folder_path - path to folder with blocks
     *      @param net - hash net
     *      \return BlocksInfo - first, last blocks and amount
     */
    static BlocksInfo getBlocksInfo(string folder_path, const HashNet net)
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

            link_table[fingerprint] = block.getPrevious;
        }

        // search for the last block
        foreach (fingerprint; link_table.keys)
        {
            bool is_last_block = true;
            // search through all previous blocks with fixed current block
            foreach (previous; link_table.values)
            {
                // last block can't be previous for another block
                if (fingerprint == previous)
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
        foreach (previous; link_table.values)
        {
            bool found_prev_block = false;
            // search through all blocks with fixed previous block
            foreach (fingerprint; link_table.keys)
            {
                // there's existent block for fixed previous block
                if (previous == fingerprint)
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
                    if (link_table[fingerprint] == previous)
                    {
                        info.first = readBlock(fingerprint, folder_path, net);
                    }
                }
            }
            found_prev_block = false;
        }

        return info;
    }

    /** Static method that reads files with given fingerprint and creates block from read data
     *      @param net - hash net
     *      @param fingerprint - fingerprint of block to read
     *      @param folder_path - path to folder with blocks
     *      \return chain block, or null if block file doesn't exist
     */
    static Block readBlock(Buffer fingerprint, string folder_path, const HashNet net)
    {
        const block_filename = makePath(fingerprint, folder_path);
        if (!block_filename.exists)
        {
            return null;
        }

        try
        {
            auto doc = fread(block_filename);
            return new Block(doc);
        }
        catch (TagionException e)
        {
            return null;
        }
    }

    /**
    * Used to find next block in chain
    * @param cur_fingerprint - fingerprint of current block of chain
    * @param folder_path - folder with files of chain
    * @param net - hash net to read block from file
    * @return block from chain
    */
    static Block findNextBlock(Buffer cur_fingerprint, string folder_path, const HashNet net)
    {
        auto block_filenames = HashChain.getBlockFilenames(folder_path);
        foreach (filename; block_filenames)
        {
            auto fingerprint = decode(filename.stripExtension);
            auto block = HashChain.readBlock(fingerprint, folder_path, net);
            if (block.getPrevious)
            {
                if (block.getPrevious == cur_fingerprint)
                {
                    return block;
                }
            }
        }
        return null;
    }

    /**
    * Static method that checks validity of chain in given folder
    * @param folder_path - folder with files of chain
    * @param net - hash net to read blocks
    * @return true is chain is valid, false - otherwise
    */
    static bool isValidChain(string folder_path, const HashNet net)
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

            Block cur_block = info.last;
            // iterate to the first block
            foreach (i; 1 .. info.amount)
            {
                auto block = readBlock(cur_block.getPrevious, folder_path, net);
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
     *      \return path to block with given fingerprint
     */
    static string makePath(Buffer fingerprint, string folder_path)
    {
        return buildPath(
            folder_path,
            fingerprint.toHexString.setExtension(getExtension));
    }
}
