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

@safe:

struct TRTArchive {
    @label(TRTLabel) Pubkey owner;
    DARTIndex[] idx;

    mixin HiBONRecord!(q{
        this(Pubkey owner, DARTIndex[] idx) {
            this.owner = owner;
            this.idx = idx;
        }
    });
}

/// Create a recorder for the trt
/// Params:
///   dart_recorder = The recorder that modified the database
/// Returns: Recorder for the trt
void createUpdateRecorder(
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
            archive.idx ~= DARTIndex(bill_index);
        }
        else if (a_bill.type == Archive.Type.REMOVE) {
            auto to_remove_index = archive.idx.countUntil!(idx => idx == bill_index);
            if (to_remove_index >= 0) {
                archive.idx.remove(to_remove_index);
            }
            else {
                log.error("Index to remove not exists in DART: %s", bill_index.toHexString);
            }
        }

        to_insert[bill.owner] = archive;
    }

    foreach (new_archive; to_insert.byValue) {
        if (new_archive.idx.empty) {
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

        archive.idx ~= DARTIndex(net.dartIndex(bill));
        to_insert[bill.owner] = archive;
    }

    foreach (archive; to_insert.byValue) {
        recorder.insert(archive, Archive.Type.ADD);
    }
}

version (none) unittest {
    import tagion.crypto.SecureNet;
    import std.format;
    import tagion.hibon.HiBONJSON;
    import tagion.dart.DARTFakeNet;
    import std.digest : toHexString;
    import std.stdio : writeln, writefln;
    import tagion.wallet.SecureWallet;
    import tagion.script.TagionCurrency;
    import std.algorithm : map, find;
    import std.algorithm.iteration : reduce, map;

    writeln("**********************************************");

    auto net = new DARTFakeNet("very secret");

    alias StdSecureWallet = SecureWallet!StdSecureNet;

    StdSecureWallet w;
    w = StdSecureWallet(
        iota(0, 5).map!(n => format("question%d", n)).array,
        iota(0, 5)
            .map!(n => format("answer%d", n)).array, 4, "0000",
    );

    TagionBill[] genesis_bills;
    foreach (i; 0 .. 2) {
        auto b = w.requestBill(1000.TGN);
        w.addBill(b);

        genesis_bills ~= b;
    }

    auto factory = RecordFactory(net);
    auto genesis_recorder = factory.recorder;
    genesis_recorder.insert(genesis_bills, Archive.Type.ADD);

    // Test simple genesisTRT
    {
        auto result_recorder = factory.recorder;
        genesisTRT(genesis_bills, result_recorder, net);

        writeln("Test simple genesisTRT recorder ", result_recorder.toPretty);

        assert(result_recorder.length == genesis_bills.length);

        foreach (a; result_recorder) {
            auto trt_archive = TRTArchive(a.filed);
            auto find_result = genesis_bills.find!(b => b.owner == trt_archive.owner);

            assert(!find_result.empty);
            assert(trt_archive.idx.length == 1);
            assert(net.dartIndex(find_result.front) == trt_archive.idx.front);
        }
    }

    // Test duplicationg gegnesisTRT bills
    {
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
                .idx.length).sum;

        assert(index_count == bills.length, "Some indices are missed in genesisTRT");

        auto bill_idx = bills.map!(b => net.dartIndex(b));
        foreach (archive; result_recorder) {
            auto trt_archive = TRTArchive(archive.filed);

            foreach (idx; trt_archive.idx) {
                assert(canFind(bill_idx, idx));
            }
        }

    }

    // Test empty recorder input
    {
    }

    // Test recorder without previous read
    {
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

    writeln("**********************************************");
}
