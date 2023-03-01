module tagion.testbench.dart_deep_rim_test;


import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONType : fwrite;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.dart;
import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;
    
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.communication.HiRPC : HiRPC;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;

import tagion.testbench.dart.dartinfo;

import tagion.basic.Version;


mixin Main!(_main);


int _main(string[] args) {
    BDDOptions bdd_options;
    setDefaultBDDOptions(bdd_options);
    bdd_options.scenario_name = __MODULE__;

    const string module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
    const string dartfilename = buildPath(module_path, "dart_deep_rim_test".setExtension(FileExtension.dart));
    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

    auto dart_deep_rim_feature = automation!(dart_two_archives_deep_rim)();

    dart_deep_rim_feature.AddOneArchive(dart_info);
    dart_deep_rim_feature.AddAnotherArchive(dart_info);
    dart_deep_rim_feature.RemoveArchive(dart_info);
    auto dart_deep_rim_context = dart_deep_rim_feature.run();


    // static if (ver.DART_SNAP_BRANCH) {
    //     auto dart_middle_branch_feature = automation!(dart_middle_branch)();
    //     dart_middle_branch_feature.AddOneArchiveAndSnap(dart_info);
    //     auto dart_middle_branch_context = dart_middle_branch_feature.run();
    // } else {
    //     pragma(msg, "fixme(phr): DART snapback problem");
    // }
    auto dart_middle_branch_feature = automation!(dart_middle_branch)();
    dart_middle_branch_feature.AddOneArchiveAndSnap(dart_info);
    auto dart_middle_branch_context = dart_middle_branch_feature.run();


    return 0;
}



