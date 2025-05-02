module tagion.testbench.dart_pseudo_random_archives;

import std.array;
import std.path : buildPath, setExtension;
import std.range : take;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.basic.Version;
import tagion.behaviour.Behaviour;
import tagion.communication.HiRPC : HiRPC;

//import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
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
    const string dartfilename = buildPath(module_path, "dart_pseudo_random_test".setExtension(FileExtension.dart));
    const string dartfilename2 = buildPath(module_path, "dart_pseudo_random_test2".setExtension(FileExtension.dart));

    const net = new DARTFakeNet;
    const hirpc = HiRPC(null);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc, dartfilename2);
    dart_info.states = dart_info.generateStates(1, 10).take(100).array;
    // dart_info.states = dart_info.generateStates(1, 10).take(10).array;

    auto dart_pseudo_random_feature = automation!(dart_pseudo_random)();

    dart_pseudo_random_feature.AddPseudoRandomData(dart_info);
    dart_pseudo_random_feature.RemovePseudoRandomData(dart_info);

    auto dart_pseudo_random_context = dart_pseudo_random_feature.run();

    return 0;

}
