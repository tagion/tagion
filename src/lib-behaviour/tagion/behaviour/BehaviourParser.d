module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourBase;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;

Feature parser(R)(R range) if(isInputRange!R && isSomeString!(ElementType!R)) {
    Feature result;
    void feature() {
         while (!range.empty) {
             enum featute_regex=regex(`feature(?:\s+|:)(*$)`);
             auto match = range.front.matchFirst(featute_regex);
             if (match) {
                 io.writefln("match %s", match);
                 return;
             }
//                 range.front.featute_regex
             range.popFront;
         }
    }
    feature;
    return result;
}

unittest { /// Convert ProtoBDD to Feature
    enum name="ProtoBDD";
    immutable filename=name.unitfile.setExtension(EXT.Markdown);
    io.writefln("filename=%s", filename);
    //   immutable mdsrc=filename.freadText;

    auto feature_byline=File(filename).byLine;

    alias ByLine=typeof(feature_byline);
    pragma(msg, "isInputRange ", isInputRange!ByLine);
    pragma(msg, "ElementType!ByLine ", ElementType!ByLine);
    pragma(msg, "isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));

    auto feature=parser(feature_byline);
}

version(unittest) {
    import io=std.stdio;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourIssue : EXT;
    import std.stdio : File;
//    import std.file : fwrite = write, freadText = readText;

    import std.path;

}
