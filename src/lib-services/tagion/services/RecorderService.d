/// \file RecorderService.d

module tagion.services.RecorderService;

import std.stdio : writeln, File;
import std.file : exists, mkdirRecurse, rmdirRecurse, write, read, remove;
import std.array;
import std.typecons;
import std.path : buildPath, baseName;
import std.algorithm;

import tagion.basic.Types : Control, Buffer;
import tagion.basic.TagionExceptions : fatal;
import tagion.logger.Logger;
import tagion.services.Options : Options, setDefaultOption;

import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.Recorder;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : Label, GetLabel;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.HiBON;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.communication.HiRPC;
import tagion.utils.Fingerprint : Fingerprint;

/** @brief File contains service for handling and saving recorder chain blocks
 */

pragma(msg, "fixme(ib) I don't like the way we cast immutable here. Can we get rid of it?");
static immutable(T) castToImmutable(T)(T object) @trusted
{
    return cast(immutable(T)) object;
}

static T castFromImmutable(T)(immutable(T) object) @trusted
{
    return cast(T) object;
}

@safe struct EpochBlockFactory
{
    const StdHashNet net;

    @disable this();

    this(immutable(StdHashNet) net)
    {
        this.net = net;
    }

    immutable(EpochBlock) opCall(const(Document) doc)
    {
        return new immutable(EpochBlock)(doc, this.net);
    }

    immutable(EpochBlock) opCall(immutable(RecordFactory.Recorder) recorder, immutable(Buffer) chain, immutable(
            Buffer) bullseye)
    {
        return new immutable(EpochBlock)(recorder, chain, bullseye, this.net);
    }

    @safe class EpochBlock
    {
        @Label("") private Buffer _fingerprint;
        Buffer bullseye;
        Buffer _chain;
        RecordFactory.Recorder recorder;
        @disable this();
        enum chainLabel = GetLabel!(_chain).name;
        enum recorderLabel = GetLabel!(recorder).name;
        enum bullseyeLabel = GetLabel!(bullseye).name;
        mixin JSONString;

        private this(const(Document) doc, const(StdHashNet) net) immutable
        {
            auto doc_keys = doc.keys.array;

            Buffer doc_chain = doc[chainLabel].get!Buffer;

            Document doc_recorder;
            if (doc_keys.canFind(recorderLabel))
                doc_recorder = doc[recorderLabel].get!Document;

            Buffer doc_bullseye;
            if (doc_keys.canFind(bullseyeLabel))
                doc_bullseye = doc[bullseyeLabel].get!Buffer;

            auto factory = RecordFactory(net);
            auto rec = castToImmutable(factory.recorder(doc_recorder));

            this.recorder = rec;
            this._chain = doc_chain;
            this.bullseye = doc_bullseye;
            this._fingerprint = net.hashOf(Document(toHiBON));
        }

        private this(immutable(RecordFactory.Recorder) recorder, immutable Buffer chain, immutable Buffer bullseye, const(
                StdHashNet) net) immutable
        {
            this.recorder = recorder;
            this._chain = chain;
            this.bullseye = bullseye;
            this._fingerprint = net.hashOf(Document(toHiBON));
        }

        final const(HiBON) toHiBON() const
        in
        {
            assert(recorder, "recorder can be empty");
        }
        do
        {
            auto hibon = new HiBON;
            hibon[chainLabel] = chain;
            if (recorder)
            {
                hibon[recorderLabel] = recorder.toDoc;
            }
            if (bullseye)
            {
                hibon[bullseyeLabel] = bullseye;
            }
            return hibon;
        }

        final const(Document) toDoc() const
        {
            auto hibon = toHiBON;
            return Document(hibon);
        }

        @nogc
        final const(Buffer) fingerprint() const pure nothrow
        in
        {
            assert(_fingerprint);
        }
        do
        {
            return _fingerprint;
        }

        final const(Buffer) chain() const pure nothrow
        {
            if (_chain)
                return _chain;
            return null;
        }
    }
}

interface EpochBlockFileDataBaseInterface
{
    immutable(EpochBlockFactory.EpochBlock) addBlock(
        immutable(EpochBlockFactory.EpochBlock) block);
    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock();
    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock();
    Buffer[] getFullChainBullseye();
}

