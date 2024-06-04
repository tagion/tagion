module tagion.tools.hipatch;

import std.getopt;
import std.stdio;
import std.format;
import std.range;
import std.typecons;

import tagion.crypto.Types;
import tagion.tools.Basic;
import tagion.tools.toolsexception;
import tagion.tools.revision;
import tagion.hibon.HiBONFile;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONtoText;
import tagion.hibon.HiBONBase : HiBONType = Type;
import tagion.script.standardnames;

mixin Main!_main;

int _main(string[] args) {
    try {
        return __main(args);
    } catch(Exception e) {
        error(e);
        return 1;
    }
}

int __main(string[] args) {
    immutable program = args[0];
    string pubkey_b64;
    string out_filename;
    bool version_switch;

    auto main_args = getopt(args,
        "version", "display the version", &version_switch,
        "v|verbose", "Prints more debug information", &__verbose_switch,
        "p|pubkey", "The public key to patch", &pubkey_b64,
        "o|output", "Output file", &out_filename,
    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter([
            "Documentation: https://docs.tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] [<hibon-filerange>]", program),
            "",
            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }

    check(!pubkey_b64.empty, "A Public key is required for patching");
    Pubkey pubkey = decode(pubkey_b64);
    /* Pubkey pubkey = new ubyte[](33); */
    check(pubkey.length == 33, "Public key should be 33 bytes");

    File fin = (args.length >= 2)? File(args[1]) : stdin();
    File fout = (out_filename)? File(out_filename, "a") : stdout();

    HiBONRange range = HiBONRange(fin);

    foreach (scope doc; range) {
        if(doc.hasMember(StdNames.owner)) {
            Document.Element owner_elm = doc[StdNames.owner];
            check(owner_elm.dataSize == 33, format("Can not replace element with size of %s", owner_elm.dataSize));

            const valuePos = owner_elm.valuePos;
            const dataPos = valuePos + HiBONType.sizeof;
            cast(ubyte[])(owner_elm.data)[dataPos .. dataPos + 33] = pubkey[0 .. 33];
            assert(doc.isInorder(No.Reserved));
            fout.fwrite(doc);
        }
        else {
            fout.fwrite(doc);
        }
    }

    return 0;
}
