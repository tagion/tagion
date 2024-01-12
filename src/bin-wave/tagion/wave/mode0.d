/** 
 * Utilitty function for spawning neuewelle in mode0
**/
module tagion.wave.mode0;

import std.array;
import std.file;
import std.algorithm;
import std.stdio;
import std.format;
import std.path;
import std.range;

import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.services.options;
import tagion.services.supervisor;
import tagion.utils.Term;
import tagion.tools.Basic;
import tagion.gossip.AddressBook;
import std.range : zip;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.script.common : Epoch, GenesisEpoch;
import tagion.actor;

// Checks if all nodes bullseyes are the same
bool isMode0BullseyeSame(const(Options[]) node_options, SecureNet __net) {
    import std.typecons;

    // extra check for mode0
    // Check bullseyes
    Fingerprint[] bullseyes;
    foreach (node_opt; node_options) {
        if (!node_opt.dart.dart_path.exists) {
            stderr.writefln("Missing dartfile %s", node_opt.dart.dart_path);
            return false;
        }
        Exception dart_exception;
        DART db = new DART(__net, node_opt.dart.dart_path, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            throw dart_exception;
        }
        scope (exit) {
            db.close();
        }
        auto b = Fingerprint(db.bullseye);
        bullseyes ~= b;

    }
    // check that all bullseyes are the same before boot
    return bullseyes.all!(b => b == bullseyes[0]);
}

const(Options)[] getMode0Options(const(Options) options, bool monitor = false) {
    const number_of_nodes = options.wave.number_of_nodes;
    const prefix_f = options.wave.prefix_format;
    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(options);
        opt.setPrefix(format(prefix_f, node_n));
        all_opts ~= opt;
    }

    if (monitor) {
        all_opts[0].monitor.enable = true;
    }

    return all_opts;
}

struct Node {
    immutable(Options) opts;
    shared(StdSecureNet) net;
    Pubkey pkey;
}

void spawnMode0(
        const(Options)[] node_options,
        ref ActorHandle[] supervisor_handles,
        Node[] nodes,
        Document epoch_head = Document.init) {

    if (epoch_head is Document.init) {
        foreach (n; zip(nodes, node_options)) {
            addressbook[n[0].pkey] = NodeAddress(n[1].task_names.epoch_creator);
        }
    }
    else {
        Pubkey[] keys;
        if (epoch_head.isRecord!Epoch) {
            assert(0, "not supported to boot from epoch yet");
            keys = Epoch(epoch_head).active;
        }
        else {
            auto genesis = GenesisEpoch(epoch_head);

            keys = genesis.nodes;
            check(equal(keys, keys.uniq), "Duplicate node public keys in the genesis epoch");
            check(keys.length == node_options.length, "There was not the same amount of configured nodes as in the genesis epoch");
        }

        foreach (node_info; zip(keys, node_options)) {
            verbose("adding addressbook ", node_info[0]);
            addressbook[node_info[0]] = NodeAddress(node_info[1].task_names.epoch_creator);
        }
    }

    /// spawn the nodes
    foreach (n; nodes) {
        verbose("spawning supervisor ", n.opts.task_names.supervisor);
        supervisor_handles ~= spawn!Supervisor(n.opts.task_names.supervisor, n.opts, n.net);
    }
}
