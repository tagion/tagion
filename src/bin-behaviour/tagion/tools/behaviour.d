module tagion.tools.behaviour;
// import tagion.behaviour.BehaviourParser;
// import std.getopt;
// import std.stdio;
// import tagion.behaviour.BehaviourBase;

// import std.range.primitives : isInputRange, ElementType;
// import std.traits;
// import std.regex;
// import std.string : strip;
// import std.format;
// //mixin Main!_main;
// import io = std.stdio;
// import tagion.basic.Basic : unitfile;
// import tagion.behaviour.BehaviourIssue : EXT;
// import std.stdio : File;

    //    import std.file : fwrite = write, freadText = readText;

    import std.path;

int _main(string[] args) {
    // enum name = "ProroBDD";
    // immutable filename = name.unitfile.setExtension(EXT.Markdown);
    // io.writefln("filename=%s", filename);
    // //   immutable mdsrc=filename.freadText;

    // auto feature_byline = File(filename).byLine;

    // alias ByLine = typeof(feature_byline);
    // pragma(msg, "isInputRange ", isInputRange!ByLine);
    // pragma(msg, "ElementType!ByLine ", ElementType!ByLine);
    // pragma(msg, "isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));

   // auto feature=parser(feature_byline);




 
    // immutable program = args[0];
    // bool version_switch;
    // auto main_args = getopt(args,
    //     std.getopt.config.caseSensitive,
    //     std.getopt.config.bundling,
    //     "version", "display the version", &version_switch,
    //     "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
    // );

    // if (version_switch) {
    //     // writefln("version %s", REVNO);
    //     // writefln("Git handle %s", HASH);
    //     return 0;
    // }

    // if (main_args.helpWanted) {
    //     defaultGetoptPrinter(
    //             [
    //         // format("%s version %s", program, REVNO),
    //         "Documentation: https://tagion.org/",
    //         "",
    //         "Usage:",
    //         format("%s <command> [<option>...]", program),
    //         "",
    //         "Where:",
    //         "<command>           one of [--read, --rim, --modify, --rpc]",
    //         "",

    //         "<option>:",

    //     ].join("\n"),
    //     main_args.options);
    //     return 0;
    // }


    return 0;
}
