// demo tool for signing a chain of events for unicef
module tagion.tools.signs;
import tagion.tools.Basic;
import tagion.tools.revision;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.path : setExtension, extension;
import std.exception : assumeUnique;
import std.format;
import std.array : join;

import tagion.basic.Types : FileExtension;

import tagion.hibon.HiBONRecord;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.script.StandardRecords;
import tagion.utils.StdTime;
import tagion.script.TagionCurrency;
import tagion.hibon.Document;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DARTBasic;
import tagion.utils.Miscellaneous : toHexString, decode;

@recordType("DeliveryOrder")
struct DeliveryOrder {
    string vaccineType; // Vaccine Type - "Measels"
    string packageID; // Package id - "1234ABC"
    int numberOfVaccines; // Number of vaccines - 20
    string destination; // Final destination - "Livingstone"
    string pickuppoint; // Pickup point location - "copenhagen"
    // TagionCurrency payment; // Payment - "20usd"
    
    sdt_t startTime; // standard time
    sdt_t endTime; // end time - should be delivered before this point    

    @label(OwnerKey) Pubkey originalOwner; // the owner of the delivery order
    Pubkey finalReceiver; // The receiver of the vaccines
    mixin HiBONRecord!(q{
        this(
            string vaccineType, 
            string packageID, 
            int numberOfVaccines, 
            string destination, 
            string pickuppoint,
            sdt_t startTime,
            sdt_t endTime,
            Pubkey originalOwner,
            Pubkey finalReceiver,
        ) {
            this.vaccineType = vaccineType;
            this.packageID = packageID;
            this.numberOfVaccines = numberOfVaccines;
            this.destination = destination;
            this.pickuppoint = pickuppoint;
            this.startTime = startTime;
            this.endTime = endTime;
            this.originalOwner = originalOwner;
            this.finalReceiver = finalReceiver;
        }
    });
}

@recordType("SignedDeliveryEvent")
struct SignedDeliveryEvent {
    Signature newSignature; // signature ex. from current owner
    DARTIndex deliveryEvent;
    sdt_t timeStamp;
    Pubkey recipient;
    @label(OwnerKey) Pubkey owner; // new token owner
    
    
    mixin HiBONRecord!(q{
        this(
            Signature newSignature, 
            DARTIndex deliveryEvent,
            sdt_t timeStamp,
            Pubkey recipient,
            Pubkey owner) 
        {    
            this.newSignature = newSignature;
            this.deliveryEvent = deliveryEvent;
            this.timeStamp = timeStamp;
            this.recipient = recipient;
            this.owner = owner;
        }   
    });
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
                "Documentation: https://tagion.org/",
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
        writefln("%s", net.pubkey.toHexString);
        return 0;
    }

    if (receiver_pubkey == receiver_pubkey.init) {
        stderr.writefln("Please supply pubkey of next receiver");
        return 1;
    }
    Pubkey receiver = decode(receiver_pubkey);
    
    // if (args.length != 1) {
    //     stderr.writefln("inputfilename not specified!");
    //     return 0;
    // }
    if (generate) {
        writefln("generating dummy delivery order");
        auto delivery_order = DeliveryOrder(
                "Measels",
                "43a3efd",
                100,
                "Copenhagen",
                "Triesen Liechenstein",
                currentTime,
                currentTime,
                net.pubkey,
                receiver,
        );
        if (standard_output) {
            stdout.rawWrite(delivery_order.toDoc.serialize);
            return 0;
        }
        outputfilename.setExtension(FileExtension.hibon).fwrite(delivery_order.toDoc.serialize);
        return 0;

    }
    if (inputfilename.extension != FileExtension.hibon) {
        stderr.writefln("Error: inputfilename not correct filetype. Must be %s", FileExtension.hibon);
        return 1;
    }

    immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
    const doc = Document(data);

    if (!(DeliveryOrder.isRecord(doc) || SignedDeliveryEvent.isRecord(doc))) {
        stderr.writefln("Error: inputfilename not correct type. Must be DeliveryOrder or DeliveryEvent");
        return 1;
    }
    writefln("going to sign the doc!");

    Signature doc_signed = net.sign(doc).signature;
    DARTIndex dart_index = net.dartIndex(doc);

    auto signed_delivery_event = SignedDeliveryEvent(doc_signed, dart_index, currentTime, receiver, net.pubkey);
     
    if (standard_output) {
        stdout.rawWrite(signed_delivery_event.toDoc.serialize);
        return 0;
    }
    outputfilename.setExtension(FileExtension.hibon).fwrite(signed_delivery_event.toDoc.serialize);
    return 0;       
}
