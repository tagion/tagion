/**
BDD markdown parser
*/
module tagion.behaviour.BehaviourParser;

import std.conv : to;
import std.format;
import std.meta;
import std.range.primitives : ElementType, isInputRange;
import std.regex;
import std.string : strip;
import std.traits;
import std.traits : Fields;
import std.uni : toLower;
import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourFeature : ActionProperties;
import tagion.hibon.HiBONRecord : GetLabel, recordType;

enum feature_regex = regex([
    `^\W*(feature)\W`, /// Feature
    `^\W*(scenario)\W`, /// Scenario
    r"^\W*(given|when|then|but)\W", /// Action
    r"`((?:\w+\.?)+)`", /// Name
], "i");

unittest {
    /// regex_given
    {
        const test = "---given when xxx";
        auto match = test.matchFirst(feature_regex);
        assert(match[1] == "given");
        assert(match.whichPattern == Token.ACTION);
    }
    /// regex_when
    {
        const test = "+++when rrrr when xxx";
        auto match = test.matchFirst(feature_regex);
        assert(match[1] == "when");
        assert(match.whichPattern == Token.ACTION);
    }
    /// regex_then
    {
        const test = "+-+-then fff rrrr when xxx";
        auto match = test.matchFirst(feature_regex);
        assert(match[1] == "then");
        assert(match.whichPattern == Token.ACTION);
    }
    /// regex_feature
    {
        const test = "****feature** fff rrrr when xxx";
        auto match = test.matchFirst(feature_regex);
        assert(match[1] == "feature");
        assert(match.whichPattern == Token.FEATURE);
    }
    /// regex_scenario
    {
        const test = "----++scenario* ddd fff rrrr when xxx";
        auto match = test.matchFirst(feature_regex);
        assert(match[1] == "scenario");
        assert(match.whichPattern == Token.SCENARIO);
    }
}

enum Token {
    NONE,
    FEATURE,
    SCENARIO,
    ACTION,
    NAME,
}

@safe
bool validAction(scope const(char[]) name) pure {
    import std.algorithm.searching : any;

    return !name.any!q{a == '.'};
}

enum State {
    Start,
    Feature,
    Scenario,
    Action,
}

@trusted
FeatureGroup parser(string filename, out string[] errors) {
    import std.stdio : File;

    auto by_line = File(filename).byLine;
    return parser(by_line, errors, filename);
}

