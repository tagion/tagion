module tagion.dart.DARTFakeNet;

import std.random;

//import tagion.gossip.InterfaceNet : SecureNet, HashNet;
import tagion.gossip.GossipNet : StdSecureNet;
import tagion.basic.Basic : Buffer, Control;
import tagion.dart.DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : HiBONPrefix;
import tagion.hibon.HiBON : HiBON;
import tagion.dart.DARTBasic;


import std.stdio;
import std.concurrency;


@safe
class DARTFakeNet : StdSecureNet {
    // mixin StdHashNetT;
//    mixin StdSecureNetT;
    //mixin StdGossipNetT;
    enum FAKE=HiBONPrefix.HASH~"#fake";
    this(string passphrase) {
        this();
        // super();
        generateKeyPair(passphrase);
        // import tagion.utils.Miscellaneous;
        // import tagion.Base;
        // writefln("public=%s", (cast(Buffer)pubkey).toHexString);
    }

    this() {
        import tagion.crypto.secp256k1.NativeSecp256k1;
        this._crypt = new NativeSecp256k1;
    }

    ///protected immutable(ubyte)[] fakeKey;
    // this(){
    //     super();
    // }
    //import core.exception : SwitchError;

    override immutable(Buffer) hashOf(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const {
        return calcHash(h1~h2);
    }


    @trusted
    override immutable(Buffer) hashOf(scope const(Document) doc) const {
        import tagion.hibon.HiBONBase : Type;
        if ( (doc.length is 1) && doc.hasElement(FAKE) && (doc[FAKE].type is Type.UINT64)) {
            auto x=doc[FAKE].get!ulong;
            import std.bitmanip: nativeToBigEndian;
            return nativeToBigEndian(x).idup;
        }
        else {
            auto range=doc[];
            if (!range.empty && (range.front.key[0] is HiBONPrefix.HASH)) {
                immutable value_data=range.front.data[range.front.valuePos..$];
                //auto hmac=HMAC(value_data);
                //pragma(msg, "value_data ", typeof(value_data), " ", typeof(calcHash(value_data)));
                return calcHash(value_data);
            }
        }
        return calcHash(doc.data);
    }

    static const(Document) fake_doc(const ulong x) {
        auto hibon=new HiBON;
        hibon[FAKE]=x;
        //import tagion.hibon.HiBONBase : Type;
        //assert(hibon[FAKE].type is Type.UINT64);
        return Document(hibon.serialize);
    }
}

Buffer SetInitialDataSet(DART dart, ubyte ringWidth, int rings, int cores = 4) {
    import std.math: floor, ceil;
    static __gshared bool stop = false;
    static __gshared ulong all_iterations = 0;
    static __gshared ulong iteration = 0;
    static ulong local_iteration = 0;

    alias Sector = DART.SectorRange;
    import std.math: pow;
    import std.algorithm : count;
    auto dart_range = dart.sectors;
    all_iterations = count(dart_range) * pow(ringWidth, (rings-2));
    float angDiff = cast(float)count(dart_range) / cores;
    static void setRings(int ring, int rings, ubyte[] buffer, ubyte ringWidth,
            DARTFile.Recorder rec) {
        if(stop) return;
        auto rnd = Random(unpredictableSeed);
        bool randomChance(int proc) {
            const c = uniform(0, 100, rnd);
            if (c <= proc)
                return true;
            return false;
        }

        void fillRandomHash(ubyte[] buf) {
            for (int x = rings; x < ulong.sizeof; x++) {
                buf[x] = rnd.uniform!ubyte;
            }
        }
        ubyte lowerByte = ring == 2 ? ubyte.min : ubyte.min + 1;
        for (ubyte j = lowerByte; j < ringWidth; j++) {
            fillRandomHash(buffer);
            buffer[ring] = j;
            // auto fake_hibon=new HiBON;
            const bufLong=convertFromBuffer!ulong(buffer);
            //immutable fake_doc_data=DARTFakeNet.foa(bufLong);
            // This is not a real Document but just the data
            const fakeDoc = DARTFakeNet.fake_doc(bufLong);
            try {
                iteration++;
                local_iteration++;
                if (iteration % (all_iterations < 100 ? 1 : all_iterations / 100) == 0) {
                    writef("\r%d%%  ", ((iteration * 100) / all_iterations));
                }
                enum max_archive_in_recorder = 50;
                if (local_iteration%max_archive_in_recorder == 0){
                    ownerTid.send(cast(shared)rec, thisTid);
                    receiveOnly!bool;
                }
                rec.add(fakeDoc);
            }
            catch (Exception e) {
                writeln(e);
            }
            if (ring < rings - 1) {
                // if(randomChance(93))continue;
                setRings(ring + 1, rings, buffer.dup, ringWidth, rec);
            }
        }
    }

    static void setSectors(immutable Sector sector, ubyte rw, int rings, shared DARTFile.Recorder rec) {
        ubyte[ulong.sizeof] buf;
        foreach(j; cast(Sector)sector) {
            buf[0 .. ushort.sizeof] = convert_sector_to_rims(j);
            setRings(2, rings, buf.dup, rw, cast(DARTFile.Recorder) rec);
        }
        if(!stop) ownerTid.send(true, rec);
    }
    for(int i=0; i< cores; i++){
        auto recorder = dart.recorder();
        immutable sector = Sector(
            cast(ushort)(dart_range.from_sector + floor(angDiff*i)),
            cast(ushort)(dart_range.from_sector + floor(angDiff*(i+1)))
        );
        spawn(&setSectors, sector, ringWidth, rings, cast(shared) recorder);
    }

    Buffer last_result;
    auto active_threads = cores;
    do{
        receive(
            (Control control){
                if(control == Control.STOP){
                    stop = true;
                    send(ownerTid, Control.END);
                }
            },
            (bool flag, shared DARTFile.Recorder recorder){
                active_threads--;
                auto non_shared_recorder = cast(DARTFile.Recorder) recorder;
                last_result = dart.modify(non_shared_recorder);
            },
            (shared DARTFile.Recorder recorder, Tid sender){
                auto non_shared_recorder = cast(DARTFile.Recorder) recorder;
                dart.modify(non_shared_recorder);
                non_shared_recorder.clear();
                send(sender, true);
            }
        );
    }while(active_threads>0 && !stop);
    import core.stdc.stdlib: exit;
    if(stop) exit(0);   //TODO: bad solution
    return last_result;
}
