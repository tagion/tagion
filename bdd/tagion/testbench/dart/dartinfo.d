module tagion.testbench.dart.dartinfo;
import std.algorithm;
import std.algorithm.iteration : each;
import std.range;
import std.stdio;
import std.traits;
import tagion.communication.HiRPC : HiRPC;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.utils.Random;

struct DartInfo {
    const string dartfilename;
    const string module_path;
    const SecureNet net;
    const HiRPC hirpc;
    const string dartfilename2;


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

    auto generateStates(const uint from, const uint to) {
       auto rnd = RandomT(0x1234);
       return recurrence!(
            (a, n) =>
            a[n-1].progress(rnd.value(from,to))
        )(SequenceT(rnd.save, from));
    }
    SequenceT[] states;

    static auto generateFixedStates(const ulong samples) {
        auto start = RandomT(0x1234);
        auto rand_range = recurrence!(q{
        a[n-1].drop(1)
        })(start);

        return(rand_range
                .take(samples)
                .map!q{a.take(1)}
                .joiner);        
    }

    ReturnType!generateFixedStates fixed_states;    
    


}

alias RandomT = Random!ulong;
alias SequenceT = Sequence!ulong;


