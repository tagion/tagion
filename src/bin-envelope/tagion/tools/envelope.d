/// Envelope CLI tool
module tagion.tools.envelope;

import core.time;
import std.array;
import std.datetime;
import std.file;
import std.format;
import std.getopt;
import std.stdio;
import std.range;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.utils.StdTime;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.communication.Envelope;


mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    
    bool version_switch;
    bool info_switch;
    bool pack_switch;
    bool unpack_switch;
    string inputfilename = "";
    string outputfilename = "";
    ulong blocksize = 0;
    int schema = 0;
    uint level = 5;

    ubyte[] buf;
    const bufsz = 8192;
    long totalsz  = 0;
    
    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.bundling,
                "version", "Display the version", &version_switch,
                "verbose|v", "Prints verbose information to console", &__verbose_switch,
                "i|info", "Describe envelope", &info_switch,
                "p|pack", "Force pack buffer to envelope", &pack_switch,
                "u|unpack", "Force unpack envelope", &unpack_switch,
                "f|file", "Filename to read from, instead of stdin", &inputfilename,
                "o|out", "Filename to write to, instead of stdout", &outputfilename,
                "b|blocksize", "Chunk size. Default 0 = no chunks.", &blocksize,
                "s|schema", "Envelope schema version", &schema,
                "c|compress", "Compression level: 0..9", &level,
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
                "Where:",
                "",

                "<option>:",

            ].join("\n"),
                    main_args.options);
            return 0;
        }

        if(pack_switch && unpack_switch){
            stderr.writeln("Couldn`t pack and unpack. Choose one.");
            return 1;
        }        
      
        
        auto infile  = (inputfilename.length > 0)  ? File(inputfilename, "rb")  : stdin;
        auto outfile = (outputfilename.length > 0) ? File(outputfilename, "wb") : stdout;
        
        foreach (ubyte[] sup; infile.byChunk(new ubyte[bufsz])){
            if(sup.empty())
                break;
            buf ~= sup;
            totalsz += sup.length;
            if(!pack_switch && !unpack_switch){
                auto e = Envelope(buf);
                if(!e.errorstate && e.header.isValid())
                    unpack_switch = true;
                pack_switch = !unpack_switch;                
            }
            if(pack_switch){
                if(blocksize > 0 && buf.length >= blocksize){
                    auto e = Envelope(schema, level, buf);
                    outfile.rawWrite(e.toBuffer());
                    buf = [];
                }            
            } else {
                auto e = Envelope(buf);
                if(e.errorstate || !e.header.isValid()){
                    //stderr.writefln("Invalid envelope: " ~ join(e.errors, " "));
                    continue;
                }
                buf = e.tail;
                if(info_switch){
                    outfile.write(e.header.toString());
                    continue;
                }
                outfile.rawWrite(e.toData());
            }
        }

        if(pack_switch && buf.length > 0){
                auto e = Envelope(schema, level, buf);
                outfile.rawWrite(e.toBuffer());
        }            

    }
    catch (Exception e) {
        error(e);
        return 1;
    }
    return 0;
}
