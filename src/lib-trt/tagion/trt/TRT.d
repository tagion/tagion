// TRT database build on the DART

module tagion.trt.TRT;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic;
import tagion.script.common : TagionBill;
import std.algorithm;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord, label, recordType, TYPENAME;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.script.standardnames;
import tagion.crypto.Types;
import std.range;
import tagion.logger.Logger : log;
import std.digest : toHexString;
import tagion.hibon.Document : Document;

@safe:
@recordType(TYPENAME ~ "trt")
struct TRTArchive {
    @label(TRTLabel) Pubkey owner;
    DARTIndex[] indices;

    mixin HiBONRecord!(q{
        this(Pubkey owner, DARTIndex[] indices) {
            this.owner = owner;
            this.indices = indices;
        }
    });
}

@safe:
@recordType(TYPENAME ~ "trt_contract")
struct TRTContractArchive {
    @label(StdNames.contract) DARTIndex contract_hash;
    Document contract;
    @label(StdNames.epoch_number) long epoch;

    mixin HiBONRecord!(q{
        this(DARTIndex contract_hash, Document contract, long epoch) {
            this.contract_hash = contract_hash;
            this.contract = contract;
            this.epoch = epoch;
        }
    });
}

void createTRTUpdateRecorder(
    immutable(RecordFactory.Recorder) dart_recorder,
    const(RecordFactory.Recorder) read_recorder,
    ref RecordFactory.Recorder trt_recorder,
    const HashNet net) {
    // get a range of all the archives with $Y field
    auto archives = dart_recorder[]
        .filter!(a => a.filed.hasMember(StdNames.owner));

    // Add to dictionary archives, that already present in TRT DART
    TRTArchive[Pubkey] to_insert;
    foreach (a; read_recorder) {
        auto trt_archive = TRTArchive(a.filed);
        to_insert[trt_archive.owner] = trt_archive;
    }

    foreach (arch; archives) {
        const doc = Document(arch.filed);
        const owner = doc[StdNames.owner].get!Pubkey;
        auto dart_index = net.dartIndex(doc);

        auto trt_archive = to_insert.require(owner, TRTArchive(owner, DARTIndex[]
                .init));

        if (arch.type == Archive.Type.ADD) {
            if (!trt_archive.indices.canFind(dart_index))
                trt_archive.indices ~= DARTIndex(dart_index);
        }
        else if (arch.type == Archive.Type.REMOVE) {
            auto to_remove_index = trt_archive.indices.countUntil!(idx => idx == dart_index);
            if (to_remove_index >= 0) {
                trt_archive.indices = trt_archive.indices.remove(to_remove_index);
            }
            else {
                log.error("Index to remove not exists in DART: %s", dart_index[].toHexString);
            }
        }

        to_insert[owner] = trt_archive;
    }

    foreach (new_archive; to_insert.byValue) {
        if (new_archive.indices.empty) {
            trt_recorder.insert(new_archive, Archive.Type.REMOVE);
        }
        else {
            trt_recorder.insert(new_archive, Archive.Type.ADD);
        }
    }
}

/// Create the recorder for boot
void genesisTRT(TagionBill[] bills, ref RecordFactory.Recorder recorder, const HashNet net) {
    auto factory = RecordFactory(net);
    auto dart_recorder = factory.recorder(bills, Archive.Type.ADD);
    createTRTUpdateRecorder(factory.uniqueRecorder(dart_recorder), factory.recorder, recorder, net);
}

