module tagion.tools.tvmutil.tvmutil;

import core.stdc.string;

import std.getopt;
import std.format;
import std.stdio;
import std.array;
import std.algorithm;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.SecureNet;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.execute;
import tagion.script.common;
import tagion.services.DART;
import tagion.services.collector;
import tagion.services.options;
import tagion.services.messages;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONRecord;
import tagion.wasmer.c;
import tagion.tools.toolsexception;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    version (ENABLE_WASMER) {

        bool version_switch;
        GetoptResult main_args;
        try {

            main_args = getopt(args, std.getopt.config.caseSensitive,
                    std.getopt.config.bundling,
                    "version", "display the version", &version_switch,
                    "v|verbose", "Enable verbose print-out", &__verbose_switch, /*
                "dry", "Dry-run this will not save the wallet", &__dry_switch,
                "C|create", "Create the wallet an set the confidence", &confidence,
                "l|list", "List wallet content", &list,
                "s|sum", "Sum of the wallet", &sum,
                "amount", "Create an payment request in tagion", &amount, //"path", "File path", &path,
                "update", "Update wallet", &update,
                "response", "Response from update (response.hibon)", &response_name,
                "force", "Force input bill", &force,
                "migrate", "Migrate from old account to dart-index account", &migrate,
*/

            

            );
            if (version_switch) {
                revision_text.writeln;
                return 0;
            }
            if (main_args.helpWanted) {
                defaultGetoptPrinter(
                        [
                        "Documentation: https://docs.tagion.org/",
                        "",
                        "Usage:",
                        format("%s [<option>...] file.wasm [file.hibon ...] ", program),
                        "",

                        "<option>:",

                        ].join("\n"),
                        main_args.options);
                return 0;
            }
            string wat_string =
                "(module\n" ~
                "  (type $swap_t (func (param i32 i64) (result i64 i32)))\n" ~
                "  (func $swap (type $swap_t) (param $x i32) (param $y i64) (result i64 i32)\n" ~
                "    (local.get $y)\n" ~
                "    (local.get $x))\n" ~
                "  (export \"swap\" (func $swap)))";

            wasm_byte_vec_t wat;
            wasm_byte_vec_new(&wat, strlen(&wat_string[0]), &wat_string[0]);
            wasm_byte_vec_t wasm_bytes;
            wat2wasm(&wat, &wasm_bytes);
            wasm_byte_vec_delete(&wat);

            printf("Creating the config and the features...\n");
            wasm_config_t* config = wasm_config_new();
            wasmer_features_t* features = wasmer_features_new();
            wasmer_features_multi_value(features, true); // enable multi-value!
            wasm_config_set_features(config, features);

            printf("Creating the store...\n");
            wasm_engine_t* engine = wasm_engine_new_with_config(config);
            wasm_store_t* store = wasm_store_new(engine);

            printf("Compiling module...\n");
            wasm_module_t* _module = wasm_module_new(store, &wasm_bytes);

            if (!_module) {
                printf("> Error compiling module!\n");

                return 1;
            }

            wasm_byte_vec_delete(&wasm_bytes);

            printf("Instantiating module...\n");
            wasm_extern_vec_t imports;
            wasm_trap_t* trap = null;
            wasm_instance_t* instance = wasm_instance_new(store, _module, &imports, &trap);

            if (!instance) {
                printf("> Error instantiating module!\n");

                return 1;
            }

            printf("Retrieving exports...\n");
            wasm_extern_vec_t exports;
            wasm_instance_exports(instance, &exports);

            if (exports.size == 0) {
                printf("> Error accessing exports!\n");

                return 1;
            }

            wasm_func_t* swap = wasm_extern_as_func(exports.data[0]);

            wasm_val_t[2] arguments = [wasm_val_t(1), wasm_val_t(long(2))];

            wasm_val_t[2] results = [wasm_init_val, wasm_init_val];
            wasm_val_vec_t arguments_as_array = wasm_val_vec_t(arguments);
            wasm_val_vec_t results_as_array = wasm_val_vec_t(results);

            writefln("Executing `swap(%d, %d)`...", arguments[0].of.i32, arguments[1].of.i64);
            trap = wasm_func_call(swap, &arguments_as_array, &results_as_array);

            if (trap !is null) {
                printf("> Failed to call `swap`.\n");

                return 1;
            }

            writefln("Got `(%d, %d)`!", results[0].of.i64, results[1].of.i32);
            if (results[0].of.i64 != 2 || results[1].of.i32 != 1) {
                printf("> Multi-value failed.\n");

                return 1;
            }

            wasm_extern_vec_delete(&exports);
            wasm_module_delete(_module);
            wasm_instance_delete(instance);
            wasm_store_delete(store);
            wasm_engine_delete(engine);

        }
        catch (GetOptException e) {
            error(e.msg);
            return 1;
        }
        catch (Exception e) {
            error(e);
            return 1;
        }
        return 0;
    }
    else {
        bool version_switch;
        string dart_filename;
        string output_filename;
        GetoptResult main_args;
        try {

            main_args = getopt(args, std.getopt.config.caseSensitive,
                    std.getopt.config.bundling,
                    "version", "display the version", &version_switch,
                    "v|verbose", "Enable verbose print-out", &__verbose_switch,
                    "d|dart", "Dart file to execute the script against", &dart_filename,
                    "o|output", "The file to output the resulting recorder to", &output_filename,
            );

            if (version_switch) {
                revision_text.writeln;
                return 0;
            }
            if (main_args.helpWanted) {
                defaultGetoptPrinter(
                        [
                        "Documentation: https://docs.tagion.org/",
                        "",
                        "Usage:",
                        format("%s [<option>...] contract.hibon [file.hibon ...] ", program),
                        "",

                        "<option>:",

                        ].join("\n"),
                        main_args.options);
                return 0;
            }

            TaskNames tn;
            check(!dart_filename.empty, "Need a dart file to execute the script against");
            register(tn.tvm, thisTid);
            auto shared_net = cast(shared)(new StdSecureNet());
            immutable dart_opts = DARTOptions(dart_filename: dart_filename);
            auto dart_handle = spawn!DARTService(tn.dart, dart_opts, tn, shared_net, false);
            auto collector_handle = _spawn!CollectorService(tn.collector, tn);
            
            string[] contract_filenames;
            foreach(arg; args) {
                if(arg.endsWith(FileExtension.hibon)) {
                    contract_filenames ~= arg;
                }
            }

            File[] contract_files;
            foreach(filename; contract_filenames) {
                contract_files ~= File(filename, "r");
            }
            if(contract_filenames.empty) {
                contract_files ~= stdin();
            }

            immutable(SignedContract)*[] s_contracts;
            foreach(file; contract_files) {
                auto hibonrange = HiBONRange(file);
                foreach(doc; hibonrange) {
                    if(doc.isRecord!SignedContract) {
                        s_contracts ~= new immutable(SignedContract)(doc);
                    }
                    // read hirpcs with signed contracts, collected contracts as well...
                }
            }

            ContractExecution engine;
            foreach(contract; s_contracts) {
                collector_handle.send(inputContract(), contract);
            }
        }
        catch(Exception e) {
            error(e);
            return 1;
        }
        return 0;
    }
}
