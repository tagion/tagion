module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourBase;

import std.traits;
import std.format;
import std.meta : AliasSeq;

version(unittest) {
//    import std.stdio;
    public import tagion.behaviour.BehaviourUnittest;
}

/**
   Returns:
   true if all the behavios has been runned
 */
auto scenario(T)(T test) if (isScenario!T) {
    alias memberCode = format!(q{result &= %s.%s;},string, string);
    bool run(S...)() {
        static if (S.length is 0) {
            return true;
        }
        else {
            alias behaviour = getBehaviour!(T, S[0]);
            bool result=true;
            static foreach(Property; AliasSeq!(Given, Then)) {
                static if (is(S[0] == Property)) {
                static assert(!is(behaviour),
                    format!"%s of the Scenario %s is missing"
                    (Property.stringof, T.stringof));
                }
            }
            static if (!is(behaviour == void)) {
                enum code = memberCode(
                    test.stringof, __traits(identifier, behaviour));
                mixin(code);
                static foreach(under_behaviour; getUnderBehaviour!(T, S[0])) {{
                        enum under_code = memberCode(
                            test.stringof, __traits(identifier, under_behaviour));
                        mixin(under_code);
                    }}
                result &= run!(S[1..$])();
            }
            return result;
        }
    }
    return &run!UniqueBehaviourProperties;
}

unittest {
    auto awesome = new Some_awesome_feature;
    const run_awesome=scenario(awesome);
    assert(!run_awesome());
    assert(awesome.count == 6);
    auto awesome_implemeted = new Some_awesome_feature_all_implemented;
    const run_awesome_implemeted=scenario(awesome_implemeted);
    assert(run_awesome_implemeted());
    assert(awesome_implemeted.count == 6);
}
