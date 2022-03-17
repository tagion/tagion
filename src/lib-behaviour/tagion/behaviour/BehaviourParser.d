module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourBase;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;
import std.string : strip;
import std.format;

import tagion.behaviour.BehaviourException;

enum feature_regex=regex([
        `Feature(?:\s+|\:)`,  /// Feature
        `Scenario(?:\s+|\:)`, /// Scenario
        r"\s*\*(\w+)\*",      /// Action
        r"\s*`(\w+)`",        /// Name
        r"`((?:\w+\.?)+)`"    /// Module
        ]);

enum Token {
    NONE,
    FEATURE,
    SCENARIO,
    ACTION,
    NAME,
    MODULE
}

enum State {
    Start,
    Feature,
    Scenario,
}

FeatureGroup parser(R)(R range) if(isInputRange!R && isSomeString!(ElementType!R)) {
    FeatureGroup result;
    State state;

    foreach(line; range) {
        auto match = range.front.matchFirst(feature_regex);
        io.writefln("match %s : %s", match, line);

        if (match) {
            // io.writefln("match %s '%s' whichPattern=%d", match, match.post.strip, match.whichPattern);
            const token=cast(Token)(match.whichPattern);
            with(Token) {
                final switch(token) {
                case NONE:
                    io.writeln("None");
                    switch (state) {
                    case State.Feature:
                        result.info.comments~=match.post.strip;
                        break;
                    case State.Scenario:
                        check(result.scenarios.length > 0, fromat("Scenario has not been declared yet : %d", line));
                        result.scenarios[$-1].comments~=match.post.strip;
                        break;
                    default:
                        /// Empty
                    }

                    break;
                case FEATURE:
                    check(state is State.Start, format("Feature has already been declared in line %d", line));
                    state = State.Feature;
                    result.info.description = match.post.strip;
                    io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case MODULE:
                    check(state is State.Feature, format("Module name can only be declare after the Feature declaration :%d", line));
                    result.info.name=match[1];
                    io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case SCENARIO:
                    check(state is State.Feature ||  state is State.Scenario, format("Scenario must be declared after a Feature :%d", line));
                    state = State.Scenario;
                    result.scenarios ~= Scenario(match.post.strip);
                    io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case ACTION:
                    io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case NAME:
                    io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);

                }
            }
//             range.popFront;

// //auto module_match=
//             return;
        }
    }
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
