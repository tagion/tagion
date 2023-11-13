module tagion.testbench.dart_partial_sync;

import std.array;
import std.path : buildPath, setExtension;
import std.range : take;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.communication.HiRPC : HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
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
    const string dartfilename = buildPath(module_path, "dart_sync_start_full".setExtension(FileExtension.dart));
    const string dartfilename2 = buildPath(module_path, "dart_sync_start_partial".setExtension(FileExtension.dart));

    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc, dartfilename2);
    dart_info.states = dart_info.generateStates(0, 10).take(10).array;

    auto dart_sync_feature = automation!(basic_dart_partial_sync)();
    dart_sync_feature.PartialSync(dart_info);
    dart_sync_feature.run();

    return 0;

}
