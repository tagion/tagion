module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourFeature;

import std.traits;
import std.format;
import std.meta : AliasSeq;
import std.range : only;
version (unittest)
{
    //    import std.stdio;
    public import tagion.behaviour.BehaviourUnittest;
    import tagion.hibon.Document;
    import io=std.stdio;
    import tagion.hibon.HiBONJSON;
}

/**
   Returns:
   true if all the behaviours has been runned
*/
@safe
ScenarioGroup run(T)(T scenario) if (isScenario!T)
{
    alias memberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Info index          %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
        }, string, string, size_t,string, string);
    ScenarioGroup scenario_group = getScenarioGroup!T;
    import std.uni : toLower;
    static foreach(_Property; BehaviourProperties) {
        {
            alias all_behaviours = getBehaviour!(T, _Property);
            static foreach(i, behaviour; all_behaviours) {{
                enum group_name = __traits(identifier, typeof(getProperty!(behaviour))).toLower;
                enum code = memberCode(
                    scenario_group.stringof, group_name, i,
                    scenario.stringof, __traits(identifier, behaviour));
                mixin(code);
                }}
            }
    }
    return scenario_group;
}

@safe
unittest {
    pragma(msg, "UNITTEST ", Some_awesome_feature);
    auto awesome = new Some_awesome_feature;
    const result = run(awesome);
}

@safe
unittest
{
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;

    auto awesome = new Some_awesome_feature;
    const runner_result = run(awesome);
    io.writefln("runner_result = %s", runner_result.toPretty);
    //    ScenarioGroup scenario=getScenarioGroup!Some_awesome_feature;
//    const result = runner_awesome();
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
    // const results = chain(
    //     runner_result.given,
    //     runner_result.when,
    //     runner_result.then,
    //     runner_result.but,
    //     )
    //     .map!(
    Document[] results;
    // results = chain(
    //     runner_result.given,
    //     runner_result.when,
    //     runner_result.then,
    //     runner_result.but,
    //     )
    //     .map!(group => group.infos)


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
    io.writefln("runner_result %s", runner_result.toPretty);
    io.writefln("results %-(%s %)", results.map!(doc => doc.toPretty));
    io.writefln("expected %-(%s %)", expected.map!(doc => doc.toPretty));
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
    static foreach (_Scenario; Scenarios!M)
    {
        {
            ScenarioGroup scenario_group = getScenarioGroup!_Scenario;
            scope (exit)
            {
                result.scenarios ~= scenario_group;
            }
            version (none)
            {
                scenario.info.property = getScenario!(_Scenario);
                scenario.info.name = _Scenario.stringof;
                static foreach (_Property; UniqueBehaviourProperties)
                {
                    {
                        alias behaviour = getBehaviour!(_Scenario, _Property);
                        static if (!is(behaviour == void))
                        {
                            import std.uni : toLower;

                            auto group = &__traits(getMember, scenario, _Property.stringof.toLower);

                            group.info.property = getProperty!behaviour;
                            group.info.name = __traits(identifier, behaviour);
                            static foreach (under_behaviour; getUnderBehaviour!(_Scenario, _Property))
                            {
                                {
                                    Info!And and;
                                    scope (exit)
                                    {
                                        group.ands ~= and;
                                    }
                                    and.property = getProperty!(under_behaviour);
                                    and.name = __traits(identifier, under_behaviour);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return result;
}

version (CBR) @safe
unittest
{ //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;

    alias Module = tagion.behaviour.BehaviourUnittest;
    import std.path;

    enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
            .unitfile
            .setExtension("hibon");
    const feature = getFeature!(Module);
    //    filename.fwrite(feature);
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}
