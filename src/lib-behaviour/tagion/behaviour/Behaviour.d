module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourFeature;
import tagion.hibon.Document;

import core.exception : AssertError;
import std.traits;
import std.format;
import std.meta : AliasSeq;
import std.range : only;
import std.array : join;
import std.algorithm.searching : any, all;
import std.exception : assumeWontThrow;

import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourResult;
import tagion.behaviour.BehaviourReporter;
import tagion.basic.Types : FileExtension;
import tagion.hibon.HiBONRecord;
import tagion.basic.basic : isOneOf;

/**
   Runs the scenario in Given, When, Then, But order
   Returns:
   The ScenarioGroup including the result of each action
*/
@trusted
ScenarioGroup run(T)(T scenario) if (isScenario!T) {
    ScenarioGroup scenario_group = getScenarioGroup!T;
    debug (bdd) import std.stdio;

    debug (bdd)
        writefln("Feature: %s", scenario_group.info.property.description);

    try {
        // Mixin code to produce the action Given, When, Then, But
        alias memberCode = format!(q{
            // Scenario group      %1$s
            // Action propery info %2$s
            // Info index (i)      %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            //            $ Given: some scenario scenario descriotion
            debug(bdd) writeln("%2$s: ", %1$s.%2$s.infos[%3$d].property.description);
            try {
                // Example.
                // scenario_group.when.info[i].result = scenario.member_function;
                %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
            }
            catch (Exception e) {
                // In case of an exception error the result is set to a BehaviourError
                // Example.
                // scemario_group.when.info[i].result = BehaviourError(e).toDoc;
                %1$s.%2$s.infos[%3$d].result= BehaviourError(e).toDoc;
            }
        }, string, string, size_t, string, string);
        import std.uni : toLower;

        

        .check(scenario !is null,
                format("The constructor must be called for %s before it's runned", T.stringof));
        static foreach (_Property; ActionProperties) {
            {
                alias all_actions = getActions!(T, _Property);
                static if (is(all_actions == void)) {
                    static assert(!isOneOf!(_Property, MandatoryActionProperties),
                            format("%s is missing a @%s action", T.stringof, _Property.stringof));
                }
                else {
                    // Traverse all the actions the scenario
                    static foreach (i, behaviour; all_actions) {
                        {
                            // This action_name is the action of the scenario
                            // The action is the lower case of Action type (ex. Given is given)
                            // See the definition of ScenarioGroup
                            enum action_name = __traits(identifier,
                                        typeof(getProperty!(behaviour))).toLower;
                            enum code = memberCode(
                                        scenario_group.stringof, action_name, i,
                                        scenario.stringof, __traits(identifier, behaviour));
                            // The memberCode is used here
                            mixin(code);
                        }
                    }
                }
            }
        }
        scenario_group.info.result = result_ok;
    }
    catch (Exception e) {
        debug (bdd) {
            writefln("BDD Caught Exception:\n\n%s", e);
        }
        scenario_group.info.result = BehaviourError(e).toDoc;
    }
    // We want to be able to report asserts as well
    catch (AssertError e) {
        debug (bdd) {
            writefln("BDD Caught AssertError:\n\n%s", e);
        }
        scenario_group.info.result = BehaviourError(e).toDoc;
    }
    return scenario_group;
}

///Examples: How use the rub fuction on a feature
@safe
unittest {
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;
    import tagion.behaviour.BehaviourUnittest;

    auto awesome = new Some_awesome_feature;
    const runner_result = run(awesome);
    auto expected = only(
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_valid",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.in_credit",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.contains_cash",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.request_cash",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_debited",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_dispensed",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.swollow_the_card",
    )
        .map!(a => result(a));
    assert(awesome.count == 7);
    Document[] results;
    results ~= runner_result.given.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.when.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.then.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.but.infos
        .map!(info => info.result)
        .array;
    assert(equal(results, expected));
}

@safe
ScenarioGroup getScenarioGroup(T)() if (isScenario!T) {
    ScenarioGroup scenario_group;
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach (_Property; ActionProperties) {
        {
            alias behaviours = getActions!(T, _Property);
            static if (!is(behaviours == void)) {
                import std.uni : toLower;

                enum group_name = _Property.stringof.toLower;
                auto group = &__traits(getMember, scenario_group, group_name);
                group.infos.length = behaviours.length;
                static foreach (i, behaviour; behaviours) {
                    {
                        Info!_Property info;
                        info.property = getProperty!behaviour;
                        info.name = __traits(identifier, behaviour);
                        group.infos[i] = info;
                    }
                }
            }
        }
    }
    return scenario_group;
}

