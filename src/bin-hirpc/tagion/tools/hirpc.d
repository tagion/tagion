/// HiRPC utility for generating HiRPC requests
@description("Create and inspect HiBON RPCs") module tagion.tools.hirpc;

import tagion.tools.Basic;
import tagion.tools.revision;
import tools = tagion.tools.toolsexception;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.dart.DARTBasic;
import tagion.tools.dartutil.dartindex;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.hibon.Document;
import tagion.script.standardnames;
import tagion.script.methods;
import tagion.script.common;
import tagion.hibon.HiBONtoText : decode;
import tagion.hibon.HiBONFile;
import tagion.basic.Debug;
import tagion.basic.basic : isinit;
import tagion.communication.HiRPC;
import std.range;
import std.conv;
import std.path;
import std.stdio;
import std.getopt;
import std.format;
import std.array;
import std.algorithm;
import std.string;
import std.typecons;

@safe
void strip_hirpc(const(HiRPC) hirpc, File fout, const(Document) doc, const bool info) {
    const error_code = doc.valid(reserved: No.Reserved);
    tools.check(error_code.isinit, format("HiRPC is not a valid document %s", error_code));
    const receiver = hirpc.receive(doc);
    if (receiver.isMethod) {
        if (info) {
            fout.writefln("Method %s", receiver.method.full_name);
            fout.writefln("id     %d", receiver.getId);
            fout.writefln("Signed %s", receiver.signed);
            return;
        }
        fout.fwrite(receiver.method.params);
        return;
    }
    if (receiver.isResponse) {
        if (info) {
            fout.writeln("Receiver");
            fout.writefln("Id     %d", receiver.getId);
            fout.writefln("Signed %s", receiver.isSigned);
            return;
        }
        fout.fwrite(receiver.result);
        return;
    }
    if (receiver.isError) {
        if (info) {
            fout.writeln("Error");
            fout.writefln("Id     %d", receiver.getId);
            fout.writefln("Signed %s", receiver.isSigned);
            fout.writefln("Code   %d", receiver.error.code);
            fout.writefln("Data   size=%d", receiver.error.data.size);
            return;
        }
        fout.fwrite(receiver.error);
        return;
    }

}

static immutable IMPLEMENTED_METHODS = [
    Queries.dartRead,
    Queries.dartCheckRead,
    Queries.dartBullseye,
];

mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool response_switch;
    bool result_switch;
    string output_filename;
    string method_name;
    string[] dartindices;
    string[] params;
    string send_address;
    const name = () => method_name.splitter('.').retro.front;
    const domain = () => method_name.split('.').dropBack(1).join('.');
    try {
        File fin = stdin;
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "o|output", "Output filename (Default stdout)", &output_filename,
                "m|method", "method name for the hirpc to generate", &method_name,
                "r|dartindex", "dartindex inputs sep. by comma or multiple args for multiples generated differently for each cmd", &dartindices,
                "A|response", "Analyzer a HiRPC response", &response_switch,
                "R|result", "Dumps the result of HiRPC response", &result_switch,
                "p|params", "Method parameters", &params,
                "s|send", "Send the hirpc to the address", &send_address,
        );

        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                "Documentation: https://docs.tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "<option>:",

            ].join("\n"),
                    main_args.options);
            writeln();
            examplesPrinter(program, [
                ToolExample("Create a dartBullseye request and save it to a file",
                        "-m dartBullseye -o bullseye_request.hibon"),
            ]);

            if (!method_name.empty) {
                writeln();
            }
            return 0;
        }

        File fout = stdout;
        if (!output_filename.isinit) {
            fout = stdout;
            tools.check(output_filename.hasExtension(FileExtension.hibon),
                    format("Output %s should be a .%s file", output_filename, FileExtension.hibon));
            fout = File(output_filename, "w");
        }

        if (response_switch || result_switch) {
            const net = createSecureNet;
            const hirpc = HiRPC(net);
            auto inputfiles = args[1 .. $].filter!(file => file.hasExtension(FileExtension.hibon));
            verbose("inputfile %s", inputfiles);

            if (!inputfiles.empty) {
                inputfiles.each!(file => strip_hirpc(hirpc, fout, file.fread, response_switch));
                return 0;
            }
            auto hrange = HiBONRange(fin);
            hrange.each!(doc => strip_hirpc(hirpc, fout, doc, response_switch));
            return 0;
        }
        const hirpc = HiRPC(null);
        tools.check(!method_name.empty && all_public_methods.canFind(name()), format(
                "method name not valid must be one of known %s", all_public_methods));

        auto get_indices(string[] _input) {
            return _input.map!(d => hash_net.dartIndexDecode(d));
        }

        auto get_pkey_indices(string[] _pkeys) {
            return _pkeys.map!(p => hash_net.dartId(HashNames.trt_owner, Pubkey(p.decode)));
        }

        Document result;
        switch (name()) {
        case RPCMethods.dartBullseye:
            result = dartBullseye(hirpc.relabel(domain())).toDoc;
            break;
        case RPCMethods.dartRead, RPCMethods.dartCheckRead:
            tools.check(!dartindices.empty || !params.empty, "must supply params or dartindices");

            auto res = (false)
                ? get_pkey_indices(params).array
                : get_indices(params).array;

            result = dartIndexCmd(name(), res, hirpc.relabel(domain())).toDoc;
            break;
        case RPCMethods.dartModify:
            import tagion.dart.Recorder;
            tools.check(args.length == 2, format("Expected one hibon input Not %s", args[1 .. $]));
            Document doc = fread(args[1]);
            auto factory = RecordFactory(hash_net);
            const recorder = factory.recorder(doc);
            result = dartModify(recorder).toDoc;

            break;
        case RPCMethods.submit:
            tools.check(args.length == 2, format("Expected one hibon input file Not %s", args[1 .. $]));
            Document doc = fread(args[1]);
            const s_contract = SignedContract(doc);
            result = submit(s_contract).toDoc;
            break;
        case RPCMethods.readRecorder:
            tools.check(params.length == 1, "Expected one number input param (eg. -p10)");
            result = readRecorder(params[0].to!long).toDoc;
            break;
        default:
            tools.check(0, format("method %s not implemented use one of %s", method_name, IMPLEMENTED_METHODS));
        }

        if(!send_address.empty) {
            import tagion.network.socket;
            import tagion.network.ReceiveBuffer;
            Socket sock = Socket(send_address);
            sock.connect;
            const to_send = result.serialize;
            ptrdiff_t sent;
            while(sent < to_send.length) {
                sent = sock.send(result.serialize);
                socket_check(sent > 0, "Error when sending");
            }
            ReceiveBuffer receive_buf;
            const result_len = receive_buf(&sock.receive);
            socket_check(result_len > 0, "Error when receiving");
            fout.rawWrite(receive_buf[]);
        }
        else {
            fout.rawWrite(result.serialize);
        }
    }
    catch (Exception e) {
        error(e);
        return 1;

    }

    return 0;
}
