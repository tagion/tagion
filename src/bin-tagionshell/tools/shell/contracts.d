module tagion.tools.shell.contracts;

@safe:

import std.stdio;
import std.path;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile;
import tagion.logger;
import tagion.tools.shell.shelloptions;
import tagion.utils.StdTime;

alias SaveRPC = Msg!"SaveRPC";

/// An 'actor/worker' which saves all incoming RPC contract
struct RPCSaver {

    HashNet net;

    File rpcs_file;

    void save_rpc(SaveRPC, Document doc) {
        rpcs_file.fwrite(doc);
        log.trace("Saved %s", dartIndex(net, doc).encodeBase64);
    }

    void task() {
        net = new StdHashNet();
        const rpcs_file_name = "rpcs_" ~ currentTime.toText.setExtension(FileExtension.hibon);

        rpcs_file = File(rpcs_file_name, "w");

        run(&save_rpc);
    }
}

// Send a message to save the contract
void save_rpc(ShellOptions* opt, lazy Document doc) {
    if (opt.save_rpcs_enable) {
        ActorHandle(opt.save_rpcs_task).send(SaveRPC(), doc);
    }
}
