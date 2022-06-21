module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourBase;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;
import std.string : strip;
import std.format;

import tagion.behaviour.BehaviourException;

enum feature_regex = regex([
        `Feature(?:\s+|\:)`, /// Feature
        `Scenario(?:\s+|\:)`, /// Scenario
        r"\s*\*(\w+)\*", /// Action
        r"`((?:\w+\.?)+)`", /// Module
        r"\s*`(\w+)`" /// Name
    ]);

enum Token {
    NONE,
    FEATURE,
    SCENARIO,
    ACTION,
    MODULE,
    NAME
}

enum State {
    Start,
    Feature,
    Scenario,
}

FeatureGroup parser(R)(R range) if (isInputRange!R && isSomeString!(ElementType!R)) {
    import std.stdio;
    import std.array;
    import std.stdio: write, writeln, writef, writefln;
    import std.algorithm.searching;
    import std.string;
    FeatureGroup result;
    ScenarioGroup scenario_group;

    Info!Feature info_feature;
    Info!Scenario info_scenario;
    writeln(typeid(scenario_group.given));


    State state;

    writeln("STARTTTTTTT--------------------------------------------------------------------------------------------------------------");
   // string flag = "";
    foreach (line; range) {
        writeln("______________________________________");
        auto match = range.front.matchFirst(feature_regex);
        writeln("match: ", match);
        writeln("line: ", line);
       // writeln("state: ", state);
        //writeln("match.post: ", match.post);

        //io.writefln("match %s : %s", match, line);

        //if (match) {
            // io.writefln("match %s '%s' whichPattern=%d", match, match.post.strip, match.whichPattern);
            const token = cast(Token)(match.whichPattern);
            writeln("Token: ", token);
            with (Token) {
                final switch (token) {
                case NONE:
                    string l = match.post.idup;
                    writeln("Hi from NONE!!!");
                    switch (state) {
                    case State.Feature:
                        writeln("1");
                        info_feature.property.comments ~= strip(l);
                        break;
                    case State.Scenario:
                        writeln("2");
                        info_scenario.property.comments ~= strip(l);
                                               //check(result.scenarios.length > 0, format("Scenario has not been declared yet : %d", line));
                        //result.scenarios[$ - 1].comments ~= match.post.strip;
                        break;
                    default:
                        writeln("3");
                        /// Empty
                    }
                    break;
                case FEATURE:
                    check(state is State.Start, format("Feature has already been declared in line %d", line));
                    writeln("Hi from Feature!!! ", line);
                    if(canFind(line, "Feature: ")) {
                        string description = cast(string)line.replace("## Feature: ", "");
                        info_feature.property.description = description;
                    }
                    else {assert(0);}
                    state = State.Feature;
                    break;
                case MODULE:
                   // check(state is State.Feature, format("Module name can only be declare after the Feature declaration :%d", line)); HERE!!!

                    if(state is State.Feature) info_feature.name = match[1].idup;
                    if(state is State.Scenario) info_scenario.name = match[1].idup;
                    writeln("STATEEEE: ", state);
                    //                    result.info.name=match[1];
                    //io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case SCENARIO:
                    check(state is State.Feature || state is State.Scenario, format("Scenario must be declared after a Feature :%d", line));
                    writeln("Hi from SCENARIO!!! ", line);
                    if(canFind(line, "Scenario: ")) {
                        string description = cast(string)line.replace("### Scenario: ", "");
                        info_scenario.property.description = description;
                    }
                    else {assert(0);}
                    state = State.Scenario;
                    //                    result.scenarios ~= Scenario(match.post.strip);
                   // io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case ACTION:
                    writeln("Hi from action!!!!!!!!!!!!");
                    assert(state == State.Scenario, "State should be scenario");
                    writefln("Action match %s", match);
                    switch (match[1]) {
                        case "Given":
                            writefln("%s match.post = %s %s", match[1], match.post, typeof(match.post).stringof);
                            scenario_group.given.info.property.description = match.post.idup;
                            break;
                        case "When" :
                            writefln("%s match.post = %s %s", match[1], match.post, typeof(match.post).stringof);
                            //writefln("%s match.post = %s ", match[1], match.post);
                            scenario_group.when.info.property.description = match.post.idup;
                            break;
                        case "Then":
                            writefln("%s match.post = %s %s", match[1], match.post, typeof(match.post).stringof);
                            scenario_group.then.info.property.description = match.post.idup;
                            //writefln("%s match.post = %s ", match[1], match.post);
                            break;
                        default:
                            break;
                    }


                   // io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);
                    break;
                case NAME:
                writeln("Hi from name!!!!!!!!!!!!");
                    //io.writefln("%s %s '%s' whichPattern=%d", token, match, match.post.strip, match.whichPattern);

                }
            }
            //             range.popFront;

            // //auto module_match=
            //             return;
       // }
    }
    writeln("***********************************************************");
    writeln("Info_F name: ", info_feature.name);
    writeln("       description: ", info_feature.property.description);
    writeln("       comments: ", info_feature.property.comments);
    writeln("Info_S name: ", info_scenario.name);
    writeln("       description: ", info_scenario.property.description);
    writeln("       comments: ", info_scenario.property.comments);
   // writeln("Given: ", scenario_group.given.description);
   // writeln("When: ", scenario_group.when.description);
   // writeln("Then: ", scenario_group.then.description);
    writeln("FINISHHHHHHHH--------------------------------------------------------------------------------------------------------------");
    return result;
}

unittest { /// Convert ProtoBDD to Feature
    enum name = "ProtoDBBTestComments";
    immutable filename = name.unitfile.setExtension(EXT.Markdown);
    io.writefln("filename=%s", filename);
    //   immutable mdsrc=filename.freadText;

    auto feature_byline = File(filename).byLine;

    alias ByLine = typeof(feature_byline);
    pragma(msg, "isInputRange ", isInputRange!ByLine);
    pragma(msg, "ElementType!ByLine ", ElementType!ByLine);
    pragma(msg, "isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));

    auto feature=parser(feature_byline);
} //failed! fix

version (unittest) {
    import io = std.stdio;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourIssue : EXT;
    import std.stdio : File;

    //    import std.file : fwrite = write, freadText = readText;

    import std.path;

}
