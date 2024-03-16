module tagion.testbench.dart_deep_rim_test;

import std.path : buildPath, setExtension;
import std.stdio;
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
    const dartfilename = "dart_deep_rim_test".setExtension(FileExtension.dart);
    const dartfilename2 = "start_empty_sync_test".setExtension(FileExtension.dart);
    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, ".", net, hirpc, dartfilename2);

    auto dart_deep_rim_feature = automation!(dart_two_archives_deep_rim)();

    dart_deep_rim_feature.AddOneArchive(dart_info);
    dart_deep_rim_feature.AddAnotherArchive(dart_info);
    dart_deep_rim_feature.RemoveArchive(dart_info);
    auto dart_deep_rim_context = dart_deep_rim_feature.run();

    auto dart_sync_snap_feature = automation!(dart_sync_snap_back)();
    dart_sync_snap_feature.SyncToAnotherDb(dart_info);
    auto dart_sync_snap_context = dart_sync_snap_feature.run();

    auto dart_middle_branch_feature = automation!(dart_middle_branch)();
    dart_middle_branch_feature.AddOneArchiveAndSnap(dart_info);
    auto dart_middle_branch_context = dart_middle_branch_feature.run();

    return 0;
}
