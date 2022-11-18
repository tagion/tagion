module tagion.testbench.tools.TestMain;

import tagion.basic.Types : FileExtension;
import std.path : baseName, setExtension;
import std.file : exists;
import std.getopt;
import std.stdio;
import std.format;
import std.string : join;
import tagion.tools.revision : revision_text;

import tagion.services.Options;

MainSetup!TestOpt mainSetup(TestOpt)(
        string config_file,
        const MainSetup!(TestOpt).SetDefault setDefault) {
    return MainSetup!TestOpt(config_file, setDefault);
}

struct MainSetup(TestOpt) {
    string default_file; /// Default config file name
    string config_file; /// Current config file name
    TestOpt options;
    alias SetDefault = void function(ref TestOpt test_opt, const Options opt);
    const SetDefault setDefault;
    void load() {
        options.load(config_file);
    }

    void save() {
        options.save(config_file);
    }

    this(string config_file, const SetDefault setDefault) {
        this.config_file = config_file.setExtension(FileExtension.json);
        this.default_file = config_file;
        this.setDefault = setDefault;
    }
}

int testMain(TestOpt)(ref MainSetup!TestOpt setup, string[] args) {

            Options opt;
    /** file for configurations */
    enum tagionconfig = "tagionwave".setExtension(FileExtension.json);
    enum ONE_ARGS_ONLY = 2;

    immutable program = args[0];
    /** flag for print current version of behaviour */
    bool version_switch;
    /** flag for overwrite config file */
    bool overwrite_switch;

    auto main_args = getopt(args, std.getopt.config.caseSensitive,
            "version", "display the version", &version_switch,
            "O", format("Write configure file %s", setup.config_file), &overwrite_switch,
    );
    if (args.length == ONE_ARGS_ONLY) {
        setup.config_file = args[1];
    }
    if (setup.config_file.exists) {
        if (setup.config_file.baseName == tagionconfig) {
            opt.load(setup.config_file);
    setup.setDefault(setup.options, opt);
        }
        else {
            setup.load;
        }
    }
    else {
        opt.setDefaultOption;
    setup.setDefault(setup.options, opt);
    }
writefln("TestMain %s", opt.transaction.service.openssl);
    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (overwrite_switch) {
        if (args.length is ONE_ARGS_ONLY) {
            setup.config_file = args[1];
        }
        if (setup.config_file.baseName == tagionconfig) {
            setup.config_file = setup.default_file;
        }
        setup.save;
        writefln("Configure file written to %s", setup.config_file);
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter([
            revision_text,
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...]", program),
            "",
            "<option>:",
        ].join("\n"), main_args.options);
        return 0;
    }
    return 0;
}