alias BlocksInfo = Tuple!(EpochBlockFactory.EpochBlock, "first", EpochBlockFactory.EpochBlock, "last", ulong, "amount");

@safe class EpochBlockFileDataBase : EpochBlockFileDataBaseInterface
{
    private EpochBlockFactory.EpochBlock first_block;
    private EpochBlockFactory.EpochBlock last_block;
    private ulong _amount;
    private immutable(string) folder_path;

    enum EPOCH_BLOCK_FILENAME_LEN = 64;

    this(string folder_path)
    {
        this.folder_path = folder_path;

        import std.file : write;

        if (!exists(this.folder_path))
            mkdirRecurse(this.folder_path);

        if (getFiles.length)
        {
            auto info = getBlocksInfo;
            this.first_block = info.first;
            this.last_block = info.last;
            this._amount = info.amount;
        }
    }

    static string makePath(Buffer name, string folder_path)
    {
        return buildPath(folder_path, name.toHexString);
    }

    private string makePath(Buffer name)
    {
        return makePath(name, this.folder_path);
    }

    immutable(EpochBlockFactory.EpochBlock) addBlock(
        immutable(EpochBlockFactory.EpochBlock) block)
    in
    {
        assert(block.fingerprint);
        assert(block.bullseye);
        assert(block.recorder);
        if (amount)
            assert(block.chain);
    }
    do
    {
        const f_name = makePath(block.fingerprint);
        import tagion.hibon.HiBONRecord : fwrite;

        fwrite(f_name, block.toHiBON);
        if (amount)
            this.last_block = castFromImmutable(block);
        else
        {
            this.last_block = castFromImmutable(block);
            this.first_block = castFromImmutable(block);
        }
        _amount++;
        return block;
    }

    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock()
    {
        if (amount)
        {

            auto info = getBlocksInfo;
            this.last_block = info.last; // because rollBack can move pointer

            auto block = castToImmutable(this.last_block);
            delBlock(this.last_block._fingerprint);
            _amount--;

            if (amount)
            {
                this.last_block = castFromImmutable(readBlockFromFingerprint(block._chain));
            }
            else
            {
                this.first_block = null;
                this.last_block = null;
            }
            return block;
        }
        assert(0);
    }

    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock()
    {
        if (amount)
        {
            _amount--;
            auto block = delBlock(this.first_block._fingerprint);
            if (amount)
            {
                import std.file;

                Buffer[Buffer] link_table;
                auto file_names = getFiles;

                foreach (f; file_names)
                {
                    Buffer fingerprint = decode(f);
                    auto block_ = readBlockFromFingerprint(fingerprint);
                    link_table[fingerprint] = block_.chain;
                }

                foreach (key; link_table.keys)
                {
                    foreach (value; link_table.values)
                    {
                        if (value == block.fingerprint)
                            this.first_block = castFromImmutable(readBlockFromFingerprint(key));
                    }
                }
            }
            else
            {
                this.last_block = null;
                this.first_block = null;
            }
            return block;
        }
        else
        {
            assert(0);
        }
    }

    @nogc ulong amount() const pure nothrow
    {
        return _amount;
    }

    immutable(Buffer) lastBlockFingerprint()
    {
        if (last_block is null)
            return null;
        else
            return last_block.fingerprint.idup;
    }

    static BlocksInfo getBlocksInfo(string folder_path)
    {

        Buffer[Buffer] link_table;
        auto filenames = getFiles(folder_path);

        foreach (f; filenames)
        {
            Buffer fingerprint = decode(f);
            auto block = readBlockFromFingerprint(fingerprint, folder_path);
            link_table[fingerprint] = block.chain;
        }

        BlocksInfo info;
        info.amount = filenames.length;

        // search for the last block
        bool found_next_block = false;
        foreach (fingerprint; link_table.keys)
        { // search such block, that there isn't chain which points to this block
            foreach (chain; link_table.values)
            {
                if (fingerprint == chain)
                    found_next_block = true;
            }
            if (!found_next_block)
            { // save last block
                info.last = castFromImmutable(readBlockFromFingerprint(fingerprint, folder_path));
            }
            found_next_block = false;
        }

        // search for the first block
        bool found_prev_block = false;
        foreach (chain; link_table.values)
        { // search empty chain that doesn't point to some block
            foreach (fingerprint; link_table.keys)
            {
                if (chain == fingerprint)
                    found_prev_block = true;
            }
            if (!found_prev_block)
            {
                foreach (fingerprint; link_table.keys)
                {
                    if (link_table[fingerprint] == chain)
                    { // find block with empty chain
                        info.first = castFromImmutable(readBlockFromFingerprint(fingerprint, folder_path));
                    }
                }
            }
            found_prev_block = false;
        }

        return info;
    }

