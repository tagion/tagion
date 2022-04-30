module tagion.tools.tagionboot;

import std.getopt;
import std.stdio;
import std.file : exists;
import std.format;
import std.exception : assumeUnique;
import std.algorithm.iteration : map;
import std.range : iota;
import std.array : array;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.script.StandardRecords : Invoice;
import tagion.script.TagionCurrency;
import tagion.wallet.SecureWallet;

//import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.hibon.HiBONRecord : fread, fwrite;

//import tagion.revision;
import std.array : join;

Invoice[] invoices;

enum REVNO = 0;
enum HASH = "xxx";

import tagion.tools.Basic;

mixin Main!(_main, "boot");

int _main(string[] args) {
    immutable program = args[0];
    writefln("BOOT ", program);
    immutable initial_gene = iota(256 / 8).map!(i => immutable(ubyte)(0b10101010)).array;
    bool version_switch;

    string invoicefile;
    string outputfile = "tmp/dart.hibon";
    //    StandardBill bill;
    uint number_of_bills;
    bool initbills = false;
    bool stdrecords = false;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
            "output|o", format("Output filename : Default %s", outputfile), &outputfile, // //        "outputfile|o", format("Sets the output file name: default : %s", outputfilename), &outputfilename,
            //         "bills|b", "Generate bills", &number_of_bills,
            // "value|V", format("Bill value : default: %d", value), &value,
            // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase
            "initbills|b", "Testing mode", &initbills,
            "stdrecords|s", &stdrecords,
    );

    if (version_switch) {
        writefln("version %s", REVNO);
        writefln("Git handle %s", HASH);
        return 0;
    }

    if (main_args.helpWanted) {
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
    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;

    const onehot = stdrecords + initbills;

    if (onehot > 1) {
        stderr.writeln("Only one of the --stdrecords and --initbills switches alowed");
        return 1;
    }

    if (stdrecords) {
        writeln("TEST MODE:\nInitialize standart records");

        NetworkNameCard nnc1;
        nnc1.name = "some_random_string";

        NetworkNameRecord nrc1;
        nrc1.name = net.hashOf(nnc1.toDoc);
        nnc1.record = net.hashOf(nrc1.toDoc);
        
        recorder.add(nnc1);
        recorder.add(nrc1);
    }
    else if (initbills) {
        writeln("TEST MODE:\nInitialize dummy bills");
        import tagion.crypto.SecureNet;
        alias StdSecureWallet = SecureWallet!StdSecureNet;
    
        auto bill_amounts = [4, 1, 100, 40, 956, 42, 354, 7, 102355].map!(a => a.TGN);
        
        const label = "some_name";
        foreach (amount; bill_amounts) {
            const invoice = StdSecureWallet.createInvoice(label, amount);
            const bill = StandardBill(invoice.amount, 0, invoice.pkey, initial_gene);
            
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
                writefln("Invoice file %s is not a HiBON file", file);
                return 1;
            }

            const invoice = Invoice(invoice_doc);

            const bill = StandardBill(invoice.amount, 0, invoice.pkey, initial_gene);

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