@safe
FeatureGroup getFeature(alias M)() if (isFeature!M) {
    FeatureGroup result;
    result.info.property = obtainFeature!M;
    result.info.name = moduleName!M;
    alias ScenariosSeq = Scenarios!M;
    result.scenarios.length = ScenariosSeq.length;
    static foreach (i, _Scenario; ScenariosSeq) {
        result.scenarios[i] = getScenarioGroup!_Scenario;
    }
    return result;
}

///Examples: How to use getFeature on a feature

@safe
unittest { //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.basic : unitfile;
    import core.demangle : mangle;

    import Module = tagion.behaviour.BehaviourUnittest;
    import std.path;

    enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
            .unitfile
            .setExtension(FileExtension.hibon);
    const feature = getFeature!(Module);
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}

@safe
auto automation(alias M)() if (isFeature!M) {
    import std.typecons;
    import std.algorithm.searching : any;

    mixin(format(q{import %s;}, moduleName!M));

    @safe
    static struct FeatureFactory {
        string alternative;
        FeatureContext context;
        void opDispatch(string scenario_name, Args...)(Args args) {
            import std.algorithm.searching : countUntil;

            enum tuple_index = [FeatureContext.fieldNames]
                    .countUntil(scenario_name);
            static assert(tuple_index >= 0,
                    format("Scenarion '%s' does not exists. Possible scenarions is\n%s",
                    scenario_name, [FeatureContext.fieldNames[0 .. $ - 1]].join(",\n")));
            alias _Scenario = FeatureContext.Types[tuple_index];
            context[tuple_index] = new _Scenario(args);
        }

        bool create(Args...)(string regex_text, Args args) {
            const index = find_scenario(regex_text);
            import std.stdio;

            switch (index) {
                static foreach (tuple_index; 0 .. FeatureContext.Types.length - 1) {
                    {
                        alias _Scenario = FeatureContext.Types[tuple_index];
                        enum scenario_property = getScenario!_Scenario;
                        enum compiles = __traits(compiles, new _Scenario(args));
            case tuple_index:
                        static if (compiles) {
                            context[tuple_index] = new _Scenario(args);
                            return true;
                        }
                        else {
                            check(false,
                                    format("Arguments %s does not match construct of %s",
                                    Args.stringof, _Scenario.stringof));
                        }
                        // return true;
                    }
                }
            default:
                return false;

            }
            return false;
        }

        static int find_scenario(string regex_text) {
            import std.regex;

            const search_regex = regex(regex_text);

            static foreach (tuple_index; 0 .. FeatureContext.Types.length - 1) {
                {
                    alias _Scenario = FeatureContext.Types[tuple_index];
                    enum scenario_property = getScenario!_Scenario;
                    //                    enum compiles = __traits(compiles, new _Scenario(args));
                    if (!scenario_property.description.matchFirst(search_regex).empty ||
                            scenario_property.comments.any!(c => !c.matchFirst(search_regex).empty)) {
                        return tuple_index;
                    }
                }
            }
            return -1;
        }

        version (none) auto find(string regex_text)() {
            import std.regex;

            enum tuple_index = find_scenario(regex_text);
            static assert(tuple_index >= 0, format("Scenario description with '%s' not found in %s", regex_text, FeatureContext
                    .stringof));
            return FeatureContext.Types[tuple_index];
        }

        @safe
        FeatureContext run() nothrow {
            if (reporter !is null) {
                auto raw_feature_group = getFeature!M;
                raw_feature_group.alternative = alternative;
                reporter.before(&raw_feature_group);
            }
            scope (exit) {
                if (reporter !is null) {
                    context.result.alternative = alternative;
                    reporter.after(context.result);
                }

            }
            uint error_count;
            context.result = new FeatureGroup;
            context.result.info.property = obtainFeature!M;
            context.result.info.name = moduleName!M;
            context.result.scenarios.length = FeatureContext.Types.length - 1; //ScenariosSeq.length;
            static foreach (i, _Scenario; FeatureContext.Types[0 .. $ - 1]) {
                try {
                    static if (__traits(compiles, new _Scenario())) {
                        if (context[i] is null) {
                            context[i] = new _Scenario();
                        }
                    }
                    else {
                        check(context[i]!is null,
                        format("Scenario '%s' must be constructed before can be executed in '%s' feature",
                                FeatureContext.fieldNames[i],
                                moduleName!M));
                    }
                    context.result.scenarios[i] = .run(context[i]);
                }
                catch (Exception e) {
                    error_count++;
                    import std.exception : assumeWontThrow;

                    context.result.scenarios[i].info.result = assumeWontThrow(BehaviourError(e)
                            .toDoc);
                }
            }
            if (error_count == 0) {
                context.result.info.result = result_ok;
            }
            return context;
        }
    }

    FeatureFactory result;
    return result;
}

