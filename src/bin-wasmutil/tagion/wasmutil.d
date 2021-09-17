import std.getopt;
import std.stdio;
import std.file: fread = read, fwrite = write, exists;
import std.format;
import std.path : extension;
import std.traits : EnumMembers;
import std.exception : assumeUnique;
import std.json;
import std.string: isNumeric;
import std.conv;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.hibon.HiBONJSON;
import tagion.wasm.Wast;
import tagion.wasm.WasmReader;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmGas;
//import tagion.script.StandardRecords;
import std.array : join;
import tagion.wasm.WasmParser;


import std.traits : isIntegral, isFloatingPoint, EnumMembers, hasMember, Unqual,
    TemplateArgsOf, PointerTarget, getUDAs, hasUDA, isPointer, ConstOf, ForeachType;
// import tagion.vm.wasm.revision;

enum fileextensions {
    wasm = ".wasm",
    wo   = ".wo",
    wast = ".wast",

    json  = ".json"
};

enum TokenState {
    START,
    MODULE,
    FUNCS,
    PARAMS,
    RETURNS,
    CODE,
    NONE
}

alias LimitReader = WasmReader.Limit;
alias Limit = WasmWriter.WasmSection.Limit;
alias SectionT = WasmWriter.WasmSection.SectionT;
alias Custom = WasmWriter.WasmSection.Custom; // 7.4 may be ignored by an implementation.
alias CustomList = WasmWriter.WasmSection.CustomList; // same
alias FuncType = WasmWriter.WasmSection.FuncType;
alias ImportType = WasmWriter.WasmSection.ImportType;
alias TableType = WasmWriter.WasmSection.TableType;
alias MemoryType = WasmWriter.WasmSection.MemoryType;
alias GlobalType = WasmWriter.WasmSection.GlobalType;
alias ExportType = WasmWriter.WasmSection.ExportType;
alias Start = WasmWriter.WasmSection.Start;
alias ElementType = WasmWriter.WasmSection.ElementType;
alias codeType = WasmWriter.WasmSection.CodeType;
alias DataType = WasmWriter.WasmSection.DataType;

Types getType(string s) {
    switch(s) {
        case("i32"):
            return Types.I32;
        case("i64"):
            return Types.I64;
        case("f32"):
            return Types.F32;
        case("f64"):
            return Types.F64;
        default:
            writeln("Unsupported symbol");
            assert(0);
    }
}


// @safe class WasmCompilerExpection : WasmException {
//     const Token token;
//     this(string msg, const Token token=Token.init,  string file = __FILE__, size_t line = __LINE__) pure nothrow {
//         super(msg, file, line);
//         this.token = token;
//     }
// }

// alias check = Check!WasmCompilerException;

