module tagion.behaviour.BehaviourReporter;

import tagion.behaviour.BehaviourFeature : FeatureGroup;

@safe
synchronized
interface Reporter {
    void before(scope const(FeatureGroup*) feature_group) nothrow;
    void after(scope const(FeatureGroup*) feature_group) nothrow;
}

static shared(Reporter) reporter;