    private BlocksInfo getBlocksInfo()
    {
        return getBlocksInfo(this.folder_path);
    }

    private immutable(EpochBlockFactory.EpochBlock) delBlock(Buffer fingerprint)
    {
        assert(fingerprint);

        auto block = readBlockFromFingerprint(fingerprint);
        const f_name = makePath(fingerprint);
        import std.file : remove;

        f_name.remove;
        return block;
    }

    static string[] getFiles(string folder_path) @trusted
    {
        import std.file;

        string[] file_names;

        auto files = dirEntries(folder_path, SpanMode.shallow).filter!(a => a.isFile())
            .map!(a => baseName(a))
            .array();
        foreach (f; files)
        {
            if (f.length == EPOCH_BLOCK_FILENAME_LEN)
            {
                file_names ~= f;
            }
        }
        return file_names;
    }

    private string[] getFiles()
    {
        return getFiles(this.folder_path);
    }

    private immutable(EpochBlockFactory.EpochBlock) rollBack()
    {
        if (buildPath(this.folder_path, this.last_block._chain.toHexString).exists)
        {
            const f_name = makePath(this.last_block._chain);
            import tagion.hibon.HiBONRecord : fread;

            auto d = fread(f_name);
            immutable(StdHashNet) net = new StdHashNet;
            auto factory = EpochBlockFactory(net);
            auto block_prev = factory(d);
            assert(block_prev.fingerprint);
            this.last_block = castFromImmutable(block_prev);
            return castToImmutable(this.last_block);
        }
        assert(0);
    }

    Buffer[] getFullChainBullseye()
    {
        auto info = getBlocksInfo;
        this.last_block = info.last;
        Buffer[] flipped_chain;
        flipped_chain ~= this.last_block.bullseye;

        while (true)
        {
            if (this.last_block._fingerprint != this.first_block._fingerprint)
            {
                rollBack();
                flipped_chain ~= this.last_block.bullseye;
            }
            else
            {
                Buffer[] full_chain;
                full_chain = flipped_chain.reverse;
                auto info_ = getBlocksInfo;
                this.last_block = info.last;
                return full_chain;
            }
        }
    }

