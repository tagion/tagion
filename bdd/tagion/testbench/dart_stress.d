module tagion.testbench.dart_stress;

import tagion.behaviour.Behaviour;
import tagion.hibon.HiBONFile : fwrite;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.dart;
import tagion.testbench.tools.Environment;

import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.communication.HiRPC : HiRPC;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import tagion.basic.Types : FileExtension;
import tagion.testbench.tools.Environment;
import std.file : mkdirRecurse, exists, rmdirRecurse, remove;

import tagion.testbench.dart.dartinfo;

import tagion.basic.Version;

mixin Main!(_main);

int _main(string[] args) {
    const string module_path = env.bdd_log.buildPath(__MODULE__);
    const string dartfilename = buildPath(module_path, "dart_stress_test".setExtension(FileExtension.dart));

    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    // create the dartfile
    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

    const ulong samples = 1000;
    const ulong number_of_records = 10;
    dart_info.fixed_states = DartInfo.generateFixedStates(samples);

    auto dart_ADD_stress_feature = automation!(dart_stress_test)();

    dart_ADD_stress_feature.AddPseudoRandomData(dart_info, samples, number_of_records);

    auto dart_ADD_stress_context = dart_ADD_stress_feature.run();


    return 0;

}
