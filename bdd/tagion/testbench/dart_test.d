module tagion.testbench.dart_test;

import std.path : buildPath, setExtension;
import std.traits : moduleName;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.communication.HiRPC : HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.testbench.dart;
import tagion.testbench.dart.dartinfo;
import tagion.testbench.tools.Environment;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    const string module_path = env.bdd_log.buildPath(__MODULE__);
    const string dartfilename = buildPath(module_path, "dart_mapping_two_archives".setExtension(FileExtension.dart));
    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

    auto dart_mapping_two_archives_feature = automation!(dart_mapping_two_archives)();

    dart_mapping_two_archives_feature.AddOneArchive(dart_info);
    dart_mapping_two_archives_feature.AddAnotherArchive(dart_info);
    dart_mapping_two_archives_feature.RemoveArchive(dart_info);

    auto dart_mapping_two_archives_context = dart_mapping_two_archives_feature.run();
    return 0;
}
