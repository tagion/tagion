module tagion.behaviour.BehaviourEnvironment;

import std.process;
import std.traits : FieldNameTuple;
import std.algorithm.iteration : map;
import std.uni : toUpper;
import std.array : array;

import tagion.basic.Basic : EnumText;

import tagion.behaviour.BehaviourFeature : FeatureGroup;

@safe
struct BehaviourEnvironment
{
    string bdd_log; /// path to the root of the bdd log files (BDD_LOG)
}

/// Defines all the Environment names
mixin(EnumText!("ENV", [FieldNameTuple!BehaviourEnvironment]
.map!(name => name.toUpper).array));

pragma(msg, ENV);

package static shared(BehaviourEnvironment) _bdd_env;

/// The BDD environment informations
@trusted
immutable(BehaviourEnvironment*) env() nothrow @nogc
{
    return cast(immutable) &_bdd_env;
}

shared static this()
{
    _bdd_env.bdd_log = environment.get(ENV.BDD_LOG, null);
}