void compile(ref Tokenizer tokenizer) {
    
    uint lvl = 0;
    // 
    
    writeln("START");
    auto range = tokenizer[];

    void parseModule(ref Tokenizer.Range range) {
        FuncType[] func_types;
        ExportType[] exp_types;
        ImportType[] imp_types;
        TableType[] tab_types;

        uint[string] index_func;
        uint[string] index_table;
        uint[string] index_memory;
        uint[string] index_global;

        uint count_tabs;

        ImportType parseImport(ref Tokenizer.Range range, ref ImportType[] imp_types) 
        in {
            assert(range.front.symbol == "import");
        }
        do {
            ImportType imp_type;
            imp_type.mod = range.front.symbol;
            range.popFront;

            imp_type.name = range.front.symbol;
            range.popFront;
           
            //check(range.front.symbol == ")", "Symbol should be -> )");

            range.popFront; // del "("
            const s = range.front.symbol;
            range.popFront;
            switch(s) {
                case "func":
                    ImportType.ReaderImportDesc.FuncDesc func_desc;
                    if(isNumeric(range.front.symbol)){
                        func_desc.funcidx = to!int(range.front.symbol);
                    } 
                    else {
                        func_desc.funcidx = index_func[range.front.symbol];
                    }
                    range.popFront;
                    const fun_d = ImportType.ImportDesc.FuncDesc(func_desc);
                    const imp_desc = ImportType.ImportDesc(fun_d);
                    imp_type.importdesc = imp_desc;
                    imp_types ~= imp_type;  
                    
                    while(range.front.symbol != ")") range.popFront;
                    range.popFront;
                    
                    return imp_type;
                
                case("table"):
                    ImportType.ReaderImportDesc.TableDesc table_desc;

                    const min_ = to!int(range.front.symbol);
                    int max_;
                    range.popFront;
                    
                    if(isNumeric(range.front.symbol)) {
                        max_ = to!int(range.front.symbol);
                        range.popFront;
                        LimitReader lim_range;
                        lim_range.lim = Limits.RANGE;
                        lim_range.from =  min_;
                        lim_range.to = max_;

                        table_desc.limit = lim_range;
                    }
                    else {
                        LimitReader lim_infinite;
                        lim_infinite.lim = Limits.INFINITE;
                        lim_infinite.from = min_;

                        table_desc.limit = lim_infinite;
                    }
                                          
                    const s_type = range.front.symbol;
                    range.popFront;

                    table_desc.type = getType(s_type);

                    auto table_d = ImportType.ImportDesc.TableDesc(table_desc);
                    auto imp_desc = ImportType.ImportDesc(table_d);

                    imp_type.importdesc = imp_desc;
                    imp_types ~= imp_type;
                    
                    if(range.front.symbol == ")") {
                        range.popFront;
                        return imp_type;
                    }
                    else {
                        assert(0, "Current symbol should be -> )");
                    }   

                case("global"):
                    ImportType.ReaderImportDesc.GlobalDesc global_desc;
                    string s_type = range.front.symbol;
                    range.popFront;

                    global_desc.type = getType(s_type);

                    if(range.front.symbol == ")") {
                        global_desc.mut = Mutable.CONST;
                    }
                    else {
                        global_desc.mut = Mutable.VAR;
                    }
                    range.popFront;

                    auto global_d = ImportType.ImportDesc.GlobalDesc(global_desc);
                    auto imp_desc = ImportType.ImportDesc(global_d);
                    
                    imp_type.importdesc = imp_desc;
                    imp_types ~= imp_type;

                    if(range.front.symbol == ")") {
                        range.popFront;
                        return imp_type;
                    }
                    else {
                        assert(0, "Current symbol should be -> )");
                    }   

                    break;

                case("memory"):
                    ImportType.ReaderImportDesc.MemoryDesc memory_desc;
                    uint min_ = to!int(range.front.symbol);
                    uint max_;
                    range.popFront;

                    if(range.front.symbol != ")") {
                        max_ = to!int(range.front.symbol);
                        range.popFront;
                        LimitReader lim_range;
                        lim_range.lim = Limits.RANGE;
                        lim_range.from =  min_;
                        lim_range.to = max_;
                        
                        memory_desc.limit = lim_range;
                    }
                    else {
                        LimitReader lim_infinite;
                        lim_infinite.from = min_;

                        memory_desc.limit = lim_infinite;
                    }

                    auto memory_d = ImportType.ImportDesc.MemoryDesc(memory_desc);
                    auto imp_desc = ImportType.ImportDesc(memory_d);
                    imp_type.importdesc = imp_desc;
                    
                    if(range.front.symbol == ")") {
                        range.popFront;
                        return imp_type;
                    }
                    else {
                        assert(0, "Current symbol should be -> )");
                    }

                default:
                    writeln("Error, current symbol should be one of {func, table, global, memory}");
                    break;
            }
            assert(0);
        }

        ExportType parseExport(ref Tokenizer.Range range, ref ExportType[] exp_types) 
        in {
            assert(range.front.symbol == "export");
        }
        do {
            range.popFront;
            ExportType exp_type;
            exp_type.name = range.front.symbol;
            range.popFront;

            if(range.front.symbol == ")") {
                range.popFront;
                exp_types ~= exp_type;
                return exp_type;    
            }
            else if(range.front.symbol == "(") {
                range.popFront;
                string s_ind_type = range.front.symbol;
                range.popFront;
                switch(s_ind_type) {
                    case "func":
                        exp_type.desc = IndexType.FUNC;
                        range.popFront;

                        if(range.front.symbol !in index_func) {
                            exp_type.idx = to!int(range.front.symbol);
                            range.popFront;
                        }
                        else {
                            exp_type.idx = index_func[range.front.symbol];
                            range.popFront;
                        }    
                        exp_types ~= exp_type; 

                        if(range.front.symbol == ")") {
                            range.popFront;
                            if(range.front.symbol == ")") {
                                range.popFront;
                            }
                            else {
                                assert(0, "Current symbol should be -> )");
                            }
                        }
                        break;
                    
                    case "table":
                        exp_type.desc = IndexType.TABLE;
                        range.popFront;
                        
                        if(range.front.symbol !in index_table) {
                            exp_type.idx = to!int(range.front.symbol);
                            range.popFront;
                        }
                        else {
                            exp_type.idx = index_table[range.front.symbol];
                            range.popFront;
                        }    
                        
                        exp_types ~= exp_type;

                        if(range.front.symbol == ")") {
                            range.popFront;
                            if(range.front.symbol == ")") {
                                range.popFront;
                            }
                            else {
                                assert(0, "Current symbol should be -> )");
                            }
                        }
                        break;
                    
                    case "memory":
                        exp_type.desc = IndexType.MEMORY;
                        range.popFront;
                        
                        if(range.front.symbol !in index_memory) {
                            exp_type.idx = to!int(range.front.symbol);
                            range.popFront;
                        }
                        else {
                            exp_type.idx = index_memory[range.front.symbol];
                            range.popFront;
                        }    
                        
                        exp_types ~= exp_type;

                        if(range.front.symbol == ")") {
                            range.popFront;
                            if(range.front.symbol == ")") {
                                range.popFront;
                            }
                            else {
                                assert(0, "Current symbol should be -> )");
                            }
                        }
                        break;
                    case "global":
                        exp_type.desc = IndexType.GLOBAL;
                        range.popFront;
                        
                        if(range.front.symbol !in index_global) {
                            exp_type.idx = to!int(range.front.symbol);
                            range.popFront;
                        }
                        else {
                            exp_type.idx = index_global[range.front.symbol];
                            range.popFront;
                        }    
                        
                        exp_types ~= exp_type;

                        if(range.front.symbol == ")") {
                            range.popFront;
                            if(range.front.symbol == ")") {
                                range.popFront;
                            }
                            else {
                                assert(0, "Current symbol should be -> )");
                            }
                        }                        
                        break;
                    
                    default:
                        break;
                }
            }
            else {
                assert(0, "Current symbol should be ( or )");
            }
  
            return exp_type;
        }
        
        FuncType parseFunction(ref Tokenizer.Range range, ref FuncType[] func_types) 
        in { 
            assert(range.front.symbol == "func");
        }
            // Types[] params;
            
        do {
            uint[string] param_index;
            uint counter = 0;
            FuncType func_type;
            uint in_lvl = 1;

            range.popFront;
           // bool got_export;
            
            assert(range.front.symbol == "(", "current symbol should be (");
            
            while(in_lvl) {
                const current = range.front;
            
                range.popFront;
                switch(current.symbol) {
                    case("("):
                        in_lvl++;
                        break;

                    case("export"):
                    //check(!got_export, current, "More the one export");
                    //got_export = true;
                        parseExport(range, exp_types);
                        break; // TODO

                    case("param"):
                        string s = range.front.symbol;
                        while(s != "i32" || s != "i64" || s != "f32" || s!= "f64") { 
                            range.popFront; // Use the param_index when it is labeled
                            param_index[s] = counter;
                            counter++;
                        }
                        string s_type = range.front.symbol;
                        func_type.params ~= getType(s_type);
                        break;
                        
                    case("result"):
                        string s_type = range.front.symbol;
                        func_type.results ~= getType(s_type);
                        break;

                    case ("import"):
                        parseImport(range, imp_types);
                        break;

                    case(")"):
                        in_lvl--;
                        break;

                    default:
                        break;
                    //TODO code part        
                }
            }
            func_type.type = Types.FUNC;
            func_types ~= func_type;
            return func_type;
        }

        TableType parseTable(ref Tokenizer.Range range, ref TableType[] table_types)
        in {
            assert(range.front.symbol == "table");
        }           
        do {
            TableType table_type;
            uint min_;
            uint max_;
            range.popFront;
            
            if(!isNumeric(range.front.symbol)) {
                index_table[range.front.symbol] = count_tabs;
                count_tabs ++;
                range.popFront;
            }

            if(isNumeric(range.front.symbol)) {
                Limit lim_;
                min_ = to!int(range.front.symbol);
                lim_.from =  min_;
                range.popFront;

                if(!isNumeric(range.front.symbol)) {
                    lim_.lim = Limits.INFINITE;
                }
                else {
                    lim_.lim = Limits.RANGE;
                    max_ = to!int(range.front.symbol);
                    lim_.to = max_;
                    range.popFront;
                }
                table_type.limit = lim_;
            }
            else {
                assert(0, "Current symbol should be numeric");
            }

            table_type.type = getType(range.front.symbol);
            range.popFront;

            table_types ~= table_type;
            if(range.front.symbol == ")") {
                range.popFront;
            }
            else {
                assert(0, "Current symbol should be -> )");
            }
            return table_type;
        }

        switch(range.front.symbol) {
            case "func":
                parseFunction(range, func_types);
                break;
            case "import":
                parseImport(range, imp_types);
                break;
            case "export":
                parseExport(range, exp_types);
                break;
            case "table":
                parseTable(range, tab_types);
                break;
            default:
                break;
        }

    }


    while (!range.empty) {
        string symbol = range.front.symbol;
        range.popFront;

        switch(symbol) {
            case("("):
                lvl++;
                break;

            case(")"):
                lvl--;
                break;

            case("module"):
                parseModule(range);
                break;
            default:
                break;
        }
    }
    assert(!lvl);
}



