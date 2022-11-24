module tagion.behaviour.BehaviourReporter;

import tagion.behaviour.BehaviourFeature : FeatureGroup;

@safe
synchronized
interface BehaviourReporter {
    void before(scope const(FeatureGroup*) feature_group) nothrow;
    void after(scope const(FeatureGroup*) feature_group) nothrow;
}

static shared(BehaviourReporter) reporter;
