module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourBase;

import std.traits;
import std.format;
import std.meta : AliasSeq;

version(unittest) {
//    import std.stdio;
    public import tagion.behaviour.BehaviourUnittest;
    import tagion.hibon.Document;
}

/**
   Returns:
   true if all the behavios has been runned
*/
@safe
auto scenario(T)(T test) if (isScenario!T) {
    alias memberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Test scenario       %3$s
            // Test member         %4$s
            %1$s.%2$s.info.result = %3$s.%4$s;
        },string, string, string, string);
    alias underMemberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Test scenario       %3$s
            // Test member         %4$s
            // Under index         %5$d
            auto and = %3$s.%4$s;
            %1$s.%2$s.ands[%5$d].result = and;
        },string, string, string, string, size_t);
//    auto
//    Document[] results;
    auto scenario_group=getScenarioGroup!T;
    ScenarioGroup run(S...)() {
        static if (S.length is 0) {
            return scenario_group;
        }
        else {
            alias behaviour = getBehaviour!(T, S[0]);
            static foreach(Property; AliasSeq!(Given, Then)) {
                static if (is(S[0] == Property)) {
                    static assert(!is(behaviour),
                        format!"%s of the Scenario %s is missing"
                        (Property.stringof, T.stringof));
                }
            }
            static if (!is(behaviour == void)) {
                import std.uni : toLower;
                enum group_name = __traits(identifier, typeof(getProperty!(behaviour))).toLower;
                pragma(msg, "group_name ", group_name);
                enum code = memberCode(
                    scenario_group.stringof, group_name,
                    test.stringof, __traits(identifier, behaviour));
                pragma(msg, "code ", code);
                mixin(code);
                static foreach(i, under_behaviour; getUnderBehaviour!(T, S[0])) {{
                        // enum under_group_name = __traits(identifier, typeof(getProperty!(under_behaviour))).toLower;
                        // pragma(msg, "unde_group_name ", under_group_name);
                        enum under_code = underMemberCode(
                            scenario_group.stringof, group_name,
                            test.stringof, __traits(identifier, under_behaviour), i);
                        pragma(msg, "under_code ", under_code);
                        mixin(under_code);
                    }}
            }
            return run!(S[1..$])();
//            return scenario_group;
        }
    }
    return &run!UniqueBehaviourProperties;
}

unittest {
    import tagion.hibon.HiBONJSON;
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;
    import std.stdio;
    auto awesome = new Some_awesome_feature;
    const run_awesome=scenario(awesome);
    ScenarioGroup scenario=getScenarioGroup!Some_awesome_feature;
    const result = run_awesome();
    auto expected = [
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_valid",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.in_credit",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.contains_cash",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.request_cash",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_debited",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_dispensed"
        ]
        .map!(a => Some_awesome_feature.result(a));
    assert(awesome.count == 6);
    Document[] results;
    results~=result.given.info.result;
    results~=result.given.ands
        .map!(a => a.result)
        .array;
    results~=result.when.info.result;
    results~=result.when.ands
        .map!(a => a.result)
        .array;
    results~=result.then.info.result;
    results~=result.then.ands
        .map!(a => a.result)
        .array;

    writefln("expected =%-(%s \n%)", expected.map!(a => a.toPretty));
    writefln("results =%-(%s \n%)", results.map!(a => a.toPretty));

    assert(equal(results, expected));
}

ScenarioGroup getScenarioGroup(T)() if (isScenario!T) {
    ScenarioGroup scenario_group;
    // scope(exit) {
    //     result.scenarios~=scenario;
    // }
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach(_Property; UniqueBehaviourProperties) {{
            alias behaviour=getBehaviour!(T, _Property);
            static if (!is(behaviour == void)) {
                import std.uni : toLower;
                auto group = &__traits(getMember, scenario_group, _Property.stringof.toLower);

                group.info.property = getProperty!behaviour;
                group.info.name = __traits(identifier, behaviour);
                static foreach(under_behaviour; getUnderBehaviour!(T, _Property)) {{
                        Info!And and;
                        scope(exit) {
                            group.ands~=and;
                        }
                        and.property = getProperty!(under_behaviour);
                        and.name = __traits(identifier, under_behaviour);
                    }}
            }
        }}
    return scenario_group;
}


//@safe
FeatureGroup getFeature(alias M)() if (isFeature!M) {
    import std.stdio;
    FeatureGroup result;
    result.feature.property = obtainFeature!M;
    result.feature.name = moduleName!M;
    static foreach(_Scenario; Scenarios!M) {{
            ScenarioGroup scenario_group=getScenarioGroup!_Scenario;
            scope(exit) {
                result.scenarios~=scenario_group;
            }
            version(none) {
            scenario.info.property = getScenario!(_Scenario);
            scenario.info.name = _Scenario.stringof;
            static foreach(_Property; UniqueBehaviourProperties) {{
                    alias behaviour=getBehaviour!(_Scenario, _Property);
                    static if (!is(behaviour == void)) {
                        import std.uni : toLower;
                        auto group = &__traits(getMember, scenario, _Property.stringof.toLower);

                        group.info.property = getProperty!behaviour;
                        group.info.name = __traits(identifier, behaviour);
                        static foreach(under_behaviour; getUnderBehaviour!(_Scenario, _Property)) {{
                                Info!And and;
                                scope(exit) {
                                    group.ands~=and;
                                }
                                and.property = getProperty!(under_behaviour);
                                and.name = __traits(identifier, under_behaviour);
                            }}
                    }
                }}
            }
        }}
    return result;
}

unittest { //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;
    alias Module=tagion.behaviour.BehaviourUnittest;
    import std.path;
    enum filename=mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
        .unitfile
        .setExtension("hibon");
    const feature = getFeature!(Module);
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}

@safe
void genBehaviourCode(alias M, Stream)(Stream bout) if(isFeature!M) {

}

unittest {
    import std.outbuffer;
    auto bout=new OutBuffer;
    genBehaviourCode!(tagion.behaviour.BehaviourUnittest)(bout);

    assert(bout.toString == "Not code");
}
