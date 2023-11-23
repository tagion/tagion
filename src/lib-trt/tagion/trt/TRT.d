// TRT database build on the DART

module tagion.trt.TRT;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic;
import tagion.script.common : TagionBill;
import std.algorithm : filter;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord, label;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.script.standardnames;
import tagion.crypto.Types;

@safe:


struct TRTArchive {
    @label(TRTLabel) Pubkey owner;
    DARTIndex[] idx;


    mixin HiBONRecord;
    version(none)
    mixin HiBONRecord!(q{
        this(Pubkey owner, DARTIndex[] idx) {
            this.owner = owner;
            this.idx = idx;
        }
    });
}


version(none)
unittest {
    auto archive = TRTArchive(Pubkey.init, [DARTIndex.init]);
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
    // get a range of all the bills
    auto archive_bills = dart_recorder[]
        .filter!(a => a.filed.isRecord!TagionBill);


    // create a associative array of the owner to the trtarchive from the ones we read from the dart.

    TRTArchive[Pubkey] to_insert;
    version(none)
    foreach(a; read_recorder) {
        auto trt_archive = TRTArchive(a.filed);
        to_insert[trt_archive.owner] = trt_archive;
    }

    // go through all the bills
    version(none)
    foreach(a_bill; archive_bills) {
        const bill = TagionBill(a_bill.filed);
        auto bill_index = net.dartIndex(a.filed);


        bool constructed;
        auto new_archive = to_insert.require(
            bill.owner, 
            {
                constructed = true; 
                if (a_bill.type == Archive.Type.ADD) {
                    return TRTArchive(bill.owner, [bill_index]);
                }
            }()); 
        if (!constructed) {
            if (a_bill.type == Archive.Type.ADD && !new_archive.idx.canFind(bill_index)) {
                to_insert[bill.owner].idx ~= bill_index;
            }
            else {
                // find the index
                auto to_remove_index = new_archive.idx.countUntil!(d => d == bill_index);
                if (to_remove_index >= 0) {
                    to_insert[bill.owner] = new_archive.idx.remove(to_remove_index);
                }
            }
        }
    }
    
    version(none)
    foreach(new_archive; to_insert.byValue) {
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

    foreach(bill; bills) {
        TRTArchive trt_archive;
        trt_archive.owner = Pubkey(bill.owner);
        trt_archive.idx ~= DARTIndex(net.dartIndex(bill));
        recorder.insert(trt_archive, Archive.Type.ADD);
    }



}