/**
   Returns:
   true if one of more scenarios in the Feature has failed
 */
@safe
bool hasErrors(ref const FeatureGroup feature_group) nothrow {
    if (BehaviourError.isRecord(feature_group.info.result)) {
        return true;
    }
    return feature_group.scenarios.any!(scenario => scenario.hasErrors);
}

@safe
bool hasErrors(const(FeatureGroup*) feature_group) nothrow {
    return hasErrors(*feature_group);
}

/**
   Returns:
   true if one of more actions in the Scenario has failed
 */
@safe
bool hasErrors(ref const ScenarioGroup scenario_group) nothrow {
    static foreach (i, Type; Fields!ScenarioGroup) {
        static if (isActionGroup!Type) {
            if (scenario_group.tupleof[i].infos.any!(info => info.result.isRecord!BehaviourError)) {
                return true;
            }
        }
        else static if (isInfo!Type) {
            if (scenario_group.tupleof[i].result.isRecord!BehaviourError) {
                return true;
            }
        }
    }
    return false;
}

/* import std.algorithm.iteration: filter, each; */
const(BehaviourError)[] getBDDErrors(const(ScenarioGroup) scenarioGroup) {
    const(BehaviourError)[] errors;
    // How do i statically iteratate over each actionGroup member of scenarioGroup
    foreach (info; scenarioGroup.given.infos) {
        if (info.result.isRecord!BehaviourError) {
            const result = BehaviourError(info.result);
            errors ~= result;
        }
    }
    foreach (info; scenarioGroup.when.infos) {
        if (info.result.isRecord!BehaviourError) {
            const result = BehaviourError(info.result);
            errors ~= result;
        }
    }
    foreach (info; scenarioGroup.then.infos) {
        if (info.result.isRecord!BehaviourError) {
            const result = BehaviourError(info.result);
            errors ~= result;
        }
    }
    foreach (info; scenarioGroup.but.infos) {
        if (info.result.isRecord!BehaviourError) {
            const result = BehaviourError(info.result);
            errors ~= result;
        }
    }
    return errors;
}

