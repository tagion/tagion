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

version (none) class HiRPCNet : StdSecureNet {
    this(string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}

Invoice[] invoices;
version (none) HiBON generateBills(Document doc) {
    foreach (d; doc[]) {
        invoices ~= Invoice(d.get!Document);
    }
    enum TGS = "TGS";
    //    enum RECORDTYPE = "BILL";
    HiBON archives = new HiBON;
    foreach (i, I; invoices) {
        StandardBill bill;
        with (bill) {
            bill_type = TGS;
            // type = RECORDTYPE;
            value = I.amount;
            epoch = 0;
            auto pkey = I.pkey;
            owner = pkey; //bill_net.calcHash(bill_net.calcHash(pkey));
        }
        HiBON archive = new HiBON;
        archive[DARTFile.Params.archive] = bill.toHiBON;
        archive[DARTFile.Params.type] = cast(uint)(DARTFile.Recorder.Archive.Type.ADD);
        archives[i] = archive;
    }
    return archives;
}

enum REVNO = 0;
enum HASH = "xxx";
int main(string[] args) {
    immutable program = args[0];
    writefln("BOOT ", program);
    immutable initial_gene = iota(256 / 8).map!(i => immutable(ubyte)(0b10101010)).array;
    bool version_switch;

    string invoicefile;
    string outputfile = "tmp/dart.hibon";
    //    StandardBill bill;
    uint number_of_bills;
    bool test_mode = false;
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
            "output|o", format("Output filename : Default %s", outputfile), &outputfile, // //        "outputfile|o", format("Sets the output file name: default : %s", outputfilename), &outputfilename,
            //         "bills|b", "Generate bills", &number_of_bills,
            // "value|V", format("Bill value : default: %d", value), &value,
            // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase
            "test|t", "Testing mode", &test_mode,
            

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

    if (!test_mode) {
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
    else {
        writeln("TEST MODE");
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

    if (recorder.empty) {
        writefln("Error: Nothing has been added to the recorder");
    }

    outputfile.fwrite(recorder);
    writefln("Recorder has been written to file '%s'", outputfile);
    return 0;
}
