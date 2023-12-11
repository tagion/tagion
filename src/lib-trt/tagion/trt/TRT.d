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

/// Create a recorder for the trt
/// Params:
///   dart_recorder = The recorder that modified the database
/// Returns: Recorder for the trt
void createTRTUpdateRecorder(
    immutable(RecordFactory.Recorder) dart_recorder,
    const(RecordFactory.Recorder) read_recorder,
    ref RecordFactory.Recorder trt_recorder,
    const HashNet net) {

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
            archive.indexes ~= DARTIndex(bill_index);
        }
        else if (a_bill.type == Archive.Type.REMOVE) {
            auto to_remove_index = archive.indexes.countUntil!(idx => idx == bill_index);
            if (to_remove_index >= 0) {
                archive.indexes.remove(to_remove_index);
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

    TRTArchive[Pubkey] to_insert;

    foreach (bill; bills) {
        auto archive = to_insert.require(bill.owner, TRTArchive(bill.owner, DARTIndex[].init));

        archive.indexes ~= DARTIndex(net.dartIndex(bill));
        to_insert[bill.owner] = archive;
    }

    foreach (archive; to_insert.byValue) {
        recorder.insert(archive, Archive.Type.ADD);
    }
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

    writeln("**********************************************");

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

    auto empty_recorder = factory.recorder;

    auto initial_recorder = factory.recorder;
    initial_recorder.insert(bills, Archive.Type.ADD);
    immutable im_dart_recorder = factory.uniqueRecorder(initial_recorder);

    // Test empty recorder input
    {
        auto trt_recorder = factory.recorder;

        auto empty_dart_recorder = factory.recorder;
        createTRTUpdateRecorder(factory.uniqueRecorder(empty_dart_recorder), empty_recorder, trt_recorder, net);

        assert(trt_recorder.length == 0, "Result recorder should be empty");
    }

    // Test recorder without previous read
    {
        auto trt_recorder = factory.recorder;

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
    }

    // Test recorder with duplicating read recorder
    {
    }

    // Test recorder with duplicating owner field
    {
    }

    // Test recorder with REMOVE archives
    {
    }

    // Test recorder with other than bills archives
    {
    }

    // Test duplicationg gegnesisTRT bills
    version (none) {
        TagionBill createDuplicatingOwners() {
            auto b = w.requestBill(1000.TGN);
            w.addBill(b);
            b.owner = genesis_bills[0].owner;

            writefln("Dup owner %s", b.owner[].toHexString);
            return b;
        }

        TagionBill[] bills = iota(3).map!(i => createDuplicatingOwners()).array;

        auto result_recorder = factory.recorder;
        genesisTRT(bills, result_recorder, net);

        auto index_count = result_recorder[].map!(a => new TRTArchive(a.filed)
                .indexes.length).sum;
        assert(index_count == bills.length, "Some indices are missed in genesisTRT");

        auto bill_idx = bills.map!(b => net.dartIndex(b));
        foreach (archive; result_recorder) {
            auto trt_archive = TRTArchive(archive.filed);
            foreach (idx; trt_archive.indexes) {
                assert(canFind(bill_idx, idx));
            }
        }
    }

    writeln("**********************************************");
}
