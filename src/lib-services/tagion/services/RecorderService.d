module tagion.services.RecorderService;

import std.stdio : writeln;
import std.stdio : File;
import std.file : exists, mkdirRecurse, write, read;
import std.array;
import std.typecons;
import std.path : buildPath, baseName;
import std.algorithm;
import std.format;

import tagion.basic.Basic : Control, Buffer;
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

struct Fingerprint {
    immutable(Buffer) buffer;

    this(immutable(Buffer) buffer) {
        this.buffer = buffer;
    }
}

struct EpochBlockFactory {
    const StdHashNet net;

    @disable this();

    this(immutable(StdHashNet) net) {
        this.net = net;
    }

    immutable(EpochBlock) opCall(const(Document) doc) {
        return new immutable(EpochBlock)(doc, this.net);
    }

    immutable(EpochBlock) opCall(immutable(RecordFactory.Recorder) recorder, immutable(Buffer) chain, immutable(Buffer) bullseye) {
        return new immutable(EpochBlock)(recorder, chain, bullseye, this.net);
    }

    class EpochBlock {
        @Label("") private Buffer _fingerprint;
        Buffer bullseye;
        Buffer _chain;
        RecordFactory.Recorder recorder;
        @disable this();
        enum chainLabel = GetLabel!(_chain).name;
        enum recorderLabel = GetLabel!(recorder).name;
        enum bullseyeLabel = GetLabel!(bullseye).name;
        mixin JSONString;

        private this(const(Document) doc, const(StdHashNet) net) immutable {
            auto doc_keys = doc.keys.array;

            Buffer doc_chain = doc[chainLabel].get!Buffer;
            
            Document doc_recorder;
            if (doc_keys.canFind(recorderLabel))
                doc_recorder = doc[recorderLabel].get!Document;
            
            Buffer doc_bullseye;
            if (doc_keys.canFind(bullseyeLabel))
                doc_bullseye = doc[bullseyeLabel].get!Buffer;

            auto factory = RecordFactory(net);
            immutable(RecordFactory.Recorder) rec = cast(immutable(RecordFactory.Recorder)) factory.recorder(doc_recorder);

            this.recorder = rec;
            this._chain = doc_chain;
            this.bullseye = doc_bullseye;
            this._fingerprint = net.hashOf(Document(toHiBON));
        }

        private this(immutable(RecordFactory.Recorder) recorder, immutable Buffer chain, immutable Buffer bullseye, const(
                StdHashNet) net) immutable {
            this.recorder = recorder;
            this._chain = chain;
            this.bullseye = bullseye;
            this._fingerprint = net.hashOf(Document(toHiBON));
        }

        final const(HiBON) toHiBON() const
        in {
            assert(recorder, "recorder can be empty");
        }
        do {
            auto hibon = new HiBON;
            hibon[chainLabel] = chain;
            if (recorder) {
                hibon[recorderLabel] = recorder.toDoc;
            }
            if (bullseye) {
                hibon[bullseyeLabel] = bullseye;
            }
            return hibon;
        }

        final const(Document) toDoc() const {
            auto hibon = toHiBON;
            return Document(hibon);
        }

        @nogc
        final const(Buffer) fingerprint() const pure nothrow
        in {
            assert(_fingerprint);
        }
        do {
            return _fingerprint;
        }

        final const(Buffer) chain() const pure nothrow {
            if (_chain)
                return _chain;
            return null;
        }
    }
}

interface EpochBlockFileDataBaseInterface {
    immutable(EpochBlockFactory.EpochBlock) addBlock(immutable(EpochBlockFactory.EpochBlock) block);
    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock();
    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock();
    Buffer[] getFullChainBullseye();
}

alias BlocksInfo = Tuple!(EpochBlockFactory.EpochBlock, "first", EpochBlockFactory.EpochBlock, "last", ulong, "amount");

class EpochBlockFileDataBase : EpochBlockFileDataBaseInterface {
    private EpochBlockFactory.EpochBlock first_block;
    private EpochBlockFactory.EpochBlock last_block;
    private ulong _amount;
    private immutable(string) folder_path;

    enum EPOCH_BLOCK_FILENAME_LEN = 64;

    this(string folder_path) {
        this.folder_path = folder_path;

        import std.file : write;

        if (!exists(this.folder_path))
            mkdirRecurse(this.folder_path);

        if (getFiles.length) {
            auto info = getBlocksInfo;
            this.first_block = info.first;
            this.last_block = info.last;
            this._amount = info.amount;
        }
    }

    static string makePath(Buffer name, string folder_path) {
        return buildPath(folder_path, name.toHexString);
    }

    private string makePath(Buffer name) {
        return makePath(name, this.folder_path);
    }