int main(){
    writeln("test");
    import std.file : fread = read;
    immutable file_name = "../temp/i32test.wast";
    immutable text = cast(string) file_name.fread;

    Tokenizer tokenizer = Tokenizer(text);

 
    compile(tokenizer);

    
//    Types in type is FyncType
  //  FuncType[]


    return 0;
}
/*
int main(string[] args) {
    pragma(msg, "START");
    immutable program=args[0];
    bool version_switch;

    string inputfilename;
    string outputfilename;
//    StandardBill bill;
    // bool binary;

//    string passphrase="verysecret";
    // ulong value=1000_000_000;
    bool print;
    bool inject_gas;
    bool verbose_switch;
//    WasmVerbose verbose_mode;
    string[] modify_from;
    string[] modify_to;

//    bill.toHiBON;

    //   pragma(msg, "bill_type ", GetLabel!(StandardBill.bill_type));
    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "inputfile|i","Sets the HiBON input file name", &inputfilename,
        "outputfile|o", "Sets the output file name",  &outputfilename,
        // "bin|b", "Use HiBON or else use JSON", &binary,
        // "value|V", format("Bill value : default: %d", value), &value,
        "gas|g", format("Inject gas countes: %s", inject_gas), &inject_gas,
        "verbose|v", format("Verbose %s", verbose_switch), &verbose_switch,
        "mod|m", "Modify import module name from ", &modify_from,
        "to|t", "Modify import module name from ", &modify_to,
        "print|p", format("Print the wasm as wast: %s", print), &print,
        );

    // writefln("%s", modify_from);
    // writefln("%s", modify_to);
    // return 0;
    void help() {
        defaultGetoptPrinter(
            [
                // format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <in-file> <out-file>", program),
                format("%s [<option>...] <in-file>", program),
                "",
                "Where:",
                "<in-file>           Is an input file in .json or .hibon format",
                // "<out-file>          Is an output file in .json or .hibon format",
                "                    stdout is used of the output is not specifed the",
                "",

                "<option>:",

                ].join("\n"),
            main_args.options);
    }

    if (version_switch) {
        // writefln("version %s", REVNO);
        // writefln("Git handle %s", HASH);
        return 0;
    }

    if (verbose_switch && (!print || outputfilename.length is 0)) {
        verbose.mode = VerboseMode.STANDARD;
    }

    if ( main_args.helpWanted ) {
        help;
        return 0;
    }
//    writefln("args=%s", args);
    if ( args.length > 3) {
        stderr.writefln("Only one output file name allowed (given %s)", args[1..$]);
        help;
        pragma(msg, "1");
        return 3;
    }
    if (args.length > 2) {
        outputfilename=args[2];
        pragma(msg, "2");
        writefln("outputfilename%s", outputfilename);
    }
    if (args.length > 1) {
        pragma(msg, "3");
        inputfilename=args[1];
        writefln("inputfilename%s", inputfilename);
    }
    else {
        stderr.writefln("Input file missing");
        help;
        return 1;
    }

    if (modify_from.length !is modify_to.length) {
        stderr.writefln("Modify set must be set in pair");
        stderr.writefln("mod=%s", modify_from);
        stderr.writefln("to=%s", modify_to);
        help;
        return 4;
    }

    immutable standard_output=(outputfilename.length == 0);

    const input_extension=inputfilename.extension;

    WasmReader wasm_reader;
    with (fileextensions) {
        switch (input_extension) {
    case wasm, wo:
        immutable read_data=assumeUnique(cast(ubyte[])fread(inputfilename));
        wasm_reader=WasmReader(read_data);
        verbose.hex(0, read_data);
//        writefln("reader\n%s", read_data);
        break;
        
    // case fileextensions.JSON:
    //     const data=cast(char[])fread(inputfilename);
    //     auto parse=data.parseJSON;
    //     auto hibon=parse.toHiBON;
    //     if (standard_output) {
    //         write(hibon.serialize);
    //     }
    //     else {
    //         outputfilename.fwrite(hibon.serialize);
    //     }
    //     break;
        
    default:
        stderr.writefln("File extensions %s not valid for input file (only %s)",
            input_extension, [EnumMembers!fileextensions]);
    }
    }
    // Wast(wasm_reader, stdout).serialize();
    // return 0;

    WasmWriter wasm_writer=WasmWriter(wasm_reader);


    // writeln("writer");
    // foreach(i, d; wasm_writer.serialize) {
    //     writef("%d ", d);
    //     if (i % 20 == 0) {
    //         writeln();
    //     }
    // }
    // writefln("writer\n%s", wasm_writer.serialize);
    // return 0;
    if (modify_from) {
    }
    if (inject_gas) {
        auto wasmgas=WasmGas(wasm_writer);
        wasmgas.modify;
//        auto wasm_writer=WasmWriter(wasm_reader);
    }
    version(none)
    static foreach(E; EnumMembers!Section) {
        static if (E !is Section.CUSTOM && E !is Section.START) {
            {
                auto sec=wasm_writer.mod[E];
                if (sec !is null) {
                    writefln("\n\n%s=%s", E, sec);
                    foreach(i, s; sec.sectypes[]) {
                        writefln("%d s=%s", i, s);
                        import std.outbuffer;
                        auto bout=new OutBuffer;
                        s.serialize(bout);
                        writefln(" %s\n", bout.toBytes);
                    }
                }
            }
        }
    }

    immutable data_out=wasm_writer.serialize;

    if (verbose_switch) {
        verbose.mode = VerboseMode.STANDARD;
    }

    if (print) {
        writefln("data_out=%s", data_out);
        // writefln("wasm_writer=%s", wasm_writer.serialize);
//        Wast(WasmReader(data_out), stdout).serialize();
        Wast(wasm_reader, stdout).serialize();
        verbose.mode = VerboseMode.NONE;
    }

    if (outputfilename) {
        const output_extension=outputfilename.extension;
        switch (output_extension) {
        case fileextensions.wasm:
            // auto fout=File(outputfilename, "w");
            // scope(exit) {
            //     fout.close;
            // }
            // fout.write(data_out);
            outputfilename.fwrite(data_out);
            // immutable read_data=assumeUnique(cast(ubyte[])fread(inputfilename));
            // wasm_reader=WasmReader(read_data);
            break;
        case fileextensions.wast:
            auto fout=File(outputfilename, "w");
            scope(exit) {
                fout.close;
            }
//            Wast(WasmReader(data_out), fout).serialize;
            Wast(WasmReader(data_out), fout).serialize;
            break;
        default:
            stderr.writefln("File extensions %s not valid output file (only %s)",
                output_extension, [EnumMembers!fileextensions]);
        }
    }
    return 0;
}
*/