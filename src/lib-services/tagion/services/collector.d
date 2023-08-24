module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.script.StandardRecords;
import tagion.dart.Recorder : RecordFactory;

import tagion.services.messages;

@safe
struct CollectedSignedContract {
    Document[] inputs;
    Document[] reads;
    SignedContract contract;
    //    mixin HiBONRecord;
}

@safe
struct CollectorOptions {
    string task_name = "collector_task";
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
