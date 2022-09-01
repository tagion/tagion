module tagion.behaviour.BehaviourParser;

import tagion.behaviour.BehaviourFeature;

import std.range.primitives : isInputRange, ElementType;
import std.traits;
import std.regex;
import std.string : strip;
import std.format;
import std.traits : Fields;
import std.meta;
import std.uni : toLower;
import std.conv : to;

import tagion.hibon.HiBONRecord : RecordType, GetLabel;
import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourFeature : BehaviourProperties;

enum feature_regex = regex([
        `feature(?:\s+|\:)`, /// Feature
        `scenario(?:\s+|\:)`, /// Scenario
        r"\s*\*(\w+)\*", /// Action
        //  r"\s*`(\w+)`", /// Name
        r"`((?:\w+\.?)+)`", /// Name
    ], "i");

enum Token {
    NONE,
    FEATURE,
    SCENARIO,
    ACTION,
    NAME, // MODULE,
}

bool validAction(scope const(char[]) name) pure {
    import std.algorithm.searching : any;

    return !name.any!q{a == '.'};
}

enum State {
    Start,
    Feature,
    Scenario,
    Action, //    And_Action,
}

// enum CurrentAction {
//     none,
//     given,
//     when,
//     then,
//     but
// }

// CurrentAction currentAction(scope const(char[]) action_word) pure {
//     switch (action_word) {
//         static foreach(E; EnumMembers!CurrentAction) {
//             static if (E !is CurrentAction.none) {
//             case E.to!string:
//                 return E;

//             }
//         }
//     default:
//         return CurrentAction.none;
//     }
//     assert(0);
// }

@trusted
FeatureGroup parser(string filename, out string[] errors) {
    import std.stdio : File;

    auto by_line = File(filename).byLine;
    return parser(by_line, errors, filename);
}