@trusted
FeatureGroup parser(R)(R range, out string[] errors, string localfile = null)
        if (isInputRange!R && isSomeString!(ElementType!R)) {
    import std.algorithm.searching;
    import std.array;
    import std.range : enumerate;
    import std.string;

    FeatureGroup result;
    ScenarioGroup scenario_group;

    Info!Feature info_feature;
    State state;
    bool got_feature;
    int current_action_index = -1;

    foreach (line_no, line; range.enumerate(1)) {
        void check_error(const bool flag, string msg) {
            if (!flag) {
                errors ~= format("%s(%d): Error: %s", localfile, line_no, msg);
            }
        }

        auto match = range.front.matchFirst(feature_regex);

        const Token token = cast(Token)(match.whichPattern);
        with (Token) {
        TokenSwitch:
            final switch (token) {
            case NONE:
                immutable comment = match.post.strip.idup;
                final switch (state) {
                case State.Feature:
                    const _comment = comment.stripRight;
                    if (_comment.length) {
                        info_feature.property.comments ~= _comment;
                    }
                    break;
                case State.Scenario:
                    const _comment = comment.stripRight;
                    if (_comment.length) {
                        scenario_group.info.property.comments ~= _comment;
                    }
                    break;
                case State.Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "infos")) {
                            with (scenario_group.tupleof[index]) {
                                if (current_action_index is index) {
                                    const _comment = comment.stripRight;
                                    if (_comment.length) {
                                        infos[$ - 1].property.comments ~= _comment;

                                    }
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
                info_feature.property.description = match.post.strip.idup;
                state = State.Feature;
                got_feature = true;
                break;
            case NAME:
                final switch (state) {
                case State.Feature:
                    info_feature.name = match[1].idup;
                    break TokenSwitch;
                case State.Scenario:
                    check_error(match[1].validAction,
                    format("Not a valid action name %s,  '.' is not allowed", match[1]));
                    scenario_group.info.name = match[1].idup;
                    break TokenSwitch;
                case State.Action:
                    static foreach (index, Field; Fields!ScenarioGroup) {
                        static if (hasMember!(Field, "infos")) {
                            if (current_action_index is index) {
                                with (scenario_group.tupleof[index]) {
                                    check_error(infos[$ - 1].name.length == 0,
                                    format("Action name '%s' has already been defined for %s", match[0],
                                    infos[$ - 1].name));
                                    infos[$ - 1].name = match[1].strip.idup;
                                }
                                break TokenSwitch;
                            }
                        }
                    }
                    break TokenSwitch;
                case State.Start:
                    break TokenSwitch;
                }
                check_error(0, format("No valid action has %s", match[1]));
                break;
            case SCENARIO:
                check_error(got_feature, "Scenario without feature");
                if (state != State.Feature) {
                    result.scenarios ~= scenario_group;
                    scenario_group = ScenarioGroup.init;
                }
                current_action_index = -1;
                scenario_group.info.property.description = match.post.strip.idup;
                state = State.Scenario;
                break;
            case ACTION:
                state = State.Action;
                const action_word = match[1].toLower;
                alias ActionGroups = staticMap!(ActionGroup, ActionProperties);
                static foreach (int index, Field; Fields!ScenarioGroup) {
                    {
                        enum field_index = staticIndexOf!(Field, ActionGroups);
                        static if (field_index >= 0) {
                            enum label = GetLabel!(scenario_group.tupleof[index]);
                            enum action_name = label.name;
                            static if (hasMember!(Field, "infos")) {

                                if (action_word == action_name) {
                                    with (scenario_group.tupleof[index]) {

                                        check_error(current_action_index <= index,
                                                format("Bad action order for action %s", action_word));
                                        current_action_index = index;
                                        infos.length++;
                                        infos[$ - 1].property.description = match.post.strip.idup;
                                    }
                                }
                            }
                        }
                    }
                }
                break;
            }
        }
    }
    result.info = info_feature;
    if (scenario_group !is scenario_group.init) {
        result.scenarios ~= scenario_group;
    }
    return result;
}

/// Examples: How to parse a markdown file
unittest { /// Convert ProtoDBBTestComments to Feature
    import std.traits : FunctionTypeOf;
    import tagion.basic.basic : fileId;

    enum bddfile_proto = "ProtoBDDTestComments".unitfile;
    enum bdd_filename = bddfile_proto.setExtension(FileExtension.markdown);

    auto feature_byline = File(bdd_filename).byLine;

    string[] errors;
    auto feature = parser(feature_byline, errors);
    assert(errors is null);

    const fileid = fileId!(FunctionTypeOf!parser)(FileExtension.markdown);
    immutable markdown_filename = fileid.fullpath;

    import tagion.behaviour.BehaviourIssue;

    /// Write the markdown file
    auto fout = File(markdown_filename, "w");
    auto markdown = Markdown(fout);
    markdown.issue(feature);
    fout.close;

    immutable hibon_filename = markdown_filename
        .setExtension(FileExtension.hibon);

    import tagion.hibon.HiBONFile : fread, fwrite;

    hibon_filename.fwrite(feature);

    // Check that the feature can be reloaded
    const expected_feature = hibon_filename.fread!FeatureGroup;
    assert(feature.toDoc == expected_feature.toDoc);
    // Reparse the produced markdown and check if it is the same
    errors = null;
    auto produced_feature = parser(markdown_filename, errors);
    "/tmp/produced_feature.hibon".fwrite(produced_feature);
    assert(errors is null);
    assert(produced_feature.toDoc == expected_feature.toDoc);
}

version (unittest) {
    import std.path;
    import io = std.stdio;
    import std.stdio : File;
    import tagion.basic.Types : FileExtension;
    import tagion.basic.testbasic : unitfile;
    import tagion.hibon.HiBONJSON;
}
