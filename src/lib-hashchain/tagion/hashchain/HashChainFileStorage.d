/// \file HashChainFileStorage.d
module tagion.hashchain.HashChainFileStorage;

import std.array : array;
import std.algorithm : filter, map;
import std.file;
import std.path;

import tagion.basic.Types : Buffer, FileExtension, withDot;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hibon.HiBONRecord : fread, fwrite;
import tagion.logger.Logger : log;
import tagion.utils.Miscellaneous : decode, toHexString;

/** @brief File contains class HashChainFileStorage
 */

/**
 * \class HashChainFileStorage
 * Implementation of hash chain storage, based on file system
 */
@safe class HashChainFileStorage(Block) : HashChainStorage!Block
{
    protected
    {
        /** Path to local folder where chain files are stored */
        string folder_path;

        /** Hash net */
        const HashNet net;
    }

    this(string folder_path, const HashNet net)
    {
        this.folder_path = folder_path;
        this.net = net;

        if (!exists(this.folder_path))
        {
            mkdirRecurse(this.folder_path);
        }
    }

    /** Writes given block to file
     *      @param block - block to write
     */
    void write(const(Block) block)
    {
        auto filename = makePath(block.getHash);
        log.trace("Added recorder chain file '%s'", filename);
        fwrite(filename, block.toHiBON);
    }

    /** Reads file with given fingerprint and creates block from read data
     *      @param fingerprint - fingerprint of block to read
     *      \return chain block, or null if such block file doesn't exist
     */
    Block read(Buffer fingerprint)
    {
        try
        {
            auto doc = fread(makePath(fingerprint));
            // TODO: bad decision, redesign to have automatic set hash from only doc
            return new Block(doc, net);
        }
        catch (Exception e)
        {
            return null;
        }
    }

    /** Finds block that satisfies given predicate 
     *      @param predicate - predicate for block
     *      \return block if search was successfull, null - if such block doesn't exist
     */
    Block find(bool delegate(Block) @safe predicate)
    {
        auto hashes = getHashes;
        foreach (hash; hashes)
        {
            auto fingerprint = decode(hash);
            auto block = read(fingerprint);
            if (predicate(block))
            {
                return block;
            }
        }
        return null;
    }

    /** Collects all block filenames in chain folder 
     *      \return array of block filenames in this folder
     */
    string[] getHashes() @trusted
    {
        enum BLOCK_FILENAME_LEN = StdHashNet.HASH_SIZE * 2;

        return folder_path.dirEntries(SpanMode.shallow)
            .filter!(f => f.isFile())
            .map!(f => baseName(f))
            .filter!(f => f.extension == getExtension.withDot)
            .filter!(f => f.stripExtension.length == BLOCK_FILENAME_LEN)
            .map!(f => f.stripExtension)
            .array;
    }

    private
    {
        static FileExtension getExtension()
        {
            import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;

            static if (is(Block == RecorderChainBlock))
            {
                return FileExtension.recchainblock;
            }
            assert(false, "Unknown block type instantiated for HashChainFileStorage");
        }

        /** Creates path to block with given fingerprint
         *      @param fingerprint - fingerprint of block to make path
         *      \return path to block with given fingerprint
         */
        string makePath(Buffer fingerprint)
        {
            return buildPath(
                folder_path,
                fingerprint.toHexString.setExtension(getExtension));
        }
    }
}