@trusted
FeatureGroup parser(R)(R range, out string[] errors, string localfile = null)
        if (isInputRange!R && isSomeString!(ElementType!R)) {
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
    bool got_feature;
    writeln("STARTTTTTTT--------------------------------------------------------------------------------------------------------------");
    //CurrentAction current_action;
    int current_action_index = -1;
    //    string[] errors;
    foreach (line_no, line; range.enumerate(1)) {
        void check_error(const bool flag, string msg) {
            if (!flag) {
                errors ~= format("%s(%d): Error: %s", localfile, line_no, msg);
            }
        }
        //        writeln("______________________________________");
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
                    //case State.And_Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "infos")) {
                            with (scenario_group.tupleof[index]) {
                                if (current_action_index is index) {
                                    infos[$ - 1].property.comments ~= comment;
                                }
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
                check_error(state is State.Start, "Feature has already been declared in line");
                writeln("Hi from Feature!!! ", line);
                info_feature.property.description = match.post.idup;
                state = State.Feature;
                got_feature = true;
                break;
            case NAME:
                // check_error(match[1].validAction || (state !is State.Feature),
                //         format("Illegal (namespace) name %s for %s", match[1], match.pre));
                // check_error(state is State.Feature, "Module name can only be declare after the Feature declaration");
                final switch (state) {
                case State.Feature:
                    info_feature.name = match[1].idup;
                    break TokenSwitch;
                case State.Scenario:
                    check_error(match[1].validAction, format("Not a valid action name %s,  '.' is not allowed", match[1]));
                    info_scenario.name = match[1].idup;
                    break TokenSwitch;
                case State.Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "infos")) {
                            if (current_action_index is index) {
                                with (scenario_group.tupleof[index]) {
                                    check_error(infos[$ - 1].name.length == 0,
                                            format("Action name '%s' has already been defined for %s", match[0],
                                            infos[$ - 1].name));
                                    infos[$ - 1].name = match[1].idup;
                                }
                                break TokenSwitch;
                            }
                        }
                    }
                    break TokenSwitch;
                case State.Start:
                    writefln("Start %s", match);
                    break TokenSwitch;
                }
                check_error(0, format("No valid action has %s", match[1]));
                writeln("STATEEEE: ", state);
                break;
            case SCENARIO:
                //current_action = CurrentAction.none;
                check_error(got_feature, "Scenario without feature");
                current_action_index = -1;
                //check_error(state is State.Feature || state is State.Scenario, "Scenario must be declared after a Feature");
                writeln("Hi from SCENARIO!!! ", line);
                info_scenario.property.description = match.post.idup;
                state = State.Scenario;
                break;
            case ACTION:
                writeln("Hi from action!!!!!!!!!!!!");
                state = State.Action;
                const action_word = match[1].toLower;
                // current_action = currentAction(action_word);
                // check_error(current_action !is CurrentAction.none, format("Invalid action %s", action_word));
                // if (action_word == "and") {
                //     check_error(current_action_index >= 0, "Missing action Given, When or Then before And");
                //     static foreach (index, Field; Fields!ScenarioGroup) {
                //         version(none)
                //         static if (isActionGroup!Field) {
                //             if (current_action_index == index) {
                //                 Info!And and;
                //                 and.property.description = match.post.idup;
                //                 pragma(msg, "Field ", Fields!ScenarioGroup[index]);
                //                 pragma(msg, ":::", FieldNameTuple!(typeof(scenario_group.tupleof[index])));
                //                 version(none_and) scenario_group.tupleof[index].ands ~= and;
                //                 version(none_and) pragma(msg, ":::", typeof(scenario_group.tupleof[index].ands));
                //             }
                //         }
                //     }
                //     //state = State.And_Action;
                //     break;
                // }
                alias ActionGroups = staticMap!(ActionGroup, BehaviourProperties);
                pragma(msg, "ActionGroups ", ActionGroups);
                writefln("Action match %s", match);
                static foreach (index, Field; Fields!ScenarioGroup) {
                    {
                        pragma(msg, "ActionGroups Field ", Field);
                        enum field_index = staticIndexOf!(Field, ActionGroups);
                        static if (field_index >= 0) {
                            enum label = GetLabel!(scenario_group.tupleof[index]);
                            enum action_name = label.name;
                            // enum code = format(q{enum next_action=CurrentAction.%s;}, action_name);
                            // pragma(msg, code);
                            // mixin(code);
                            static if (hasMember!(Field, "infos")) {

                                if (action_word == action_name) {
                                    with (scenario_group.tupleof[index]) {
                                        check_error(current_action_index <= index,
                                                format("Bad action order for action %s", action_word));
                                        current_action_index = index;
                                        pragma(msg, "label ", typeof(label));
                                        //io.writefln("label %s", action_word);
                                        infos.length++; // ~= typeof(Field.infos).init;
                                        //io.writefln("length %s index=%d", scenario_group.tupleof[index].infos.length, index);
                                        infos[$ - 1].property.description = match.post.idup;
                                    }
                                }
                            }
                            // current_action = next_action;
                            // pragma(msg, "___action_name ", label.name);
                            // // enum action_name=getUDAs!(UniqueBehaviourProperties[field_index], RecordType)[0].name.toLower;
                            // pragma(msg, "action_name ", action_name);

                            // writefln("action %s match = %s index=%d", action_name, match[1].toLower, index);

                            // if (match[1].toLower == label.name) {
                            //     writefln("!!!! %s", label.name);
                            //     current_action_index = index;
                            //     scenario_group.tupleof[index].infos[0].property.description = match.post.idup;

                            //     break TokenSwitch;
                            // }
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
    immutable bdd_filename = bddfile_proto.unitfile.setExtension(FileExtension.markdown);
    io.writefln("bdd_filename=%s", bdd_filename);

    auto feature_byline = File(bdd_filename).byLine;

    // alias ByLine = typeof(feature_byline);
    // pragma(msg, "isInputRange ", isInputRange!ByLine);
    // pragma(msg, "ElementType!ByLine ", ElementType!ByLine);
    // pragma(msg, "isSomeString!(ElementType!ByLine) ", isSomeString!(ElementType!ByLine));

    string[] errors;
    auto feature = parser(feature_byline, errors);

    enum bddfile_proto_test = bddfile_proto~"_test";
    immutable markdown_filename = bddfile_proto_test
        .unitfile.setExtension(FileExtension.markdown);


    import tagion.behaviour.BehaviourIssue;

    auto fout = File(markdown_filename, "w");
    scope(exit) {
        fout.close;
    }
    auto markdown = Markdown(fout);
    markdown.issue(feature);
    // fout.writeln("------");
    // fout.writefln("feature.comments %s", feature.info.property.comments);
    immutable hibon_filename = markdown_filename
        // bddfile_proto_test
        // .unitfile
        .setExtension(FileExtension.hibon);

    import tagion.hibon.HiBONRecord : fwrite;

//    markdown_filename.fwrite(bout.toString);

    hibon_filename.fwrite(feature);
    // { // Check ProtoDBBTestComments converted to check
    //     // Feature feature
    //     assert(feature.info.name == "tagion.behaviour.unittest.ProtoBDD");
    //     assert(feature.info.property.description == " Some awesome feature should print some cash out of the blue(descr)");
    //     assert(feature.info.property.comments == ["Some addtion notes", "my comment1", "my comment2 a lot spaces", ""]);
    //     // check scenario
    //     assert(feature.scenarios[0].info.name == "Some_awesome_money_printer");
    //     assert(feature.scenarios[0].info.property.description == " Some awesome money printer");
    //     assert(feature.scenarios[0].info.property.comments == ["\u200B   comments", ""]); // Why?
    //     // check given
    //     assert(feature.scenarios[0].given.infos[0].name == "is_valid");
    //     assert(feature.scenarios[0].given.infos[0].property.description == " the card is valid");
    //     assert(feature.scenarios[0].given.infos[0].property.comments == ["some comments scenario", ""]);
    //     version (none_and) {
    //         assert(feature.scenarios[0].given.infos.length == 2);
    //         assert(feature.scenarios[0].given.infos[0].name == "in_credit");
    //         assert(feature.scenarios[0].given.infos[0].property.description == " the account is in credit");
    //         assert(feature.scenarios[0].given.infos[0].property.comments == ["some comments Given And", ""]);
    //         assert(feature.scenarios[0].given.infos[1].name == "contains_cash");
    //         assert(feature.scenarios[0].given.infos[1].property.description == " the dispenser contains cash");
    //         assert(feature.scenarios[0].given.infos[1].property.comments == [""]);
    //     }
    //     // check when
    //     assert(feature.scenarios[0].when.infos[0].name == "request_cash");
    //     assert(feature.scenarios[0].when.infos[0].property.description == " the Customer request cash");
    //     assert(feature.scenarios[0].when.infos[0].property.comments == ["some comments for When"]);
    //     version (none_ands)
    //         assert(feature.scenarios[0].when.ands.length == 0);
    //     // check then
    //     assert(feature.scenarios[0].then.infos[0].name == "is_debited");
    //     assert(feature.scenarios[0].then.infos[0].property.description == " the account is debited");
    //     assert(feature.scenarios[0].then.infos[0].property.comments == ["some comments for Then", ""]);
    //     version (none_and) {
    //         assert(feature.scenarios[0].then.ands.length == 1);
    //         assert(feature.scenarios[0].then.ands[0].name == "is_dispensed");
    //         assert(feature.scenarios[0].then.ands[0].property.description == " the cash is dispensed");
    //         assert(feature.scenarios[0].then.ands[0].property.comments == ["some comments for Then And", ""]);
    //     }
    // }

    // white space at the start of description
    // only for one scenario
}

version (unittest) {
    import io = std.stdio;
    import tagion.basic.Basic : unitfile;
    import tagion.basic.Types : FileExtension;
    import std.stdio : File;
    import std.path;
}
