// TRT database build on the DART

module tagion.trt.TRT;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic;
import tagion.script.common : TagionBill;
import std.algorithm;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord, label;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.script.standardnames;
import tagion.crypto.Types;
import std.range;
import tagion.logger.Logger : log;
import std.digest : toHexString;

@safe:

struct TRTArchive {
    @label(TRTLabel) Pubkey owner;
    DARTIndex[] indexes;

    mixin HiBONRecord!(q{
        this(Pubkey owner, DARTIndex[] indexes) {
            this.owner = owner;
            this.indexes = indexes;
        }
    });
}

void createTRTUpdateRecorder(
    immutable(RecordFactory.Recorder) dart_recorder,
    const(RecordFactory.Recorder) read_recorder,
    ref RecordFactory.Recorder trt_recorder,
    const HashNet net) {
    // get a range of all the bills
    auto archive_bills = dart_recorder[]
        .filter!(a => a.filed.isRecord!TagionBill);

    // Add to dictionary archives, that already present in TRT DART
    TRTArchive[Pubkey] to_insert;
    foreach (a; read_recorder) {
        auto trt_archive = TRTArchive(a.filed);
        to_insert[trt_archive.owner] = trt_archive;
    }

    foreach (a_bill; archive_bills) {
        const bill = TagionBill(a_bill.filed);
        auto bill_index = net.dartIndex(bill);

        auto archive = to_insert.require(bill.owner, TRTArchive(bill.owner, DARTIndex[].init));

        if (a_bill.type == Archive.Type.ADD) {
            if (!archive.indexes.canFind(bill_index))
                archive.indexes ~= DARTIndex(bill_index);
        }
        else if (a_bill.type == Archive.Type.REMOVE) {
            auto to_remove_index = archive.indexes.countUntil!(idx => idx == bill_index);
            if (to_remove_index >= 0) {
                archive.indexes = archive.indexes.remove(to_remove_index);
            }
            else {
                log.error("Index to remove not exists in DART: %s", bill_index[].toHexString);
            }
        }

        to_insert[bill.owner] = archive;
    }

    foreach (new_archive; to_insert.byValue) {
        if (new_archive.indexes.empty) {
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
    import tagion.dart.DARTFakeNet;
    import std.stdio : writeln, writefln;
    import tagion.wallet.SecureWallet;
    import tagion.script.TagionCurrency;
    import std.algorithm : map;
    import std.algorithm.iteration : reduce, map;

    ulong countTRTRecorderIndexes(const ref RecordFactory.Recorder recorder) {
        return recorder[].map!(a => new TRTArchive(a.filed)
                .indexes.length).sum;
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

        assert(countTRTRecorderIndexes(trt_recorder) == im_dart_recorder.length,
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
        int number_of_dummy_indexes = count_read_bills;

        auto read_recorder = factory.recorder;
        read_recorder.insert(bills[0 .. count_read_bills].map!(b => TRTArchive(b.owner, [
                    net.dartIndex(b), DARTIndex.init
                ])), Archive.Type.ADD);

        createTRTUpdateRecorder(im_dart_recorder, read_recorder, trt_recorder, net);

        assert(countTRTRecorderIndexes(trt_recorder) - number_of_dummy_indexes == im_dart_recorder.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indexes.canFind(a.indexes.front)),
                "Some bills are missing");
        }

        assert(trt_archives.map!(a => a.indexes.canFind(DARTIndex.init))
                .sum == number_of_dummy_indexes, "Read indexes are missing");
    }

    // Test recorder with duplicating read recorder
    {
        auto trt_recorder = factory.recorder;

        auto read_recorder = factory.recorder;
        read_recorder.insert(im_dart_recorder[].map!(a => TagionBill(a.filed))
                .map!(b => TRTArchive(b.owner, [
                        net.dartIndex(b), DARTIndex.init
                    ])), Archive.Type.ADD);

        auto number_of_dummy_indexes = im_dart_recorder.length;

        createTRTUpdateRecorder(im_dart_recorder, read_recorder, trt_recorder, net);

        assert(countTRTRecorderIndexes(trt_recorder) == im_dart_recorder.length + number_of_dummy_indexes,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indexes.canFind(a.indexes.front)),
                "Some bills are missing");
        }

        assert(trt_archives.map!(a => a.indexes.canFind(DARTIndex.init))
                .sum == number_of_dummy_indexes, "Read indexes are missing");
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

        assert(countTRTRecorderIndexes(trt_recorder) == im_dart_recorder_dup.length,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder_dup[]
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives.array) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indexes.canFind(a.indexes.front)),
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

        assert(countTRTRecorderIndexes(trt_recorder) == index_of_remove_bill,
            "Number of entries in recorders differs");

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (b; bills[0 .. index_of_remove_bill]) {
            // Find added indexes
            assert(trt_archives.canFind!(arch => (arch.owner == b.owner && arch.indexes.front == net.dartIndex(
                    b))));

            // Check archives for ADD
            assert(trt_recorder[]
                    .canFind!(arch => (TRTArchive(arch.filed).owner == b.owner
                        && arch.type == Archive.Type.ADD)));
        }

        foreach (b; bills[index_of_remove_bill .. $]) {
            // Find empty lists with removed indexes
            assert(trt_archives.canFind!(arch => (arch.owner == b.owner && arch.indexes.empty)));

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

        assert(countTRTRecorderIndexes(trt_recorder) == im_dart_recorder_dirty.length - fake_docs_count,
            "Number of entries in recorders differs");

        auto dart_archives = im_dart_recorder_dirty[]
            .filter!(a => a.filed.isRecord!TagionBill)
            .map!(a => TagionBill(a.filed))
            .map!(b => TRTArchive(b.owner, [net.dartIndex(b)]));

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (a; dart_archives.array) {
            assert(trt_archives.canFind!(trt_arch => trt_arch.indexes.canFind(a.indexes.front)),
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

        assert(countTRTRecorderIndexes(trt_recorder) == im_dart_recorder.length,
            "Number of entries in recorders differs");

        auto trt_archives = trt_recorder[]
            .map!(b => TRTArchive(b.filed));

        foreach (b; bills) {
            assert(trt_archives.canFind(TRTArchive(b.owner, [net.dartIndex(b)])), "Some bills are missing");
        }
    }
}
