module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourBase;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;
import std.string : strip;

Feature parser(R)(R range) if(isInputRange!R && isSomeString!(ElementType!R)) {
    enum featute_regex=regex(`feature(?:\s+|\:)`);
    enum module_regex=regex(r"`((?:\w+\.?)+)`");
    enum scenario_regex=regex(`scenario(?:\s+|\:)`);
    enum action_regex=regex(`\s*\*(\w+)\*`);
    enum func_regex=regex(r"\s*\*`(\w+)`\*");
    Feature result;
    void feature() {
         while (!range.empty) {
//             enum featute_regex=regex(`feature(?:\s+|\:)`);
             auto match = range.front.matchFirst(featute_regex);
//             io.writefln("!!!) match %s", match);

             if (match) {
                 io.writefln("match %s '%s'", match, match.post.strip);
                 range.popFront;

                 auto module_match=
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
