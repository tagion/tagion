module tagion.testbench.dart.dartinfo;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.communication.HiRPC : HiRPC;
import tagion.utils.Random;
import std.range;
import std.stdio;


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

    State[] states;


    void generateStates() {
        states.length = 4;
        auto rnd = RandomT(0x1234UL);

        states[0].rand = rnd.save;
        states[0].number_of_archives = rnd.value(1UL, 5UL);

        void innerGenerate(State prev_states, const uint index = 0) {
            if (index < states.length) {
                states[index].rand = prev_states.rand.drop(states[index].number_of_archives);
                states[index].number_of_archives = rnd.value(1UL, 5UL);
                innerGenerate(states[index], index+1);  
            }
        }
        innerGenerate(states[0]);
    }


}

alias RandomT = Random!ulong;

struct State {
    RandomT rand;
    ulong number_of_archives;
    auto list() {
        return rand.save.take(number_of_archives);
    }
}

