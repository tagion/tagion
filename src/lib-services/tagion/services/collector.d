module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.Recorder : RecordFactory;
import tagion.script.StandardRecords : SignedContract;
import tagion.services.messages;

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    string task_name = "collector_task";
    mixin JSONCommon;
}

@safe
struct CollectorService {
    void task(immutable(CollectorOptions) opts) {

        void signed_contract(inputContract, immutable(SignedContract) contract) {

        }

        void recorder(inputRecorder, immutable(RecordFactory.Recorder) recorder) {
        }

        run(&signed_contract, &recorder);

    }
}
