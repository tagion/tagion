module tagion.tools.signs;
import core.time;
import std.array : join;
import std.datetime;
import std.file : exists, readText, fwrite = write;
import std.format;
import std.getopt;
import std.path : extension, setExtension;
import std.stdio;
import tagion.basic.Types : FileExtension;
import tagion.basic.Types;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONFile : fread;
import tagion.hibon.HiBONtoText : decode, encodeBase58;
import tagion.script.TagionCurrency;
import tagion.script.standardnames;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.utils.StdTime;

@recordType("DeliveryOrder") 
struct DeliveryOrder {

    string vaccineType;
    string packageID;
    int numberOfVaccines;
    string destination;
    string pickuppoint;
    string startTime;
    string endTime;
    int payment;
    @label(StdNames.owner) Pubkey owner; // new token owner       
    Pubkey finalReceiver;
    mixin HiBONRecord;
}

@recordType("DeliveryEvent")
struct DeliveryEvent {
    Signature newSignature; // signature ex. from receiver or from sender when receiver has already signed
    DARTIndex deliveryEvent;
    string temp;
    string timeStamp;
    @label(StdNames.owner) Pubkey owner; // new token owner
    mixin HiBONRecord;
}

mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    auto logo = import("logo.txt");
    string password;
    bool standard_output;
    bool version_switch;
    bool generate;
    string inputfilename;
    string outputfilename = "delivery_order.hibon";
    bool generate_pubkey;
    string receiver_pubkey;
    string final_receiver_pubkey;

    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "f|filename", "file to sign", &inputfilename,
                "p|password", "set the password for the signing", &password,
                "c|stdout", "write the output to stdout", &standard_output,
                "g|generate", "generates dummy delivery order", &generate,
                "generate_pubkey", "generates public key to stdout", &generate_pubkey,
                "r|receiver", "give the pubkey for the receiver", &receiver_pubkey,
                "R|finalreceiver", "the final receiver only used for gen delivery order", &final_receiver_pubkey,
                "o|outputfilename", "filename to write to", &outputfilename,
        );
    }
    catch (std.getopt.GetOptException e) {
        writeln(e.msg);
        return 1;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (main_args.helpWanted) {
        writeln(logo);
        defaultGetoptPrinter(
                [
            "Documentation: https://docs.tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] <in-file>", program),
            "",
            "Where:",
            "<in-file>           Is an input file in .json or .hibon format",
            "",

            "<option>:",

        ].join("\n"),
                main_args.options);
        return 0;
    }

    SecureNet net = new StdSecureNet;
    if (password.init) {
        net.generateKeyPair("very secret");
    }
    else {
        net.generateKeyPair(password);
    }

    if (generate_pubkey) {
        auto buf = cast(Buffer) net.pubkey;
        writefln("%s", buf.encodeBase58);
        return 0;
    }

    // if (args.length != 1) {
    //     stderr.writefln("inputfilename not specified!");
    //     return 0;
    // }
    if (generate) {
        writefln("generating delivery order");
        if (final_receiver_pubkey == final_receiver_pubkey.init) {
            stderr.writefln("missing finalreceiver");
            return 1;
        }
        Pubkey final_receiver = decode(final_receiver_pubkey);
        auto startTime = Clock.currTime();
        auto endTime = startTime + 2.days;
        auto delivery_order = DeliveryOrder(
                "Measels",
                "43a3efd0se395",
                200,
                "Livingstone Pharmacy",
                "Lusaka Warehouse",
                startTime.toISOExtString,
                endTime.toISOExtString,
                100,
                net.pubkey,
                final_receiver,
        );
        if (standard_output) {
            stdout.rawWrite(delivery_order.toDoc.serialize);
            return 0;
        }
        writefln("%s", delivery_order.toDoc.toPretty);
        outputfilename.setExtension(FileExtension.hibon).fwrite(delivery_order.toDoc.serialize);
        return 0;

    }

    if (receiver_pubkey == receiver_pubkey.init) {
        stderr.writefln("Please supply pubkey of next receiver");
        return 1;
    }
    Pubkey receiver = decode(receiver_pubkey);

    if (inputfilename.extension != FileExtension.hibon) {
        stderr.writefln("Error: inputfilename not correct filetype. Must be %s", FileExtension.hibon);
        return 1;
    }

    Document doc = fread(inputfilename);

    if (!(DeliveryOrder.isRecord(doc) || DeliveryEvent.isRecord(doc))) {
        stderr.writefln("Error: inputfilename not correct type. Must be DeliveryOrder or DeliveryEvent");
        return 1;
    }
    writefln("going to sign the doc!");

    Signature doc_signed = net.sign(doc).signature;
    DARTIndex dart_index = net.dartIndex(doc);

    auto signed_delivery_event = DeliveryEvent(
            doc_signed,
            dart_index,
            "OK",
            Clock.currTime.toISOExtString,
            receiver, //new token owner

            

    );

    if (standard_output) {
        stdout.rawWrite(signed_delivery_event.toDoc.serialize);
        return 0;
    }
    writefln("%s", signed_delivery_event.toDoc.toPretty);
    outputfilename.setExtension(FileExtension.hibon).fwrite(signed_delivery_event.toDoc.serialize);
    return 0;
}
