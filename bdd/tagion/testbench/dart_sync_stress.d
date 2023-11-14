module tagion.testbench.dart_sync_stress;

import std.array;
import std.path : buildPath, setExtension;
import std.range : take;
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

    const string module_path = env.bdd_log.buildPath(__MODULE__);
    const string dartfilename = buildPath(module_path, "dart_sync_stress_test".setExtension(FileExtension.dart));
    const string dartfilename2 = buildPath(module_path, "dart_sync_start_slave".setExtension(FileExtension.dart));

    SecureNet net;

    version (REAL_HASHES) {
        net = new StdSecureNet();
        net.generateKeyPair("very secret");
    }
    else {
        net = new DARTFakeNet("very secret");
    }

    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc, dartfilename2);

    auto dart_sync_stress_feature = automation!(dart_sync_stress)();
    dart_sync_stress_feature.AddRemoveAndReadTheResult(dart_info, env.getSeed, 100_000, 1000, 1000);

    auto dart_sync_context = dart_sync_stress_feature.run();

    return 0;

}
