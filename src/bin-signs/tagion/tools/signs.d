// demo tool for signing a chain of events for unicef
module tagion.tools.signs;
import tagion.tools.Basic;
import tagion.tools.revision;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.path : setExtension;
import std.exception : assumeUnique;
import std.format;
import std.array : join;

import tagion.basic.Types : FileExtension, fileExtension;

import tagion.hibon.HiBONRecord;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.script.StandardRecords;
import tagion.utils.StdTime;
import tagion.script.TagionCurrency;
import tagion.hibon.Document;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;

mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    auto logo = import("logo.txt");
    string password;
    bool standard_output;
    bool version_switch;
    string inputfilename;

    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "f|filename", "file to sign", &inputfilename, 
                "p|password", "set the password for the signing", &password,
                "c|stdout", "write the output to stdout", &standard_output,
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

    // if (args.length != 1) {
    //     stderr.writefln("inputfilename not specified!");
    //     return 0;
    // }
    SecureNet net = new StdSecureNet;
    if (password.init) { 
        net.generateKeyPair("very secret"); 
    } else {
        net.generateKeyPair(password);
    }

    if (inputfilename.fileExtension != FileExtension.hibon) {
        stderr.writefln("Error: inputfilename not correct filetype. Must be %s", FileExtension.hibon);
        return 0;
    }
    

    immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
    const doc = Document(data);

    const doc_signed = net.sign(doc);
    


    import tagion.hibon.HiBONJSON : toPretty;
    writefln("%s", doc.toPretty);
    
    
    return 0;

}




@recordType("DeliveryOrder")
struct DeliveryOrder {
    string vaccineType; // Vaccine Type - "Measels"
    string packageID; // Package id - "1234ABC"
    int numberOfVaccines; // Number of vaccines - 20
    string destination; // Final destination - "Livingstone"
    string pickuppoint; // Pickup point location - "copenhagen"
    TagionCurrency payment; // Payment - "20usd"

    sdt_t startTime; // standard time
    sdt_t endTime; // end time - should be delivered before this point    
    sdt_t timeStamp; // When the delivery order was created
     
    @label(OwnerKey) Pubkey originalOwner; // the owner of the delivery order
    Pubkey receiver; // The receiver of the vaccines
    mixin HiBONRecord;
}

@recordType("SignedDeliveryOrder")
struct SignedDeliveryOrder {
    Signature deliveryOrderChain; // signature ex. from unicef
    Buffer deliveryOrder;
    sdt_t timeStamp;
    @label(OwnerKey) Pubkey tokenOwner; // owner of the vaccines
    
    mixin HiBONRecord;
}

