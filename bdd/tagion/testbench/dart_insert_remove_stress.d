module tagion.testbench.dart_insert_remove_stress;

import std.array;
import std.path : buildPath, setExtension;
import std.range : take;
import std.stdio : writefln;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.basic.Version;
import tagion.behaviour.Behaviour;
import tagion.communication.HiRPC : HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.hibon.HiBONFile : fwrite;
import tagion.testbench.dart;
import tagion.testbench.dart.dartinfo;
import tagion.testbench.tools.Environment;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {

    if (env.stage == Stage.performance) {
        const dartfilename = "dart_insert_remove_stress_test".setExtension(FileExtension.dart);

        SecureNet net;

        version (REAL_HASHES) {
            net = new StdSecureNet();
            net.generateKeyPair("very secret");
        }
        else {
            net = new DARTFakeNet("very secret");
        }

        const hirpc = HiRPC(net);

        DartInfo dart_info = DartInfo(dartfilename, ".", net, hirpc);

        auto dart_ADD_REMOVE_stress_feature = automation!(insert_remove_stress)();
        dart_ADD_REMOVE_stress_feature.AddRemoveAndReadTheResult(dart_info, env.getSeed, 100_000, 20, 1000);

        auto dart_ADD_REMOVE_stress_context = dart_ADD_REMOVE_stress_feature.run();

    }

    if (env.stage == Stage.commit) {
        const dartfilename = "dart_insert_remove_stress_test".setExtension(FileExtension.dart);

        SecureNet net;

        version (REAL_HASHES) {
            net = new StdSecureNet();
            net.generateKeyPair("very secret");
        }
        else {
            net = new DARTFakeNet("very secret");
        }

        const hirpc = HiRPC(net);

        DartInfo dart_info = DartInfo(dartfilename, ".", net, hirpc);

        auto dart_ADD_REMOVE_stress_feature = automation!(insert_remove_stress)();
        dart_ADD_REMOVE_stress_feature.AddRemoveAndReadTheResult(dart_info, env.getSeed, 100, 5, 5);

        auto dart_ADD_REMOVE_stress_context = dart_ADD_REMOVE_stress_feature.run();

    }
    return 0;

}
