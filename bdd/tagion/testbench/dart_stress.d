module tagion.testbench.dart_stress;


import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.dart;
import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;
    
import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.communication.HiRPC : HiRPC;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import tagion.basic.Types : FileExtension;
import tagion.testbench.tools.Environment;

import tagion.testbench.dart.dartinfo;

import tagion.basic.Version;


mixin Main!(_main);


int _main(string[] args) {

    if (env.stage == Stage.performance) {
        BDDOptions bdd_options;
        setDefaultBDDOptions(bdd_options);
        bdd_options.scenario_name = __MODULE__;

        const string module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
        const string dartfilename = buildPath(module_path, "dart_stress_test".setExtension(FileExtension.dart));

        const SecureNet net = new DARTFakeNet("very_secret");
        const hirpc = HiRPC(net);

        DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);
        dart_info.states = dart_info.generateStates(1, 10).take(100).array;

        auto dart_ADD_stress_feature = automation!(dart_stress_test)();

        dart_ADD_stress_feature.AddPseudoRandomData(dart_info);

        
        auto dart_ADD_stress_context = dart_ADD_stress_feature.run();

    } 

    return 0;


}