unittest {
    import tagion.crypto.SecureNet;
    import std.format;
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBON : HiBON;
    import tagion.dart.DARTFakeNet;
    import tagion.wallet.SecureWallet;
    import tagion.script.TagionCurrency;
    import std.algorithm : map;
    import std.algorithm.iteration : reduce, map;
    import std.conv : to;

    ulong countTRTRecorderindices(const ref RecordFactory.Recorder recorder) {
        return recorder[].map!(a => new TRTArchive(a.filed)
                .indices.length).sum;
    }

    auto net = new DARTFakeNet("very secret");

    alias StdSecureWallet = SecureWallet!StdSecureNet;

    StdSecureWallet w;
    w = StdSecureWallet(
        iota(0, 5).map!(n => format("question%d", n)).array,
        iota(0, 5)
            .map!(n => format("answer%d", n)).array, 4, "0000",
    );

    TagionBill[] bills;
    foreach (i; 0 .. 5) {
        auto b = w.requestBill(1000.TGN);
        w.addBill(b);

        bills ~= b;
    }

    auto factory = RecordFactory(net);

    auto fake_hibon = new HiBON();
    fake_hibon["key"] = "some string";
    auto fake_index = net.dartIndex(Document(fake_hibon.serialize));

    auto initial_recorder = factory.recorder;
    initial_recorder.insert(bills, Archive.Type.ADD);
    immutable im_dart_recorder = factory.uniqueRecorder(initial_recorder);

    // Test empty recorder input
    {
        auto trt_recorder = factory.recorder;
        auto empty_recorder = factory.recorder;

        auto empty_dart_recorder = factory.recorder;
        createTRTUpdateRecorder(factory.uniqueRecorder(empty_dart_recorder), empty_recorder, trt_recorder, net);

        assert(trt_recorder.length == 0, "Result recorder should be empty");
    }

    // Test recorder without previous read
    {
        auto trt_recorder = factory.recorder;
        auto empty_recorder = factory.recorder;

        createTRTUpdateRecorder(im_dart_recorder, empty_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind(a), "Some bills are missing");
        }
    }

    // Test recorder with some previous read
    {
        auto trt_recorder = factory.recorder;

        int count_read_bills = 2;
        int number_of_dummy_indices = count_read_bills;

        auto read_recorder = factory.recorder;
        read_recorder.insert(bills[0 .. count_read_bills].map!(b => TRTArchive(b.owner, [
                    net.dartIndex(b), fake_index
                ])), Archive.Type.ADD);
        createTRTUpdateRecorder(im_dart_recorder, read_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) - number_of_dummy_indices == im_dart_recorder.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indices.canFind(a.indices.front)),
                "Some bills are missing");
        }

        assert(trt_archives.map!(a => a.indices.canFind(fake_index))
                .sum == number_of_dummy_indices, "Read indices are missing");
    }

    // Test recorder with duplicating read recorder
    {
        auto trt_recorder = factory.recorder;

        auto read_recorder = factory.recorder;
        read_recorder.insert(im_dart_recorder[].map!(a => TagionBill(a.filed))
                .map!(b => TRTArchive(b.owner, [
                        net.dartIndex(b), fake_index
                    ])), Archive.Type.ADD);

        auto number_of_dummy_indices = im_dart_recorder.length;

        createTRTUpdateRecorder(im_dart_recorder, read_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder.length + number_of_dummy_indices,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indices.canFind(a.indices.front)),
                "Some bills are missing");
        }

        assert(trt_archives.map!(a => a.indices.canFind(fake_index))
                .sum == number_of_dummy_indices, "Read indices are missing");
    }

    // Test recorder with duplicating owner field
    {
        auto trt_recorder = factory.recorder;
        auto empty_recorder = factory.recorder;

        auto num_of_bills = 5;

        TagionBill[] dup_bills;
        foreach (i; 0 .. num_of_bills) {
            auto b = w.requestBill(1000.TGN);
            w.addBill(b);
            b.owner = bills[i].owner;

            dup_bills ~= b;
        }

        auto dart_recorder = factory.recorder;
        dart_recorder.insert(bills, Archive.Type.ADD);
        dart_recorder.insert(dup_bills, Archive.Type.ADD);
        immutable im_dart_recorder_dup = factory.uniqueRecorder(dart_recorder);

        createTRTUpdateRecorder(im_dart_recorder_dup, empty_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder_dup.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder_dup[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives.array) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indices.canFind(a.indices.front)),
                "Some bills are missing");
        }
    }

    // Test recorder with REMOVE archives
    {
        auto trt_recorder = factory.recorder;

        auto read_recorder = factory.recorder;
        read_recorder.insert(bills.map!(b => TRTArchive(b.owner, [
                    net.dartIndex(b)
                ])), Archive.Type.ADD);

        auto index_of_remove_bill = 2;
        auto dart_recorder = factory.recorder;
        dart_recorder.insert(bills[0 .. index_of_remove_bill], Archive.Type.ADD);
        dart_recorder.insert(bills[index_of_remove_bill .. $], Archive.Type.REMOVE);
        immutable im_dart_recorder_rem = factory.uniqueRecorder(dart_recorder);

        createTRTUpdateRecorder(im_dart_recorder_rem, read_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == index_of_remove_bill,
            "Number of entries in recorders differs");

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (b; bills[0 .. index_of_remove_bill]) {
            // Find added indices
            assert(trt_archives.canFind!(arch => (arch.owner == b.owner && arch.indices.front == net.dartIndex(
                    b))));

            // Check archives for ADD
            assert(trt_recorder[]
                    .canFind!(arch => (TRTArchive(arch.filed).owner == b.owner
                        && arch.type == Archive.Type.ADD)));
        }

        foreach (b; bills[index_of_remove_bill .. $]) {
            // Find empty lists with removed indices
            assert(trt_archives.canFind!(arch => (arch.owner == b.owner && arch.indices.empty)));

            // Check archives for REMOVE
            assert(trt_recorder[]
                    .canFind!(arch => (TRTArchive(arch.filed).owner == b.owner
                        && arch.type == Archive.Type.REMOVE)));
        }
    }

    // Test recorder with other docs inside
    {
        auto trt_recorder = factory.recorder;
        auto empty_recorder = factory.recorder;

        int fake_docs_count = 5;
        auto fake_docs = iota(0, fake_docs_count).map!(i => DARTFakeNet.fake_doc(i));

        auto dart_recorder = factory.recorder;
        dart_recorder.insert(bills, Archive.Type.ADD);
        dart_recorder.insert(fake_docs, Archive.Type.ADD);
        immutable im_dart_recorder_dirty = factory.uniqueRecorder(dart_recorder);

        createTRTUpdateRecorder(im_dart_recorder_dirty, empty_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder_dirty.length - fake_docs_count,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder_dirty[]
            .filter!(a => a.filed.isRecord!TagionBill)
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives.array) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indices.canFind(a.indices.front)),
                "Some bills are missing");
        }
    }

    // Test genesisTRT empty recorder input
    {
        auto trt_recorder = factory.recorder;

        genesisTRT(TagionBill[].init, trt_recorder, net);

        assert(trt_recorder.length == 0, "Result recorder should be empty");
    }

    // Test genesisTRT with bills
    {
        auto trt_recorder = factory.recorder;

        genesisTRT(bills, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder.length,
            "Number of entries in recorders differs");

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (b; bills) {
            assert(trt_archives.canFind(TRTArchive(b.owner, [net.dartIndex(b)])), "Some bills are missing");
        }
    }

    // Test recorder with other than TagionBill records with owner field
    {
        import tagion.script.namerecords : NetworkNameCard;
        import tagion.utils.StdTime : sdt_t;

        auto trt_recorder = factory.recorder;
        const empty_recorder = factory.recorder;

        NetworkNameCard[] nnc_array;
        foreach (i; 0 .. 5) {
            NetworkNameCard nnc;
            nnc.name = i.to!string;
            nnc.owner = bills[i].owner;
            nnc_array ~= nnc;
        }

        auto dart_recorder = factory.recorder;
        dart_recorder.insert(bills, Archive.Type.ADD);
        dart_recorder.insert(nnc_array, Archive.Type.ADD);
        immutable im_dart_recorder_mixed = factory.uniqueRecorder(dart_recorder);

        createTRTUpdateRecorder(im_dart_recorder_mixed, empty_recorder, trt_recorder, net);

        assert(countTRTRecorderindices(trt_recorder) == im_dart_recorder_mixed.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => Document(a.filed))
            .map!(doc => TRTArchive(doc[StdNames.owner].get!Pubkey, [
                        net.dartIndex(doc)
                    ]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indices.canFind(a.indices.front)),
                "Some bills are missing");
        }
    }
}
