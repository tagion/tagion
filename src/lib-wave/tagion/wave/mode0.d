/** 
 * Utilitty function for spawning neuewelle in mode0
**/
module tagion.wave.mode0;

@safe:

import std.array;
import std.file;
import std.algorithm;
import std.stdio;
import std.format;
import std.path;
import std.range;
import std.sumtype;

import tagion.actor;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.services.options;
import tagion.services.supervisor;
import tagion.script.common : Epoch, GenesisEpoch, GenericEpoch;
import tagion.script.namerecords;
import tagion.utils.Term;
import tagion.tools.Basic;
import tagion.gossip.AddressBook;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.wave.common;

// Checks if all nodes bullseyes are the same
bool isMode0BullseyeSame(const(Options[]) node_options, SecureNet __net) {
    import std.typecons;

    // extra check for mode0
    // Check bullseyes
    Fingerprint[] bullseyes;
    foreach (node_opt; node_options) {
        Exception dart_exception;
        DART db = new DART(__net, node_opt.dart.dart_path, dart_exception, Yes.read_only);
        if (dart_exception !is null) {
            throw dart_exception;
        }
        scope (exit) {
            db.close();
        }
        auto b = Fingerprint(db.bullseye);
        if (dart_exception !is null) {
            throw dart_exception;
        }
        bullseyes ~= b;

    }
    // check that all bullseyes are the same before boot
    return bullseyes.all!(b => b == bullseyes[0]);
}

// Return: A range of options prefixed with the node number
const(Options)[] getMode0Options(const(Options) options) {
    const number_of_nodes = options.wave.number_of_nodes;
    const prefix_f = options.wave.prefix_format;
    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(options);
        opt.setPrefix(format(prefix_f, node_n));
        all_opts ~= opt;
    }

    return all_opts;
}

Node[] dummy_nodestruct_for_testing(const(Options[]) node_options) {
    Node[] nodes;
    scope nets = dummy_nodenets_for_testing(node_options);
    foreach (i, opts; node_options) {
        auto net = nets[i];
        scope (exit) {
            net = null;
        }
        shared shared_net = (() @trusted => cast(shared) net)();
        nodes ~= Node(opts, shared_net);
    }
    return nodes;
}

StdSecureNet[] dummy_nodenets_for_testing(const(Options[]) node_options) {
    StdSecureNet[] nets;
    foreach (i, opts; node_options) {
        auto net = new StdSecureNet;
        scope (exit) {
            net = null;
        }
        net.generateKeyPair(opts.task_names.supervisor);
        nets ~= net;
    }
    return nets;
}

struct Node {
    immutable(Options) opts;
    shared(StdSecureNet) net;
    Pubkey pkey;
}

void spawnMode0(
        ref ActorHandle[] supervisor_handles,
        Node[] nodes) {

    /// spawn the nodes
    foreach (ref n; nodes) {
        verbose("spawning supervisor ", n.opts.task_names.supervisor);
        supervisor_handles ~= spawn!Supervisor(n.opts.task_names.supervisor, n.opts, n.net);
    }
}
