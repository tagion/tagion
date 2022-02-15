module tagion.services.RecorderService;

import std.concurrency;
import std.stdio : writeln;
import std.file : exists, mkdirRecurse, write, read;

import tagion.basic.Basic : Control;
import tagion.logger.Logger;

import tagion.services.Options : Options;
import tagion.basic.TagionExceptions : fatal;

import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.dart.Recorder;
import tagion.basic.Basic : Buffer;
import tagion.hibon.HiBONRecord : Label, GetLabel;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.HiBON;
import std.typecons;
import std.path : buildPath, baseName;
import std.algorithm;
import tagion.utils.Miscellaneous : toHexString, decode;
import std.array;
import std.stdio : File;

struct EpochBlockFactory {
    const StdHashNet net;

    @disable this();

    this(immutable(StdHashNet) net) {
        this.net=net;
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
        enum chainLabel=GetLabel!(_chain).name;
        enum recorderLabel=GetLabel!(recorder).name;
        enum bullseyeLabel=GetLabel!(bullseye).name;
        mixin JSONString;

        private this(const(Document) doc, const(StdHashNet) net) immutable{
                auto d = doc[recorderLabel].get!Document;
                auto c = doc[chainLabel].get!Buffer;
                auto b = doc[bullseyeLabel].get!Buffer;

                auto factory = RecordFactory(net);
                auto rec = factory.recorder(d);
                immutable(RecordFactory.Recorder) recor = cast(immutable(RecordFactory.Recorder))rec;

                this.recorder = recor;
                this._chain = c;
                this.bullseye = b;
                this._fingerprint = net.hashOf(Document(toHiBON));
        }
        private this(immutable(RecordFactory.Recorder) recorder, immutable Buffer chain, immutable Buffer bullseye,  const(StdHashNet) net) immutable{
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
                auto h=new HiBON;
                h[chainLabel] = chain;
                if (recorder) {
                    h[recorderLabel] = recorder.toDoc;
                }
                if(bullseye){
                    h[bullseyeLabel] = bullseye;
                }
                return h;
        }
        final const(Document) toDoc() const{
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
        final const(Buffer) chain() const pure nothrow{
                if(_chain) return _chain;
                return null;
        }
    }
}

interface EpochBlockFileDataBaseInterface{
    immutable(EpochBlockFactory.EpochBlock) addBlock(immutable(EpochBlockFactory.EpochBlock) block);
    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock();
    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock();
    Buffer[] getFullChainBullseye();
}

alias info_blocks = Tuple!(EpochBlockFactory.EpochBlock, "first", EpochBlockFactory.EpochBlock, "last", ulong, "amount");
enum FileName_Len = 64;

class EpochBlockFileDataBase : EpochBlockFileDataBaseInterface{

    private EpochBlockFactory.EpochBlock first_block;
    private EpochBlockFactory.EpochBlock last_block;
    private ulong _amount;
    private immutable(string) file_for_blocks;

    this(string file_for_blocks){
        this.file_for_blocks = file_for_blocks;
        
        import std.file : write;
        if (!exists(this.file_for_blocks))
            mkdirRecurse(this.file_for_blocks);

        if(getFiles.length) {
            auto info = findFirstLastAmountBlock;
            this.first_block = info.first;
            this.last_block = info.last;
            this._amount = info.amount;
        }
    }


    string makePath(Buffer name){
        return buildPath(this.file_for_blocks, name.toHexString);
    }

    immutable(EpochBlockFactory.EpochBlock) addBlock(immutable(EpochBlockFactory.EpochBlock) block)
    in{
        assert(block.fingerprint);
        assert(block.bullseye);
        assert(block.recorder);
        if(amount) assert(block.chain);
    }
    do{
        const f_name = makePath(block.fingerprint);
        import tagion.hibon.HiBONRecord : fwrite;
        fwrite(f_name, block.toHiBON);
        if(amount) this.last_block = cast(EpochBlockFactory.EpochBlock) block;
        else{
            this.last_block = cast(EpochBlockFactory.EpochBlock) block;
            this.first_block = cast(EpochBlockFactory.EpochBlock) block;
        }
        _amount++;
        return block;
    }

    immutable(EpochBlockFactory.EpochBlock) deleteLastBlock() {
        if(amount){

            auto info = findFirstLastAmountBlock;
            this.last_block = info[1]; // because rollBack can move pointer

            immutable(EpochBlockFactory.EpochBlock) block = cast(immutable(EpochBlockFactory.EpochBlock)) this.last_block;
            delBlock(this.last_block._fingerprint);
            _amount--;

            if(amount){
                this.last_block = cast(EpochBlockFactory.EpochBlock)getBlockFing(block._chain);
            }
            else{
                this.first_block = null;
                this.last_block = null;
            }
            return block;
        }
        assert(0);
    }

    immutable(EpochBlockFactory.EpochBlock) deleteFirstBlock() {
        if(amount){
            _amount--;
            auto block = delBlock(this.first_block._fingerprint);
            if(amount){
                import std.file;
                Buffer[Buffer] link_table;
                string[] files_name;
                string dir = this.file_for_blocks;

                auto files = dirEntries(dir, SpanMode.shallow).
                       filter!(a => a.isFile()).
                    map!(a => baseName(a)).array();

                foreach (f; files){
                    if(f.length == FileName_Len){
                        files_name~=f;
                    }
                }

                foreach(f; files_name){
                    Buffer fing = decode(f);
                    auto block_ = getBlockFing(fing);
                    link_table[fing] = block_.chain;
                }

                foreach(key; link_table.keys){
                    foreach (value; link_table.values){
                        if (value == block.fingerprint)
                        this.first_block = cast(EpochBlockFactory.EpochBlock)getBlockFing(key);
                    }
                }
            }
            else{
                this.last_block = null;
                this.first_block = null;
            }
            return block;
        }
        else{
            assert(0);
        }
    }