    static immutable(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(
        Buffer fingerprint, string folder_path)
    {
        const f_name = makePath(fingerprint, folder_path);

        import tagion.hibon.HiBONRecord : fread;

        auto doc = fread(f_name);
        auto factory = EpochBlockFactory(new StdHashNet);
        return factory(doc);
    }

    private immutable(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(Buffer fingerprint)
    {
        return readBlockFromFingerprint(fingerprint, this.folder_path);
    }

    static immutable(RecordFactory.Recorder) getFlippedRecorder(
        immutable(EpochBlockFactory.EpochBlock) block)
    {
        const net = new StdHashNet;
        auto factory = RecordFactory(net);
        auto rec = factory.recorder;
        foreach (archive; block.recorder)
        {
            if (archive.type == Archive.Type.ADD)
            {
                rec.remove(archive.filed);
            }
            else if (archive.type == Archive.Type.REMOVE)
            {
                rec.add(archive.filed);
            }
            else
            {
                rec.insert(archive);
            }
        }
        return castToImmutable(rec);
    }
}

import tagion.basic.Basic : TrustedConcurrency;

mixin TrustedConcurrency;

import tagion.tasks.TaskWrapper;

@safe struct RecorderTask
{
    mixin TaskBasic;

    EpochBlockFileDataBase blocks_db;
    EpochBlockFactory epoch_block_factory = EpochBlockFactory(new StdHashNet);

    @TaskMethod void receiveRecorder(immutable(RecordFactory.Recorder) recorder, Fingerprint db_fingerprint)
    {
        auto last_block_fingerprint = blocks_db.lastBlockFingerprint;
        auto block = epoch_block_factory(recorder, last_block_fingerprint, db_fingerprint
                .buffer);
        blocks_db.addBlock(block);

        version (unittest)
            ownerTid.send(Control.LIVE);
    }

    void opCall(immutable(Options) opts)
    {
        blocks_db = new EpochBlockFileDataBase(opts.recorder.folder_path);

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(&control, &receiveRecorder);
        }
    }
}

immutable(RecordFactory.Recorder) initDummyRecorderAdd(int seed = 1, string suffix = "")
{
    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    HiBON[10] HIB;

    foreach (i; 0 .. HIB.length)
    {
        HIB[i] = new HiBON;
    }

    for (int i = 0; i < HIB.length; i++)
    {
        HIB[i]["test1" ~ suffix] = (seed * i) % 10 * 35 - 46;
        HIB[i]["test2" ~ suffix] = (seed * i) % 10 * 35 - 45;
        HIB[i]["test3" ~ suffix] = (seed * i) % 10 * 35 - 44;
        HIB[i]["test4" ~ suffix] = (seed * i) % 10 * 35 - 43;
        HIB[i]["test5" ~ suffix] = (seed * i) % 10 * 35 - 42;
        HIB[i]["test6" ~ suffix] = (seed * i) % 10 * 35 - 41;
        HIB[i]["test7" ~ suffix] = (seed * i) % 10 * 35 - 40;
        HIB[i]["test8" ~ suffix] = (seed * i) % 10 * 35 - 39;
        HIB[i]["test9" ~ suffix] = (seed * i) % 10 * 35 - 38;
        HIB[i]["test10" ~ suffix] = (seed * i) % 10 * 35 - 37;
    }

    foreach (i; 0 .. HIB.length)
    {
        rec.add(Document(HIB[i]));
    }

    immutable(RecordFactory.Recorder) rec_im = castToImmutable(rec);
    return rec_im;
}

immutable(RecordFactory.Recorder) initDummyRecorderDel()
{

    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    enum hibon_count = 5;

    HiBON[hibon_count] HIB;

    foreach (i; 0 .. HIB.length)
    {
        HIB[i] = new HiBON;
    }

    for (int i = 0; i < HIB.length; i++)
    {
        HIB[i]["test1"] = i * 35 - 46;
        HIB[i]["test2"] = i * 35 - 45;
        HIB[i]["test3"] = i * 35 - 44;
        HIB[i]["test4"] = i * 35 - 43;
        HIB[i]["test5"] = i * 35 - 42;
        HIB[i]["test6"] = i * 35 - 41;
        HIB[i]["test7"] = i * 35 - 40;
        HIB[i]["test8"] = i * 35 - 39;
        HIB[i]["test9"] = i * 35 - 38;
        HIB[i]["test10"] = i * 35 - 37;
    }

    foreach (i; 0 .. hibon_count)
    {
        rec.remove(Document(HIB[i]));
    }

    HiBON toAdd = new HiBON;
    toAdd["add"] = "add";
    rec.add(Document(toAdd));

    return castToImmutable(rec);
}

immutable(RecordFactory.Recorder) initDummyNewRecorder()
{
    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto rec = factory.recorder;

    enum hibon_count = 3;

    HiBON[hibon_count] H;

    foreach (i; 0 .. H.length)
    {
        H[i] = new HiBON;
    }

    for (int i = 0; i < H.length; i++)
    {
        H[i]["Otest1"] = i * 350 - 46;
        H[i]["Otest2"] = i * 350 - 45;
        H[i]["Otest3"] = i * 350 - 44;
        H[i]["Otest4"] = i * 350 - 43;
        H[i]["Otest5"] = i * 350 - 42;
        H[i]["Otest6"] = i * 350 - 41;
        H[i]["Otest7"] = i * 350 - 40;
        H[i]["Otest8"] = i * 350 - 39;
        H[i]["Otest9"] = i * 350 - 38;
        H[i]["Otest10"] = i * 350 - 37;
    }

    foreach (i; 0 .. hibon_count)
    {
        rec.add(Document(H[i]));
    }

    return castToImmutable(rec);
}

void addDummyRecordToDB(ref DART db, immutable(RecordFactory.Recorder) rec, HiRPC hirpc)
{
    const sent = hirpc.dartModify(rec);
    const received = hirpc.receive(sent.toDoc);
    const result = db(received, false);
}

unittest
{
    import std.algorithm : equal;

    Options options;
    setDefaultOption(options);

    alias BlocksDB = EpochBlockFileDataBase;

    // Init dummy database
    string passphrase = "verysecret";
    string folder_path = options.recorder.folder_path;
    string dartfilename = folder_path ~ "DummyDART";

    if (!exists(folder_path))
        mkdirRecurse(folder_path);
    scope (exit)
        rmdirRecurse(folder_path);

    SecureNet net = new StdSecureNet;
    net.generateKeyPair(passphrase);
    auto hirpc = HiRPC(net);
    enum BLOCK_SIZE = 0x80;
    BlockFile.create(dartfilename, DARTFile.stringof, BLOCK_SIZE);

    ushort fromAngle = 0;
    ushort toAngle = 1;
    DART db = new DART(net, dartfilename, fromAngle, toAngle);

    // Create dummy Recorder
    HiBON hibon = new HiBON;
    hibon["not_empty_db?"] = "NO:)";
    immutable(StdHashNet) hashnet = new StdHashNet;
    auto recordFactory = RecordFactory(hashnet);
    auto rec = recordFactory.recorder;
    rec.add(Document(hibon));
    immutable(RecordFactory.Recorder) rec_im = castToImmutable(rec);

    // Spawn recorder task
    auto recorderService = Task!RecorderTask(options.recorder.task_name, options);
    assert(receiveOnly!Control == Control.LIVE);

    /* Add blocks to database */
    // Step 0
    addDummyRecordToDB(db, rec_im, hirpc);
    recorderService.receiveRecorder(rec_im, Fingerprint(db.fingerprint));
    assert(receiveOnly!Control == Control.LIVE);

    assert(equal(db.fingerprint, BlocksDB.getBlocksInfo(folder_path).last.bullseye));

    // Step 1
    auto rec1 = initDummyRecorderAdd(111, "a");
    addDummyRecordToDB(db, rec1, hirpc);
    recorderService.receiveRecorder(rec1, Fingerprint(db.fingerprint));
    assert(receiveOnly!Control == Control.LIVE);

    assert(equal(db.fingerprint, BlocksDB.getBlocksInfo(folder_path).last.bullseye));

    // Step 2
    auto rec2 = initDummyRecorderAdd(23, "aaa");
    addDummyRecordToDB(db, rec2, hirpc);
    recorderService.receiveRecorder(rec2, Fingerprint(db.fingerprint));
    assert(receiveOnly!Control == Control.LIVE);

    assert(equal(db.fingerprint, BlocksDB.getBlocksInfo(folder_path).last.bullseye));

    // Step 3
    auto rec3 = initDummyRecorderAdd(31, "aaaaa");
    addDummyRecordToDB(db, rec3, hirpc);
    recorderService.receiveRecorder(rec3, Fingerprint(db.fingerprint));
    assert(receiveOnly!Control == Control.LIVE);

    assert(equal(db.fingerprint, BlocksDB.getBlocksInfo(folder_path).last.bullseye));

    // Check iterations through blocks
    auto blocks_info = BlocksDB.getBlocksInfo(folder_path);
    auto files = BlocksDB.getFiles(folder_path);
    assert(blocks_info.amount == files.length);

    Buffer fingerprint = blocks_info.last.fingerprint;
    foreach (j; 0 .. blocks_info.amount)
    {
        auto current_block = BlocksDB.readBlockFromFingerprint(fingerprint, folder_path);
        fingerprint = current_block.chain;
    }

    import tagion.utils.Miscellaneous : cutHex;

    /* Test rollback */
    foreach (j; 0 .. BlocksDB.getBlocksInfo(folder_path).amount - 1)
    {
        immutable block = castToImmutable(BlocksDB.getBlocksInfo(folder_path).last);

        addDummyRecordToDB(db, BlocksDB.getFlippedRecorder(block), hirpc);
        BlocksDB.makePath(block.fingerprint, folder_path).remove;

        assert(equal(db.fingerprint, BlocksDB.getBlocksInfo(folder_path).last.bullseye));
    }

    recorderService.control(Control.STOP);
    assert(receiveOnly!Control == Control.END);
}
