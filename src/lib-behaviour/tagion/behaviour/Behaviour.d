module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourFeature;

import std.traits;
import std.format;
import std.meta : AliasSeq;
import std.range : only;
import std.array : join;
import tagion.behaviour.BehaviourException;

import tagion.basic.Types : FileExtension;

/**
   Run the scenario in Given, When, Then, But order
   Returns:
   The ScenarioGroup including the result of each action
*/
@safe
ScenarioGroup run(T)(T scenario) if (isScenario!T)
{
    ScenarioGroup scenario_group = getScenarioGroup!T;
    try {
    alias memberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Info index          %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
        }, string, string, size_t,string, string);
    import std.uni : toLower;
    .check(scenario !is null, format("The constructor must be called for %s before it's runned", T.stringof));
    static foreach(_Property; BehaviourProperties) {
        {
            alias all_behaviours = getBehaviour!(T, _Property);
            static if (is(all_behaviours == void)) {
                static assert(0, format("%s is missing a @%s action", T.stringof, _Property.stringof));
            }
            else {
            pragma(msg, "all_behaviours ", all_behaviours);
            static foreach(i, behaviour; all_behaviours) {{
                enum group_name = __traits(identifier, typeof(getProperty!(behaviour))).toLower;
                enum code = memberCode(
                    scenario_group.stringof, group_name, i,
                    scenario.stringof, __traits(identifier, behaviour));
                mixin(code);
                }}
            }
        }
    }
    }
    catch (Exception e) {
        io.writefln("RUN %s", e.msg);
        scenario_group.info.result = BehaviourError(e).toDoc;
        io.writefln("scenario_group.info.result = %s", scenario_group.info.result.toPretty);
    }
    return scenario_group;
}

@safe
unittest
{
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;

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
        .map!(a => Some_awesome_feature.result(a));
    io.writefln("awesome.count = %d", awesome.count);
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
ScenarioGroup getScenarioGroup(T)() if (isScenario!T)
{
    ScenarioGroup scenario_group;
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach (_Property; BehaviourProperties)
    {
        {
            alias behaviours = getBehaviour!(T, _Property);
            static if (!is(behaviours == void))
            {
                import std.uni : toLower;
                enum group_name = _Property.stringof.toLower;
                auto group = &__traits(getMember, scenario_group, group_name);
                group.infos.length = behaviours.length;
                static foreach (i, behaviour; behaviours)
                {{
                    Info!_Property info;
                    info.property = getProperty!behaviour;
                    info.name = __traits(identifier, behaviour);
                    group.infos[i]=info;
                    }}
            }
        }
    }
    return scenario_group;
}

@safe
FeatureGroup getFeature(alias M)() if (isFeature!M)
{
    //    import std.stdio;
    FeatureGroup result;
    result.info.property = obtainFeature!M;
    result.info.name = moduleName!M;
    alias ScenariosSeq = Scenarios!M;
    result.scenarios.length = ScenariosSeq.length;
    static foreach (i, _Scenario; ScenariosSeq)
    {
        result.scenarios[i] =getScenarioGroup!_Scenario;
    }
    return result;
}

@safe
unittest
{ //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;

    alias Module = tagion.behaviour.BehaviourUnittest;
    import std.path;

    enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
            .unitfile
            .setExtension(FileExtension.hibon);
    const feature = getFeature!(Module);
    /+ test file printout
+/
     (filename.stripExtension~"_test")
     .setExtension(FileExtension.hibon)
     .fwrite(feature);
//     +/
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}

protected string _scenarioTupleCode(alias M, string tuple_name)() if (isFeature!M) {
    string[] result;
    {
        result ~= format("alias %s = Tuple!(", tuple_name);
        scope(exit) {
            result ~= ");";
        }
        static foreach(_Scenario; Scenarios!M) {
            result~=format(q{%1$s, "%1$s",}, _Scenario.stringof);
        }
    }
    return result.join("\n");
}

mixin template ScenarioTuple(alias M, string tuple_name) {
    import std.array : join;
    import std.format;
    enum code = _scenarioTupleCode!(M, tuple_name);
    mixin(code);
}

@safe
auto automation(alias M)() if (isFeature!M) {
    import std.typecons;
//     alias ScenariosSeq = Scenarios!M;
//     pragma(msg, "ScenariosSeq ", ScenariosSeq);
//     pragma(msg, "ScenariosSeq ", ScenariosSeq[0], " : ", ScenariosSeq[0].stringof);
// //    const xxx=_scenarioTupleCode!(M)("ScenarionTuple");
//     pragma(msg, _scenarioTupleCode!(M, "ScenarioTuple")());
    static struct FeatureFactory {
        Feature feature;
        // Defines the tuple of the Feature scenarios
        mixin ScenarioTuple!(M, "ScenariosT");
        ScenariosT scenarios;
        void opDispatch(string scenario_name, Args...)(Args args) {
            pragma(msg, "Scenarios.fieldNames ", ScenariosT.fieldNames);

            enum code = format(q{scenarios.%1$s = new ScenariosT.%1$s(args);}, scenario_name);
            pragma(msg, code);

        }
        FeatureGroup run() nothrow {
            import tagion.behaviour.BehaviourException : BehaviourError;
            FeatureGroup result;
            result.info.property = obtainFeature!M;
            result.info.name = moduleName!M;
            alias ScenariosSeq = Scenarios!M;
            result.scenarios.length = ScenariosSeq.length;
            static foreach (i, _Scenario; ScenariosSeq)
            {
                try {
                    io.writefln("run %s ", _Scenario.stringof);
                    static if (__traits(compiles, new _Scenario())) {
                        if (result.scenarios[i] is null) {
                            result.scenarios[i] = new _Scenario();
                        }
                    }
                    pragma(msg, "scenarios[i] ", typeof(scenarios[i]));
                    result.scenarios[i] = .run(scenarios[i]);
                }
                catch (Exception e) {
                    import std.exception : assumeWontThrow;
                    // assumeWontThrow({
                    //         io.writefln("FeatureGroup run %s", e.msg);
                    result.scenarios[i].info.result = assumeWontThrow(BehaviourError(e).toDoc);
                        // });
                }
            }
            return result;
        }

    }
    FeatureFactory result;
//    auto feature
    return result;
}

bool hasError(const Feature) {
    return false;
}
/// Test Feature automation
@safe
unittest {
    auto feature_with_ctor = automation!(WithCtor)();
    const feature_result=feature_with_ctor.run;
    io.writefln("feature_result_with_ctor=%s", feature_result.toPretty);
//    feature_with_ctor.Some_awesome_feature(42, "with_ctor");
}

version (unittest)
{
    //    import std.stdio;
    import tagion.behaviour.BehaviourUnittest;
    import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;
    import tagion.hibon.Document;
    import io=std.stdio;
    import tagion.hibon.HiBONJSON;
}
