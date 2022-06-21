module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourBase;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;
import std.string : strip;
import std.format;
import tagion.hibon.HiBONRecord : RecordType, GetLabel;
import std.traits : Fields;
import std.meta;
import std.uni : toLower;
import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourBase : UniqueBehaviourProperties;

enum feature_regex = regex([
        `feature(?:\s+|\:)`, /// Feature
        `scenario(?:\s+|\:)`, /// Scenario
        r"\s*\*(\w+)\*", /// Action
        r"\s*`(\w+)`", /// Name
        r"`((?:\w+\.?)+)`", /// Module
    ], "i");

enum Token {
    NONE,
    FEATURE,
    SCENARIO,
    ACTION,
    NAME,
    MODULE,
}

enum State {
    Start,
    Feature,
    Scenario,
    Action,
    And_Action,
}

@trusted
FeatureGroup parser(R)(R range) if (isInputRange!R && isSomeString!(ElementType!R)) {
    import std.stdio;
    import std.array;
    import std.stdio : write, writeln, writef, writefln;
    import std.algorithm.searching;
    import std.string;
    import std.range : enumerate;

    FeatureGroup result;
    ScenarioGroup scenario_group;

    Info!Feature info_feature;
    Info!Scenario info_scenario;
    writeln(typeid(scenario_group.given));

    State state;
    writeln("STARTTTTTTT--------------------------------------------------------------------------------------------------------------");
    int current_action_index = -1;
    foreach (line_no, line; range.enumerate(1)) {
        writeln("______________________________________");
        auto match = range.front.matchFirst(feature_regex);
        writeln("match: ", match);
        writefln("%s:%d ", line, line_no);
        const Token token = cast(Token)(match.whichPattern);
        writeln("Token: ", token);
        with (Token) {
        TokenSwitch:
            final switch (token) {
            case NONE:
                immutable comment = match.post.strip.idup;
                writeln("Hi from NONE!!!");
            StateSwitch:
                final switch (state) {
                case State.Feature:
                    writeln("1");
                    info_feature.property.comments ~= comment;
                    break;
                case State.Scenario:
                    writeln("2");
                    info_scenario.property.comments ~= comment;
                    break;
                case State.Action:
                case State.And_Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "info")) {
                            if (current_action_index is index) {
                                if (state == State.And_Action) {
                                    scenario_group.tupleof[index].ands[$ - 1].property.comments ~= comment;
                                    break StateSwitch;
                                }
                                scenario_group.tupleof[index].info.property.comments ~= comment;
                            }
                        }
                    }
                    break;
                case State.Start:
                    check(0, format("Missing feature declaration %s:%d", line, line_no));
                }
                break;
            case FEATURE:
                current_action_index = -1;
                check(state is State.Start, format("Feature has already been declared in line %d", line));
                writeln("Hi from Feature!!! ", line);
                info_feature.property.description = match.post.idup;
                state = State.Feature;
                break;
            case NAME:
            case MODULE:
                check((token is MODULE) || (state !is State.Feature),
                        format("Illegal (namespace) name %s for %s", match[1], match.pre));
                // check(state is State.Feature, format("Module name can only be declare after the Feature declaration :%d", line)); HERE!!!
                final switch (state) {
                case State.Feature:
                    info_feature.name = match[1].idup;
                    break TokenSwitch;
                case State.Scenario:
                    info_scenario.name = match[1].idup;
                    break TokenSwitch;
                case State.Action:
                case State.And_Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "info")) {
                            if (current_action_index is index) {
                                if (state is State.And_Action) {
                                    scenario_group.tupleof[index].ands[$ - 1].name = match[1].idup;
                                    break TokenSwitch;
                                }
                                writefln("scenario_group.tupleof[index].info.name = %s", scenario_group.tupleof[index]
                                        .info.name);
                                check(scenario_group.tupleof[index].info.name.length == 0,
                                     format("Action name has already been defined %s", match[0], scenario_group.tupleof[index].info.name));

                                scenario_group.tupleof[index].info.name = match[1].idup;
                                break TokenSwitch;

                            }
                        }
                    }
                    break TokenSwitch;
                case State.Start:
                    writefln("Start %s", match);
                    break TokenSwitch;
                }
                check(0, format("No valid action has %s", match[1]));
                writeln("STATEEEE: ", state);
                break;
            case SCENARIO:
                current_action_index = -1;
                check(state is State.Feature || state is State.Scenario, format("Scenario must be declared after a Feature :%d", line));
                writeln("Hi from SCENARIO!!! ", line);
                info_scenario.property.description = match.post.idup;
                state = State.Scenario;
                break;
            case ACTION:
                writeln("Hi from action!!!!!!!!!!!!");
                state = State.Action;
                scope const action_word = match[1].toLower;
                if (action_word == "and") {
                    check(current_action_index >= 0, "Missing action Given, When or Then before And");
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (isBehaviourGroup!Field) {
                            if (current_action_index == index) {
                                Info!And and;
                                and.property.description = match.post.idup;
                                pragma(msg, "Field ", Fields!ScenarioGroup[index]);
                                pragma(msg, ":::", FieldNameTuple!(typeof(scenario_group.tupleof[index])));
                                scenario_group.tupleof[index].ands ~= and;
                                pragma(msg, ":::", typeof(scenario_group.tupleof[index].ands));
                            }
                        }
                    }
                    state = State.And_Action;
                    break;
                }
                alias BehaviourGroups = staticMap!(BehaviourGroup, UniqueBehaviourProperties);
                pragma(msg, "BehaviourGroups ", BehaviourGroups);
                writefln("Action match %s", match);
                static foreach (index, Field; Fields!ScenarioGroup) {
                    {
                        enum field_index = staticIndexOf!(Field, BehaviourGroups);
                        static if (field_index >= 0) {
                            alias label = GetLabel!(scenario_group.tupleof[index]);
                            pragma(msg, "___action_name ", label.name);
                            enum action_name = label.name;
                            // enum action_name=getUDAs!(UniqueBehaviourProperties[field_index], RecordType)[0].name.toLower;
                            pragma(msg, "action_name ", action_name);

                            writefln("action %s match = %s index=%d", action_name, match[1].toLower, index);

                            if (match[1].toLower == label.name) {
                                writefln("!!!! %s", label.name);
                                current_action_index = index;
                                scenario_group.tupleof[index].info.property.description = match.post.idup;

                                break TokenSwitch;
                            }
                        }
                    }
                }
                break;
            }
        }
    }
    scenario_group.info = info_scenario;
    result.info = info_feature;
    result.scenarios ~= scenario_group;

    writeln("***********************************************************");
    writeln("FeatureGroup: ");
    writeln("              Feature:   ");
    writeln("                       name:        ", result.info.name);
    writeln("                       description: ", result.info.property.description);
    writeln("                       comments:    ", result.info.property.comments);
    writeln("              Scenarios: ");
    writeln("                       name:        ", result.scenarios[0].info.name);
    writeln("                       description: ", result.scenarios[0].info.property.description);
    writeln("                       comments:    ", result.scenarios[0].info.property.comments);
    writeln("               Given name:          ", result.scenarios[0].given.info.name);
    writeln("               Given description:   ", result.scenarios[0].given.info.property.description);
    writeln("               Given comments:   ", result.scenarios[0].given.info.property.comments);
    writeln("               Given ands:   ", result.scenarios[0].given.ands.length);
    foreach (and; result.scenarios[0].given.ands) {
        writeln("                  And name:          ", and.name);
        writeln("                  And description:   ", and.property.description);
        writeln("                  And comments:   ", and.property.comments);
    }
    writeln("               When name:           ", result.scenarios[0].when.info.name);
    writeln("               When description:    ", result.scenarios[0].when.info.property.description);
    writeln("               When comments:   ", result.scenarios[0].when.info.property.comments);
    writeln("               When ands:   ", result.scenarios[0].when.ands.length);
    foreach (and; result.scenarios[0].when.ands) {
        writeln("                  And name:          ", and.name);
        writeln("                  And description:   ", and.property.description);
        writeln("                  And comments:   ", and.property.comments);
    }
    writeln("               Then name:           ", result.scenarios[0].then.info.name);
    writeln("               Then description:    ", result.scenarios[0].then.info.property.description);
    writeln("               Then comments:   ", result.scenarios[0].then.info.property.comments);
    writeln("               Then ands:   ", result.scenarios[0].then.ands.length);
    foreach (and; result.scenarios[0].then.ands) {
        writeln("                  And name:          ", and.name);
        writeln("                  And description:   ", and.property.description);
        writeln("                  And comments:   ", and.property.comments);
    }
    writeln("FINISHHHHHHHH--------------------------------------------------------------------------------------------------------------");
    import tagion.hibon.HiBONJSON : toPretty;

    writefln("pretty %s", result.toPretty);
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

    auto feature = parser(feature_byline);
} //failed! fix

version (unittest) {
    import io = std.stdio;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourIssue : EXT;
    import std.stdio : File;

    //    import std.file : fwrite = write, freadText = readText;

    import std.path;

}
