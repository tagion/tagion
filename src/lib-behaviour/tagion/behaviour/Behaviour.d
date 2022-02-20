module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourBase;

version(unittest) {
    public import tagion.behaviour.BehaviourUnittest;
}
/**
   Returns:
   true if all the behavios has been runned
 */
bool behaviour(T)(T test) if (isScenario!T) {

    return false;
}

unittest {
    auto awesome = new Some_awesome_feature;
    assert(behaviour(awesome));
}
