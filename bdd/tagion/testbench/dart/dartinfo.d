module tagion.testbench.dart.dartinfo;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.communication.HiRPC : HiRPC;



struct DartInfo {
    const string dartfilename;
    const string module_path;
    const SecureNet net;
    const HiRPC hirpc;

    const ulong[] table = [
        0xABB9_13ab_cdef_1234,
        0xABB9_14ab_cdef_1234,
        0xABB9_15ab_cdef_1234
    ];

    const ulong[] deep_table = [
        0xABB9_13ab_10ef_1234,
        0xABB9_13ab_11ef_1234,
        0xABB9_14ab_cdef_1234,
    ];

    const enum FAKE = "$fake#";

}