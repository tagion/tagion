module tagion.testbench.dart_stress;

import std.array;
import std.file : exists, mkdirRecurse, remove, rmdirRecurse;
import std.path : buildPath, setExtension;
import std.range : take;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.basic.Version;
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
    const dartfilename = "dart_stress_test".setExtension(FileExtension.dart);

    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, ".", net, hirpc);

    const ulong samples = 1000;
    const ulong number_of_records = 10;
    dart_info.fixed_states = DartInfo.generateFixedStates(samples);

    auto dart_ADD_stress_feature = automation!(dart_stress_test)();

    dart_ADD_stress_feature.AddPseudoRandomData(dart_info, samples, number_of_records);

    auto dart_ADD_stress_context = dart_ADD_stress_feature.run();


    return 0;

}
