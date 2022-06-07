// module tagion.tools.behaviour;
// import tagion.behaviour.BehaviourParser;
// import std.range.primitives : isInputRange, ElementType;
// import std.traits;
// import std.regex;
// import std.string : strip;
// import std.format;
// import io = std.stdio;
// import tagion.basic.Basic : unitfile;
// import tagion.behaviour.BehaviourIssue : EXT;
// import std.stdio : File;
// import std.path;
// import std.stdio;
// import tagion.behaviour.Behaviour;

// int main(string[] args) {
//     // enum name = "ProtoBDD";
//     // immutable filename = name.unitfile.setExtension(EXT.Markdown);
    
//     // io.writefln("filename=%s", filename);
//     // auto feature_byline = File(filename).byLine;
//     // alias ByLine = typeof(feature_byline);
//     // writeln(feature_byline);
//     // writeln("isInputRange ", isInputRange!ByLine);
//     // //writeln("ElementType!ByLine ", ElementType!ByLine);
//     // writeln("isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));
//     import tagion.hibon.HiBONRecord;
//     import tagion.basic.Basic : unitfile;
//     import core.demangle : mangle;

//     alias Module = tagion.behaviour.BehaviourUnittest;
//     import std.path;

//     enum filename = "TEST_B";

//     writeln(filename);
//     const feature = getFeature!(Module);
//     //filename.fwrite(feature);
//     // const expected = filename.fread!FeatureGroup;
//     // assert(feature.toDoc == expected.toDoc);

//     return 0;
// }
