module tagion.behaviour.BehaviourReporter;

import tagion.behaviour.BehaviourFeature : FeatureGroup;

@safe
synchronized
interface BehaviourReporter {
    const(Exception) before(scope const(FeatureGroup*) feature_group) nothrow;
    const(Exception) after(scope const(FeatureGroup*) feature_group) nothrow;
}

static shared(BehaviourReporter) reporter;
