module tagion.testbench.dart_insert_remove_stress;

import tagion.behaviour.Behaviour;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.dart;
import tagion.testbench.tools.BDDOptions;
import tagion.testbench.tools.Environment;

import tagion.dart.DARTFakeNet : DARTFakeNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;

import tagion.communication.HiRPC : HiRPC;

import std.path : setExtension, buildPath;
import std.range : take;
import std.array;
import std.stdio : writefln;

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
        const string dartfilename = buildPath(module_path, "dart_insert_remove_stress_test".setExtension(FileExtension
                .dart));

        SecureNet net;

        version (REAL_HASHES) {
            net = new StdSecureNet();
            net.generateKeyPair("very secret");
        }
        else {
            net = new DARTFakeNet("very secret");
        }

        const hirpc = HiRPC(net);

        DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

        auto dart_ADD_REMOVE_stress_feature = automation!(insert_remove_stress)();
        dart_ADD_REMOVE_stress_feature.AddRemoveAndReadTheResult(dart_info, env.getSeed, 100_000, 20, 1000);

        auto dart_ADD_REMOVE_stress_context = dart_ADD_REMOVE_stress_feature.run();

    }

    if (env.stage == Stage.commit) {
        BDDOptions bdd_options;
        setDefaultBDDOptions(bdd_options);
        bdd_options.scenario_name = __MODULE__;

        const string module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
        const string dartfilename = buildPath(module_path, "dart_insert_remove_stress_test".setExtension(FileExtension
                .dart));

        SecureNet net;

        version (REAL_HASHES) {
            net = new StdSecureNet();
            net.generateKeyPair("very secret");
        }
        else {
            net = new DARTFakeNet("very secret");
        }

        const hirpc = HiRPC(net);

        DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

        auto dart_ADD_REMOVE_stress_feature = automation!(insert_remove_stress)();
        dart_ADD_REMOVE_stress_feature.AddRemoveAndReadTheResult(dart_info, env.getSeed, 100, 5, 5);

        auto dart_ADD_REMOVE_stress_context = dart_ADD_REMOVE_stress_feature.run();

    }
    return 0;

}
