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
FeatureGroup parser(string filename, out string[] errors) {
    import std.stdio : File;
    auto by_line = File(filename).byLine;
    return parser(by_line, errors, filename);
}

@trusted
FeatureGroup parser(R)(R range, out string[] errors, string localfile=null) if (isInputRange!R && isSomeString!(ElementType!R)) {
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
//    string[] errors;
    foreach (line_no, line; range.enumerate(1)) {
        void check_error(const bool flag, string msg) {
            if (!flag) {
                const text = format("%s:%d\n%s\n%s", localfile, line_no, line, msg);
                errors ~= text; //format("%s:%d\n%s\n", localfile, line_no, line, msg);
            }
        }
        writeln("______________________________________");
        auto match = range.front.matchFirst(feature_regex);
        // writeln("match: ", match);
        // writefln("%s:%d ", localfile, line_no);
        const Token token = cast(Token)(match.whichPattern);
        // writeln("Token: ", token);
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
                    check_error(0, "Missing feature declaration");
                }
                break;
            case FEATURE:
                current_action_index = -1;
//                check(state is State.Start, format("Feature has already been declared in line %d", line_no));
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
                                // writefln("scenario_group.tupleof[index].info.name = %s", scenario_group.tupleof[index]
                                //         .info.name);
                                check_error(scenario_group.tupleof[index].info.name.length == 0,
                                    format("Action name '%s' has already been defined for %s", match[0], scenario_group.tupleof[index].info.name));

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
                //check(state is State.Feature || state is State.Scenario, format("Scenario must be declared after a Feature :%d", line_no));
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
    import tagion.hibon.HiBONJSON : toPretty;

//    writefln("pretty %s", result.toPretty);
//    check(errors.length == 0, errors.join("\n"));
    return result;
}

unittest { /// Convert ProtoDBBTestComments to Feature
    enum bddfile_proto = "ProtoBDDTestComments";
    immutable bdd_filename = bddfile_proto.unitfile.setExtension(EXT.Markdown);
    io.writefln("bdd_filename=%s", bdd_filename);

    auto feature_byline = File(bdd_filename).byLine;

    // alias ByLine = typeof(feature_byline);
    // pragma(msg, "isInputRange ", isInputRange!ByLine);
    // pragma(msg, "ElementType!ByLine ", ElementType!ByLine);
    // pragma(msg, "isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));

    auto feature = parser(feature_byline);
    { // Check ProtoDBBTestComments converted to Feature
    // check feature
    assert(feature.info.name == "tagion.behaviour.unittest.ProtoBDD");
    assert(feature.info.property.description == " Some awesome feature should print some cash out of the blue(descr)");
    assert(feature.info.property.comments == ["Some addtion notes", "my comment1", "my comment2 a lot spaces", ""]);
    // check scenario
    assert(feature.scenarios[0].info.name == "Some_awesome_money_printer");
    assert(feature.scenarios[0].info.property.description == " Some awesome money printer");
    assert(feature.scenarios[0].info.property.comments == ["\u200B   comments", ""]); // Why?
    // check given
    assert(feature.scenarios[0].given.info.name == "is_valid");
    assert(feature.scenarios[0].given.info.property.description == " the card is valid");
    assert(feature.scenarios[0].given.info.property.comments == ["some comments scenario", ""]);
    assert(feature.scenarios[0].given.ands.length == 2);
    assert(feature.scenarios[0].given.ands[0].name == "in_credit");
    assert(feature.scenarios[0].given.ands[0].property.description == " the account is in credit");
    assert(feature.scenarios[0].given.ands[0].property.comments == ["some comments Given And", ""]);
    assert(feature.scenarios[0].given.ands[1].name == "contains_cash");
    assert(feature.scenarios[0].given.ands[1].property.description == " the dispenser contains cash");
    assert(feature.scenarios[0].given.ands[1].property.comments == [""]);
    // check when
    assert(feature.scenarios[0].when.info.name == "request_cash");
    assert(feature.scenarios[0].when.info.property.description == " the Customer request cash");
    assert(feature.scenarios[0].when.info.property.comments == ["some comments for When"]);
    assert(feature.scenarios[0].when.ands.length == 0);
    // check then
    assert(feature.scenarios[0].then.info.name == "is_debited");
    assert(feature.scenarios[0].then.info.property.description == " the account is debited");
    assert(feature.scenarios[0].then.info.property.comments == ["some comments for Then", ""]);
    assert(feature.scenarios[0].then.ands.length == 1);
    assert(feature.scenarios[0].then.ands[0].name == "is_dispensed");
    assert(feature.scenarios[0].then.ands[0].property.description == " the cash is dispensed");
    assert(feature.scenarios[0].then.ands[0].property.comments == ["some comments for Then And", ""]);
    }


    // white space at the start of description
    // only for one scenario
}

version (unittest) {
    import io = std.stdio;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourIssue : EXT;
    import std.stdio : File;
    import std.path;
}
