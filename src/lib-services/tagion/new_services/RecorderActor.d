/// Handles the recorder backup and redo/undo.  
module tagion.new_services.RecorderActor;

import tagion.utils.JSONCommon;
import tagion.actor.Actor;
import tagion.dart.Recorder : RecordFactory;

struct RecorderOptions {
    string task_name; /// Name of the recorder task
    string folder_path; /// Folder used for the recorder service files, default empty path means this feature is disabled
    mixin JSONCommon;
}

struct RecoderActor {
    /**
Stores the recoder in the recover list    
*/
    @method void storeRecorder(immutable(RecordFactory.Recorder) recoder);

    /**
Request a Recorder and sends it back to
*/
    @method void requestRecover(immutable(ActorChannel) channel);

    @task void run(
            immutable(RecorderOptions) rec_opt);

    mixin TaskActor;
}