    @nogc ulong amount() const pure nothrow {
        return _amount;
    }

    private info_blocks findFirstLastAmountBlock(){

        Buffer[Buffer] link_table;
        string[] files_name = getFiles;

        foreach(f; files_name){
            Buffer fing = decode(f);
            auto block = getBlockFing(fing);
            link_table[fing] = block.chain;
        }

        info_blocks info;

        bool a = false;
        foreach(key; link_table.keys){
            foreach (value; link_table.values){
                if(key == value) a = true;
            }
            if(!a){ //last blocks
                info[1] = cast(EpochBlockFactory.EpochBlock) getBlockFing(key);
            }
            a = false;
        }

        bool b = true;
        foreach(v; link_table.values){
            foreach (k; link_table.keys){
                if (v == k) a = false;
            }
            if(b){
                foreach (ke; link_table.keys){
                    if(link_table[ke] == v){ //first block
                        info[0] = cast(EpochBlockFactory.EpochBlock) getBlockFing(ke);
                    }
                }
            }
            b = true;
        }
        info[2] = files_name.length;
        return info;

    }

    private immutable(EpochBlockFactory.EpochBlock) delBlock(Buffer fingerprint){
        assert(fingerprint);

        auto block = getBlockFing(fingerprint);
        const f_name = makePath(fingerprint);
        import std.file : remove;
        f_name.remove;
        return block;
    }

    private string[] getFiles() {
        import std.file;
        string[] files_name;

        auto files = dirEntries(this.file_for_blocks, SpanMode.shallow).
                           filter!(a => a.isFile()).
                        map!(a => baseName(a)).array();
        foreach (f; files) {
            if(f.length == FileName_Len){
                files_name~=f;
            }
        }
        return files_name;
    }

    private immutable(EpochBlockFactory.EpochBlock) rollBack() {
        if(buildPath(this.file_for_blocks, this.last_block._chain.toHexString).exists){
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
        auto info = findFirstLastAmountBlock;
        this.last_block = info[1];
        Buffer[] flipped_chain;
        flipped_chain ~=  this.last_block.bullseye;

        while(true){
            if(this.last_block._fingerprint != this.first_block._fingerprint ){
                rollBack();
                flipped_chain~= this.last_block.bullseye;
            }
            else{
                Buffer[] full_chain;
                full_chain = flipped_chain.reverse;
                auto info_ = findFirstLastAmountBlock;
                this.last_block = info[1];
                return full_chain;
            }
        }
    }

    private immutable(EpochBlockFactory.EpochBlock) getBlockFing(Buffer fingerprint){
        const f_name = makePath(fingerprint);
        auto file = File(f_name, "r");
        import tagion.hibon.HiBONRecord : fread;
        auto d = fread(f_name);
        immutable(StdHashNet) _net = new StdHashNet;
        auto factory = EpochBlockFactory(_net);
        auto block = factory(d);
        return block;
    }

    string getFileName(){
        if(this.file_for_blocks) return this.file_for_blocks;
        else assert(0);
    }

    immutable(RecordFactory.Recorder) flipRecorder(immutable(EpochBlockFactory.EpochBlock) block) const{
        const net = new StdHashNet;
        auto factory = RecordFactory(net);
        auto rec = factory.recorder;
        foreach (a; block.recorder){

            if (a.type == Archive.Type.ADD){
                    rec.remove(a.filed);
            }
            else if (a.type == Archive.Type.REMOVE){
                rec.add(a.filed);
            }
            else {
                rec.insert(a);
            }
        }
        immutable(RecordFactory.Recorder) rec_im = cast(immutable(RecordFactory.Recorder))rec;
        return rec_im;
    }
}

unittest {
    // TODO
}

void recorderTask(immutable(Options) opts) {
    try {
        scope (exit) {
            ownerTid.prioritySend(Control.END);
        }

        log.register(opts.recorder.task_name);

        auto records_folder = opts.recorder.folder_path;
        // if (!records_folder.exists) {
        //     records_folder.mkdir;
        // }

        bool stop;
        void control(Control ctrl) @safe {
            with (Control) switch (ctrl) {
                case STOP:
                    stop = true;
                    writeln("%s Stopped ", opts.recorder.task_name);
                    break;
                default:
                    writeln("%s: Unsupported control %s", opts.recorder.task_name, ctrl);
            }
        }

        void receiveRecorder(string test_str, string filename) {
            import tagion.hibon.Document;

            writeln("===== receiveRecorder WRITE <", test_str, "> to ", filename);
            // write(/*records_folder ~ */filename ~ ".recorder", test_str);
            // auto read_output = read(/*records_folder ~ */filename ~ ".recorder");
            // writeln("-----receiveRecorder READ <", read_output, ">");
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(&control, &receiveRecorder);
        }
    }
    catch(Throwable t) {
        fatal(t);
    }
}
