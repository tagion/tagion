module tagion.dart.Recorder;

import std.container.rbtree : RedBlackTree;
import std.range.primitives : isInputRange;
import std.format;

import tagion.crypto.SecureInterface : HashNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : Label, STUB, isHiBONRecord, GetLabel, isStub;
import tagion.basic.Basic : Buffer;
import tagion.Keywords;

import tagion.basic.Message;;
import tagion.dart.DARTException : DARTRecorderException;

import tagion.basic.TagionExceptions : Check;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.BlockFile : BlockFile;
alias Params=DARTFile.Params;
enum INDEX_NULL=BlockFile.INDEX_NULL;
//import tagion.utils.Miscellaneous : toHex=toHexString;

import tagion.utils.Miscellaneous : toHexString;
alias hex=toHexString;

private alias check=Check!DARTRecorderException;

//    alias recorder=factory.recorder;
@safe
struct Factory {


    const HashNet net;
    @disable this();
    protected this(const HashNet net) {
        this.net=net;
    }
    // static Factory opCall(const HashNet net) {
    //     return new Factory(net);
    // }
    /++
     Creates an empty Recorder
     +/
    // Recorder recorder() nothrow {
    //     return new Recorder;
    // }

    /++
     Creates an empty Recorder
     +/
    // Recorder recorder(const(Document) doc) {
    //     return new Recorder(doc);
    // }

    /++
     + Creates a Recorder base on an existing archive list

     + Params:
     +     archives = Archive list
     +/
    // Recorder recorder(Recorder.Archives archives) nothrow  {
    //     return new Recorder(archives);
    // }

    // Recorder recorder(R)(R range) if(isInputRange!R) {
    //     return new Recorder(range);
    // }


    /++
     +  Recorder to recorder (REMOVE, ADD) actions while can be executed by the
     +  modify method
     +/
    @safe
    struct Recorder {
        alias Archives=RedBlackTree!(Archive, (a,b) => a.fingerprint < b.fingerprint);
        private HashNet net;
        //private Archives _archives;
        Archives _archives;
//        @disable this();
//        alias BranchRange=Archives.Range;

        /++
         + Creates a Recorder with an empty archive list
         + Params:
         +     net = Secure net should be the same as define in the DARTFile class
         +/
        private this(HashNet net) pure nothrow
            in {
                assert(net);
            }
        do {
            this.net=net;
            _archives=new Archives;
        }

        /++
         + Creates an Recorder base on an existing archive list

         + Params:
         +     net      = Secure net should be the same as define in the DARTFile class
         +     archives = Archive list
         +/
        private this(HashNet net, Archives archives) pure nothrow
            in {
                assert(net);
            }
        do {
            this.net=net;
            this._archives=archives;
        }

        this(HashNet net, Document doc) {
            this(net);
            foreach(e; doc[]) {
                auto doc_archive=e.get!Document;
                auto archive=new Archive(net, doc_archive);
                _archives.insert(archive);
            }
        }

        @trusted inout(Archives) archives() inout  {
            return _archives;
        }

        void removeOutOfRange(ushort from, ushort to){  //TODO: write unit tests
            if(from == to) return;
            immutable ushort to_origin=(to-from) & ushort.max;
            foreach(archive; archives){
                if(archive.type != Archive.Type.REMOVE){
                    short archiveSector = archive.fingerprint[0] | archive.fingerprint[1];
                    // writeln("CHECK STUBS: arcive fp:%s sector: %d", archive.fingerprint, archiveSector);
                    ushort sector_origin=(archiveSector-from) & ushort.max;
                    if( sector_origin >= to_origin ){
                        archives.removeKey(archive);
                    }
                }
            }
        }

        size_t length() pure const nothrow {
            return _archives.length;
        }

        bool empty() pure const nothrow {
            return _archives.length == 0;
        }

        /+
         + Finds an archive with the fingerprint
         +
         + Returns:
         +     The archive @ fingerprint and if it dosn't exists then a null reference is returned
         +/
        Archive find(immutable(Buffer) fingerprint)
            in {
                assert(fingerprint);
            }
        do {
            if ( _archives ) {
                scope archive=new Archive(fingerprint);
                scope range=_archives.equalRange(archive);
                if ( (!range.empty) && ( archive.fingerprint == range.front.fingerprint ) ) {
                    return range.front;
                }
            }
            return null;
        }

        /+
         + Clear all archives
         +/

        void clear() {
            _archives.clear;
        }


        void insert(const Document doc, const Archive.Type type=Archive.Type.NONE) {
            auto a=new Archive(net, doc, type);
            insert(a);
        }

        void insert(T)(T pack, const Archive.Type type=Archive.Type.NONE) if(isHiBONRecord!T) {
            insert(pack.toDoc, type);
        }