    immutable(EpochBlockFactory.EpochBlock) addBlock(immutable(EpochBlockFactory.EpochBlock) block)
    in {
        assert(block.fingerprint);
        assert(block.bullseye);
        assert(block.recorder);
        if (amount)
            assert(block.chain);
    }
    do {
        const f_name = makePath(block.fingerprint);
        import tagion.hibon.HiBONRecord : fwrite;

        fwrite(f_name, block.toHiBON);
        if (amount)
            this.last_block = cast(EpochBlockFactory.EpochBlock) block;
        else {
            this.last_block = cast(EpochBlockFactory.EpochBlock) block;
            this.first_block = cast(EpochBlockFactory.EpochBlock) block;
        }
        _amount++;
        return block;
    }

    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock() {
        if (amount) {

            auto info = getBlocksInfo;
            this.last_block = info[1]; // because rollBack can move pointer

            immutable(EpochBlockFactory.EpochBlock) block = cast(immutable(EpochBlockFactory.EpochBlock)) this.last_block;
            delBlock(this.last_block._fingerprint);
            _amount--;

            if (amount) {
                this.last_block = cast(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(block._chain);
            }
            else {
                this.first_block = null;
                this.last_block = null;
            }
            return block;
        }
        assert(0);
    }

    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock() {
        if (amount) {
            _amount--;
            auto block = delBlock(this.first_block._fingerprint);
            if (amount) {
                import std.file;

                Buffer[Buffer] link_table;
                string[] file_names;
                string dir = this.folder_path;

                auto files = dirEntries(dir, SpanMode.shallow).filter!(a => a.isFile())
                    .map!(a => baseName(a))
                    .array();

                foreach (f; files) {
                    if (f.length == EPOCH_BLOCK_FILENAME_LEN) {
                        file_names ~= f;
                    }
                }

                foreach (f; file_names) {
                    Buffer fingerprint = decode(f);
                    auto block_ = readBlockFromFingerprint(fingerprint);
                    link_table[fingerprint] = block_.chain;
                }

                foreach (key; link_table.keys) {
                    foreach (value; link_table.values) {
                        if (value == block.fingerprint)
                            this.first_block = cast(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(key);
                    }
                }
            }
            else {
                this.last_block = null;
                this.first_block = null;
            }
            return block;
        }
        else {
            assert(0);
        }
    }

    @nogc ulong amount() const pure nothrow {
        return _amount;
    }

    immutable(Buffer) lastBlockFingerprint() {
        if (last_block is null)
            return null;
        else
            return last_block.fingerprint.idup;
    }

    static BlocksInfo getBlocksInfo(string folder_path) {

        Buffer[Buffer] link_table;
        auto filenames = getFiles(folder_path);

        foreach (f; filenames) {
            Buffer fingerprint = decode(f);
            auto block = readBlockFromFingerprint(fingerprint, folder_path);
            link_table[fingerprint] = block.chain;
        }

        BlocksInfo info;
        info.amount = filenames.length;

        // search for the last block
        bool found_next_block = false;
        foreach (fingerprint; link_table.keys) { // search such block, that there isn't chain which points to this block 
            foreach (chain; link_table.values) {
                if (fingerprint == chain)
                    found_next_block = true;
            }
            if (!found_next_block) { // save last block
                info.last = cast(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(fingerprint, folder_path);
            }
            found_next_block = false;
        }

        // search for the first block
        bool found_prev_block = false;
        foreach (chain; link_table.values) { // search empty chain that doesn't point to some block
            foreach (fingerprint; link_table.keys) {
                if (chain == fingerprint)
                    found_prev_block = true;
            }
            if (!found_prev_block) {
                foreach (fingerprint; link_table.keys) {
                    if (link_table[fingerprint] == chain) { // find block with empty chain
                        info.first = cast(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(fingerprint, folder_path);
                    }
                }
            }
            found_prev_block = false;
        }

        return info;
    }

    private BlocksInfo getBlocksInfo() {
        return getBlocksInfo(this.folder_path);
    }

    private immutable(EpochBlockFactory.EpochBlock) delBlock(Buffer fingerprint) {
        assert(fingerprint);

        auto block = readBlockFromFingerprint(fingerprint);
        const f_name = makePath(fingerprint);
        import std.file : remove;

        f_name.remove;
        return block;
    }

    static string[] getFiles(string folder_path) {
        import std.file;

        string[] file_names;

        auto files = dirEntries(folder_path, SpanMode.shallow).filter!(a => a.isFile())
            .map!(a => baseName(a))
            .array();
        foreach (f; files) {
            if (f.length == EPOCH_BLOCK_FILENAME_LEN) {
                file_names ~= f;
            }
        }
        return file_names;
    }    

    private string[] getFiles() {
        return getFiles(this.folder_path);
    }

    private immutable(EpochBlockFactory.EpochBlock) rollBack() {
        if (buildPath(this.folder_path, this.last_block._chain.toHexString).exists) {
            const f_name = makePath(this.last_block._chain);
            import tagion.hibon.HiBONRecord : fread;

            auto d = fread(f_name);
            immutable(StdHashNet) net = new StdHashNet;
            auto factory = EpochBlockFactory(net);
            auto block_prev = factory(d);
            assert(block_prev.fingerprint);
            this.last_block = cast(EpochBlockFactory.EpochBlock) block_prev;
            return cast(immutable(EpochBlockFactory.EpochBlock)) this.last_block;
        }
        assert(0);
    }

    Buffer[] getFullChainBullseye() {
        auto info = getBlocksInfo;
        this.last_block = info.last;
        Buffer[] flipped_chain;
        flipped_chain ~= this.last_block.bullseye;

        while (true) {
            if (this.last_block._fingerprint != this.first_block._fingerprint) {
                rollBack();
                flipped_chain ~= this.last_block.bullseye;
            }
            else {
                Buffer[] full_chain;
                full_chain = flipped_chain.reverse;
                auto info_ = getBlocksInfo;
                this.last_block = info.last;
                return full_chain;
            }
        }
    }

    static immutable(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(Buffer fingerprint, string folder_path) {
        const f_name = makePath(fingerprint, folder_path);
        
        import tagion.hibon.HiBONRecord : fread;
        auto doc = fread(f_name);
        auto factory = EpochBlockFactory(new StdHashNet);
        return factory(doc);
    }

    private immutable(EpochBlockFactory.EpochBlock) readBlockFromFingerprint(Buffer fingerprint) {
        return readBlockFromFingerprint(fingerprint, this.folder_path);
    }

    immutable(RecordFactory.Recorder) flipRecorder(immutable(EpochBlockFactory.EpochBlock) block) const {
        const net = new StdHashNet;
        auto factory = RecordFactory(net);
        auto rec = factory.recorder;
        foreach (a; block.recorder) {

            if (a.type == Archive.Type.ADD) {
                rec.remove(a.filed);
            }
            else if (a.type == Archive.Type.REMOVE) {
                rec.add(a.filed);
            }
            else {
                rec.insert(a);
            }
        }
        immutable(RecordFactory.Recorder) rec_im = cast(immutable(RecordFactory.Recorder)) rec;
        return rec_im;
    }
}

import tagion.basic.Basic : TrustedConcurrency;
mixin TrustedConcurrency;

/*@safe*/ void recorderTask(immutable(Options) opts) {
    try {
        scope (exit) {
            prioritySend(ownerTid, Control.END);
        }

        log.register(opts.recorder.task_name);

        const auto records_folder = opts.recorder.folder_path;
        auto blocks_db = new EpochBlockFileDataBase(records_folder);

        immutable(StdHashNet) hashnet = new StdHashNet;
        auto epoch_block_factory = EpochBlockFactory(hashnet);

        bool stop;
        void control(Control ctrl) {
            with (Control) switch (ctrl) {
            case STOP:
                stop = true;
                writeln(format("%s stopped ", opts.recorder.task_name));
                break;
            default:
                writeln(format("%s: Unsupported control %s", opts.recorder.task_name, ctrl));
            }
        }

        void receiveRecorder(immutable(RecordFactory.Recorder) recorder, Fingerprint db_fingerprint) {
            auto last_block_fingerprint = blocks_db.lastBlockFingerprint;
            auto block = epoch_block_factory(recorder, last_block_fingerprint, db_fingerprint.buffer);
            blocks_db.addBlock(block);

            version(unittest)
            ownerTid.send(Control.LIVE);
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(&control, &receiveRecorder);
        }
    }
    catch (Exception e) {
        fatal(e);
    }
}

unittest {
    Options options;
    setDefaultOption(options);

    // Init dummy database
    string passphrase = "verysecret";
    string folder_path = options.recorder.folder_path;
    string dartfilename = folder_path ~ "DummyDART";

    if (!exists(folder_path))
        mkdirRecurse(folder_path);

    SecureNet net = new StdSecureNet;
    net.generateKeyPair(passphrase);
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
    immutable(RecordFactory.Recorder) rec_im = cast(immutable) rec;

    // Spawn recorder task
    auto recorder_service_tid = spawn(&recorderTask, options);
    assert(receiveOnly!Control == Control.LIVE);
    scope(exit) {
        import std.file;
        rmdirRecurse(folder_path);
    }
    
    // Send recorder to service
    enum number_of_test_iterations = 5;
    for (int i = 0; i < number_of_test_iterations; ++i) {
        recorder_service_tid.send(rec_im, Fingerprint(db.fingerprint));
        assert(receiveOnly!Control == Control.LIVE);

        auto blocks_info = EpochBlockFileDataBase.getBlocksInfo(folder_path);

        auto files = EpochBlockFileDataBase.getFiles(folder_path);
        assert(blocks_info.amount == files.length);

        Buffer fingerprint = blocks_info.last.fingerprint;
        for (int j = 0; j < blocks_info.amount; ++j) {
            auto current_block = EpochBlockFileDataBase.readBlockFromFingerprint(fingerprint, folder_path);
            fingerprint = current_block.chain;
        }
    }

    recorder_service_tid.send(Control.STOP);
    assert(receiveOnly!Control == Control.END);
}