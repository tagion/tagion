/// Tagion DART synchronization service
module tagion.services.DARTSync;
import tagion.utils.JSONCommon;

import tagion.services.options : NetworkMode, TaskNames;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.actor;
import tagion.services.messages;

@safe:

struct SyncOptions {
    mixin JSONCommon;
}

import tagion.dart.synchronizer;


version(none)
struct SyncService {
    void task(immutable(SyncOptions) opts,
            immutable(NetworkMode) network_mode,
            shared(StdSecureNet) shared_net,
            immutable(TaskNames) task_names) {

        const net = new StdSecureNet(shared_net);
        ActorHandle dart_handle = ActorHandle(task_names.dart);

        assert(network_mode == NetworkMode.INTERNAL, "mode0 only supported"); 
    
        auto hirpc = HiRPC(net);

        void init_query(immutable Rims params) {
            // get query branch from dart.

            dart_handle.send(SyncBranchQueryRR(), params);
        
            // const local_branches = branches(params.path);
            // const request_branches = CRUD.dartRim(rims : params, hirpc: hirpc, id: id);
        }

        void query(BranchQueryRR.Response, immutable(Branches) branches) {

            const request_branches = dartRim(rims : params, hirpc: hirpc);
            // send request branches to remote node here. Expect to call receive_query_response
        }

        void receive_query_response(SyncQueryRR.Response, HiRPC.Receiver receiver) {

            if (receiver.isError) {
                return;
            }

            if (Branches.isRecord(receiver.response.result)) {
                // we have a branch and need to search deeper!
                const foreign_branches = receiver.result!Branches;

                const query_req = dartRead(foreign_branches.dart_indices, hirpc);
                // send request to remote node here.  
            }

            if (receiver.isRecord!(RecordFactory.Recorder)) {
                // we received a recorder


            }







        }


        run(&init_query, &query);

    }




}



