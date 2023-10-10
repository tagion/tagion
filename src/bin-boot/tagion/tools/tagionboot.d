module tagion.tools.tagionboot;

import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.exception : assumeUnique;
import std.algorithm.iteration : map;
import std.range;
import std.array : array;
import std.bitmanip : nativeToBigEndian;
import tagion.utils.Random;
import stdrnd = std.random;

import tagion.gossip.AddressBook;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.basic.basic : basename;
import tagion.script.prior.StandardRecords;
import tagion.wallet.prior.AccountDetails;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.script.TagionCurrency;
import tagion.wallet.prior.SecureWallet;

//import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.hibon.HiBONRecord : fread, fwrite;
import tagion.dart.DARTBasic;

//import tagion.revision;
import std.array : join;

_Invoice[] invoices;

enum REVNO = 0;
enum HASH = "xxx";

import tagion.tools.Basic;

pragma(msg, "fixme(ib): move to new library when it will be merged from cbr");
void createNetworkNameCard(const HashNet net, string name, RecordFactory.Recorder recorder)
in {
    assert(recorder);
}
do {
    NetworkNameCard nnc;
    nnc.name = name;
    // TODO: set also time?

    NetworkNameRecord nrc;
    nrc.name = DARTIndex(net.dartIndex(nnc));

    NodeAddress na;
    // TODO: init NodeAddress

    // Bind hashes
    nrc.node = DARTIndex(net.dartIndex(na));
    nnc.record = DARTIndex(net.dartIndex(nrc));

    auto hr = HashLock(net, nnc);

    recorder.add(nnc);
    recorder.add(nrc);
    recorder.add(hr);
    recorder.add(na);
}

mixin Main!(_main, "boot");

int _main(string[] args) {
    immutable program = args[0];
    writefln("BOOT ", program);
    const net = new StdHashNet;
    Buffer init_gene() {
        auto rnd = Random!uint(stdrnd.unpredictableSeed);
        return net.rawCalcHash(nativeToBigEndian(rnd.value()));
    }

    bool version_switch;

    string invoicefile;
    string outputfile = "tmp/dart.hibon";
    auto logo = import("logo.txt");
    //    StandardBill bill;
    uint number_of_bills;
    bool initbills = false;
    string nnc_name;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
            "output|o", format("Output filename : Default %s", outputfile), &outputfile, // //        "outputfile|o", format("Sets the output file name: default : %s", outputfilename), &outputfilename,
            //         "bills|b", "Generate bills", &number_of_bills,
            // "value|V", format("Bill value : default: %d", value), &value,
            // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase
            "initbills|b", "Testing mode", &initbills,
            "nnc", "Initialize NetworkNameCard with given name", &nnc_name,
    );

    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    if (main_args.helpWanted) {
        writeln(logo);
        defaultGetoptPrinter(
                [
                format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <invoice-file0> <invoice-file1>...", program),
                "",
                "Where:",
                format("<file>           hibon outfile (Default %s)", outputfile),
                "",

                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }
    //writefln("args=%s", args);

    // if ( args.length > 2) {
    //     stderr.writefln("Only one output file name allowed (given %s)", args[1..$]);
    // }
    // else if (args.length > 1) {
    //     outputfilename=args[1];
    // }
    writefln("args=%s", args);
    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;

    void addGenesisEpoch(RecordFactory.Recorder recorder) {
        import tagion.dart.DARTFile : hash_null;

        EpochBlock block;
        block.previous = hash_null;

        auto top_record = LastEpochRecord(net, block);

        recorder.add(block);
        recorder.add(top_record);
    }

    addGenesisEpoch(recorder);

    const onehot = initbills + (!nnc_name.empty);

    if (onehot > 1) {
        stderr.writeln("Only one of the --stdrecords and --initbills switches alowed");
        return 1;
    }

    if (!nnc_name.empty) {
        writeln("TEST MODE: Initialize standart records");
        createNetworkNameCard(net, nnc_name, recorder);
    }
    else if (initbills) {
        writeln("TEST MODE: Initialize dummy bills");
        alias StdSecureWallet = SecureWallet!StdSecureNet;

        auto bill_amounts = [4, 1, 100, 40, 956, 42, 354, 7, 102355].map!(a => a.TGN).array;

        const label = "some_name";
        foreach (amount; bill_amounts) {
            const invoice = StdSecureWallet.createInvoice(label, amount);
            const bill = StandardBill(invoice.amount, 0, invoice.pkey, init_gene);

            // Add the bill to the DART recorder
            recorder.add(bill);
        }
    }
    else {
        foreach (file; args[1 .. $]) {
            if (!file.exists) {
                writefln("Error: File %s does not exists", file);
                return 3;
            }
            const invoice_doc = file.fread;
            if (!invoice_doc.isInorder) {
                writefln("_Invoice file %s is not a HiBON file", file);
                return 1;
            }

            const invoice = _Invoice(invoice_doc);

            const bill = StandardBill(invoice.amount, 0, invoice.pkey, init_gene);

            // Add the bill to the DART recorder
            recorder.add(bill);
        }
    }

    if (recorder.empty) {
        writefln("Error: Nothing has been added to the recorder");
    }

    outputfile.fwrite(recorder);
    writefln("Recorder has been written to file '%s'", outputfile);
    return 0;
}
