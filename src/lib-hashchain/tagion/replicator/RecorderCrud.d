module tagion.replicator.RecorderCrud;

import tagion.communication.HiRPC;
import tagion.hibon.HiBON : HiBON;
import tagion.script.standardnames;

@safe:

/**
* Constructs a HiRPC method for the dartBullseye 
* Params:
*   epoch_number
*   hirpc = HiRPC credentials
*   id = HiRPC id
* Returns: 
*   HiRPC sender
*/
const(HiRPC.Sender) readRecorder( // replicatorRead
    HiRPC hirpc,
    long epoch_number,
    uint id = 0) {
    
    auto params = new HiBON;
    params[StdNames.epoch_number] = epoch_number;
    return hirpc.action("readRecorder", params, id);
}