        private void insert(Archive archive) {
            _archives.insert(archive);
        }

        const(Archive) add(const(Document) doc)
            in {
                assert(doc.data);
            }
        do {
            auto archive=new Archive(net, doc, Archive.Type.ADD);
            _archives.insert(archive);
            return archive;
        }

        const(Archive) remove(const(Document) doc)
            in {
                assert(doc.data);
            }
        do {
            auto archive=new Archive(net, doc, Archive.Type.REMOVE);
            _archives.insert(archive);
            return archive;
        }

        void remove(immutable(Buffer) fingerprint)
            in {
                assert(fingerprint);
            }
        do {
            auto archive=new Archive(fingerprint, Archive.Type.REMOVE);
            _archives.insert(archive);
        }

        void stub(immutable(Buffer) fingerprint) {
            auto archive=new Archive(fingerprint, Archive.Type.NONE);
            insert(archive);
        }

        void dump() const {
            import std.stdio;
            foreach(a; _archives) {
                writefln("Archive %s %s", a.fingerprint.hex, a.type);
            }
        }

        HiBON toHiBON() const {
            auto result=new HiBON;
            uint i;
            foreach(a; _archives) {
                result[i]=Document(a.toHiBON.serialize);
                //result[i]=a.toDoc;
                i++;
            }
            return result;
        }
    }
}


@safe class Archive {
    enum Type : int {
        NONE = 0,
            REMOVE = -1,
            ADD = 1,
            STUB
            }
    @Label("") immutable(Buffer) fingerprint;
    @Label("$a", true) const Document doc;
    @Label("$t", true) Type type;

//            immutable uint index;
    bool done;

    this(HashNet net, const(Document) _doc, const Type t)
    in {
        assert(net);
    }
    do {
        if (t is Type.STUB) {
            // The type is stub the data contains the fingerprint not data
            fingerprint=doc.data;
        }
        else {
            fingerprint=net.hashOf(_doc);
            doc=_doc;
        }
        type=t;
        //index=INDEX_NULL;
    }

//    version(none)
    this(HashNet net, Document _doc, const uint _index)
    in {
        assert(net);
    }
    do {
        fingerprint=net.hashOf(_doc);
        this.doc=_doc;
        //      this.index=index;
        type=Type.NONE;
    }

    this(HashNet net, Document _doc) {
        uint doc_type=_doc[Params.type].get!uint;
//                Buffer _data;
        Buffer _fingerprint;
        Document inner_doc;
        scope(success) {
            type=cast(Type)doc_type;
            doc=inner_doc;
            if ( _fingerprint ) {
                fingerprint=_fingerprint;
            }
            else {
                fingerprint=net.hashOf(doc);
            }
        }
        // scope(exit) {
        //     this.index=INDEX_NULL;
        // }
        with(Type) switch(doc_type) {
            case ADD, NONE:
                const archive_doc=_doc[Params.archive].get!Document;
                inner_doc=archive_doc;
                // _data=archive_doc.data.idup;

                break;
            case REMOVE:
                if ( _doc.hasMember(Params.fingerprint) ) {
                    goto case STUB;
                }
                else {
                    goto case NONE;
                }
                break;
            case STUB:
                _fingerprint=_doc[Params.fingerprint].get!Buffer;
                break;
            default:
                .check(0, format("Unsupported archive type number=%d", type));
            }
    }

    HiBON toHiBON() const {
        auto hibon=new HiBON;
        hibon[Params.type]=cast(uint)(type);
        if ( doc.length ) {
            hibon[Params.archive]=doc;
        }
        else {
            hibon[Params.fingerprint]=fingerprint;
        }
        return hibon;
    }

    // Define a remove archive by it fingerprint
    private this(Buffer fingerprint, const Type t=Type.REMOVE) {
        type=t;
        //index=INDEX_NULL;
        doc=Document();
        //data=null;
        this.fingerprint=fingerprint;
    }

    final bool isRemove() pure const nothrow {
        return type is Type.REMOVE;
    }

    final bool isAdd() pure const nothrow {
        return type is Type.ADD;
    }

    final bool isStub() pure const nothrow {
        return type is Type.STUB;
    }

    // final Type type() pure const nothrow {
    //     return _type;
    // }

    /++
     + Returns:
     +     Generates Buffer to be store in the BlockFile
     +/
    immutable(Buffer) store() const {
        if ( type is Type.STUB ) {
            auto hibon=new HiBON;
            hibon[Keywords.stub]=fingerprint;
            return hibon.serialize;
        }
        .check(doc.serialize.length !is 0, format("Archive is %s type and it must contain data", type));
        return doc.serialize;
    }

}