///Examples: Show how to use the automation function and the hasError on a feature group
@safe
unittest {
    import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

    auto feature_with_ctor = automation!(WithCtor)();

    { // No constructor has been called for the scenarios, this means that scenarios and the feature will have errors
        const feature_context = feature_with_ctor.run;
        assert(feature_context.result.scenarios[0].hasErrors);
        assert(feature_context.result.scenarios[1].hasErrors);
        assert(feature_context.result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_feature_errors.hibon".fwrite(feature_context.result);
    }

    { // Fails in second scenario because the constructor has not been called
        // Calls the construction for the Some_awesome_feature scenario
        feature_with_ctor.Some_awesome_feature(42, "with_ctor");
        const feature_context = feature_with_ctor.run;
        assert(!feature_context.result.scenarios[0].hasErrors);
        assert(feature_context.result.scenarios[1].hasErrors);
        assert(feature_context.result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_scenario_errors.hibon".fwrite(feature_context.result);
    }

    { // The constructor of both scenarios has been called, this means that no errors is reported
        // Calls the construction for the Some_awesome_feature scenario
        feature_with_ctor.Some_awesome_feature(42, "with_ctor");
        feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);
        const feature_context = feature_with_ctor.run;
        assert(!feature_context.result.scenarios[0].hasErrors);
        assert(!feature_context.result.scenarios[1].hasErrors);
        assert(!feature_context.result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_no_errors.hibon".fwrite(feature_context.result);
    }
}

/**
Checks if a feature has passed all tests
   Returns:
   true if all scenarios in a Feature has passed all tests
 */
@safe
bool hasPassed(ref const FeatureGroup feature_group) nothrow {
    return feature_group.info.result.isRecord!Result &&
        feature_group.scenarios.all!(scenario => scenario.hasPassed);
}

@safe
bool hasPassed(const(FeatureGroup*) feature_group) nothrow {
    return hasPassed(*feature_group);
}

/**
Used to checks if a scenario has passed all tests
Params:
scenario_group = The scenario which been runned
Returns: true if the scenario has passed all tests
*/
@safe
bool hasPassed(ref const ScenarioGroup scenario_group) nothrow {
    static foreach (i, Type; Fields!ScenarioGroup) {
        static if (isActionGroup!Type) {
            if (scenario_group
                    .tupleof[i].infos
                    .any!(info => !info
                        .result
                        .isRecord!Result)) {
                return false;
            }
        }
        else static if (isInfo!Type) {
            if (!scenario_group
                    .tupleof[i]
                    .result
                    .isRecord!Result) {
                return false;
            }
        }
    }
    return true;
}

@safe
bool hasStarted(ref const ScenarioGroup scenario_group) nothrow {
    static foreach (i, Type; Fields!ScenarioGroup) {
        static if (isActionGroup!Type) {
            if (!scenario_group
                    .tupleof[i].infos
                    .any!(info => !info
                        .result
                        .empty)) {
                return true;
            }
        }
    }
    return false;
}

@safe
bool hasStarted(ref const FeatureGroup feature_group) nothrow {
    return feature_group.scenarios.any!(scenario => scenario.hasStarted);
}

enum TestCode {
    none,
    passed,
    error,
    started,
}

@safe
TestCode testCode(Group)(Group group) nothrow
if (is(Group : const(ScenarioGroup)) || is(Group : const(FeatureGroup))) {
    TestCode result;
    if (hasPassed(group)) {
        result = TestCode.passed;
    }
    else if (hasErrors(group)) {
        result = TestCode.error;
    }
    else if (hasStarted(group)) {
        result = TestCode.started;
    }
    return result;
}

@safe
string testColor(const TestCode code) nothrow pure {
    import tagion.utils.Term;

    with (TestCode) {
        final switch (code) {
        case none:
            return BLUE;
        case passed:
            return GREEN;
        case error:
            return RED;
        case started:
            return YELLOW;
        }
    }
}

@safe
unittest {

    import WithoutCtor = tagion.behaviour.BehaviourUnittestWithoutCtor;

    auto feature_without_ctor = automation!(WithoutCtor)();
    { // None of the scenario passes
        const feature_context = feature_without_ctor.run;
        assert(!feature_context.result.scenarios[0].hasPassed);
        assert(!feature_context.result.scenarios[1].hasPassed);
        assert(!feature_context.result.hasPassed);
    }
}

///Examples: Shows how to use a automation on scenarios with constructor and the hasParssed
@safe
unittest {
    // Test of hasPassed function on Scenarios and Feature
    import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

    auto feature_with_ctor = automation!(WithCtor)();
    feature_with_ctor.Some_awesome_feature(42, "with_ctor");
    feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);

    { // None of the scenario passes
        const feature_context = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_has_failed.hibon".fwrite(feature_context.result);
        assert(!feature_context.result.scenarios[0].hasPassed);
        assert(!feature_context.result.scenarios[1].hasPassed);
        assert(!feature_context.result.hasPassed);
    }

    { // One of the scenario passed
        WithCtor.pass_one = true;
        const feature_context = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_one_has_passed.hibon".fwrite(feature_context.result);
        assert(!feature_context.result.scenarios[0].hasPassed);
        assert(feature_context.result.scenarios[1].hasPassed);
        assert(!feature_context.result.hasPassed);
    }

    { // Some actions passed passes
        WithCtor.pass_some = true;
        WithCtor.pass_one = false;
        const feature_context = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_some_actions_has_passed.hibon".fwrite(feature_context.result);
        assert(!feature_context.result.scenarios[0].hasPassed);
        assert(!feature_context.result.scenarios[1].hasPassed);
        assert(!feature_context.result.hasPassed);
    }

    { // All of the scenario passes
        WithCtor.pass = true; /// Pass all tests!
        WithCtor.pass_some = false;

        const feature_context = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_has_passed.hibon".fwrite(feature_context.result);
        assert(feature_context.result.scenarios[0].hasPassed);
        assert(feature_context.result.scenarios[1].hasPassed);
    }
}

@safe
unittest {
    import WithCtor = tagion
        .behaviour
        .BehaviourUnittestWithCtor;

    auto feature_with_ctor = automation!(WithCtor)();
    assert(feature_with_ctor.create("bankster", 17));
    assertThrown!BehaviourException(feature_with_ctor.create("bankster", "wrong argument"));
    assert(!feature_with_ctor.create("this-text-does-not-exists", 17));
}

version (unittest) {
    import tagion.hibon.Document;
    import tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBONJSON;
    import std.exception;
}
