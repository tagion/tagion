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
    DARTIndex idx;

    mixin HiBONRecord;
}


/// Create a recorder for the trt
/// Params:
///   dart_recorder = The recorder that modified the database
/// Returns: Recorder for the trt
void createUpdateRecorder(immutable(RecordFactory.Recorder) dart_recorder, ref RecordFactory.Recorder trt_recorder, const HashNet net) {
    // get a range of all the bills
    auto archive_bills = dart_recorder[]
        .filter!(a => a.filed.isRecord!TagionBill);
    foreach(a_bill; archive_bills) {
        if (a_bill.type == Archive.Type.ADD) {
            const bill = TagionBill(a_bill.filed);
            TRTArchive trt_archive;
           
            trt_archive.owner = Pubkey(bill.owner);
            trt_archive.idx = DARTIndex(net.dartIndex(a_bill.filed));
            trt_recorder.insert(trt_archive, Archive.Type.ADD);
        } else {
            trt_recorder.remove(a_bill.dart_index);
        }
    }
}


/// Create the recorder for boot
void genesisTRT(TagionBill[] bills, ref RecordFactory.Recorder recorder, const HashNet net) {

    foreach(bill; bills) {
        TRTArchive trt_archive;
        trt_archive.owner = Pubkey(bill.owner);
        trt_archive.idx = DARTIndex(net.dartIndex(bill));
        recorder.insert(trt_archive, Archive.Type.ADD);
    }



}












