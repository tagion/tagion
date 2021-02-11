module tagion.dart.Recorder;

import std.container.rbtree : RedBlackTree;
import  std.range.primitives : isInputRange;

import tagion.gossip.InterfaceNet : HashNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : Label, STUB, isDocument, GetLabel, isStub;
import tagion.basic.Basic : Buffer;
import tagion.basic.Message;;
import tagion.dart.DARTException : DARTRecorderException;

import tagion.basic.TagionExceptions : Check;

//import tagion.utils.Miscellaneous : toHex=toHexString;

import tagion.utils.Miscellaneous : toHexString;
alias hex=toHexString;

private alias check=Check!DARTRecorderException;

//    alias recorder=factory.recorder;
class Factory {


    const HashNet net;
    @disable this();
    protected this(const HashNet net) {
        this.net=net;
    }
    static Factory opCall(const HashNet net) {
        return new Factory(net);
    }
    /++
     Creates an empty Recorder
     +/
    Recorder recorder() nothrow {
        return new Recorder;
    }

    /++
     Creates an empty Recorder
     +/
    Recorder recorder(const(Document) doc) {
        return new Recorder(doc);
    }

    /++
     + Creates a Recorder base on an existing archive list

     + Params:
     +     archives = Archive list
     +/
    Recorder recorder(Recorder.Archives archives) nothrow  {
        return new Recorder(archives);
    }

    Recorder recorder(R)(R range) if(isInputRange!R) {
        return new Recorder(range);
    }


    /++
     +  Recorder to recorder (REMOVE, ADD) actions while can be executed by the
     +  modify method
     +/
    @safe
    class Recorder {
        alias Archives=RedBlackTree!(Archive, (a,b) => a.fingerprint < b.fingerprint);
//        protected HashNet net;
        private Archives _archives;
//        @disable this();
//        alias BranchRange=Archives.Range;
//        this(ref return scope Recorder rec) {}

        /++
         + Creates a Recorder with an empty archive list
         + Params:
         +     net = Secure net should be the same as define in the DARTFile class
         +/
        private this() pure nothrow {
            this._archives = new Archives;
        }

        /++
         + Creates an Recorder base on an existing archive list

         + Params:
         +     net      = Secure net should be the same as define in the DARTFile class
         +     archives = Archive list
         +/
        private this(Archives archives) pure nothrow {
            this._archives=archives;
        }

        @trusted private this(R)(R range) if(isInputRange!R) {
            this._archives=new Archives(range);
        }

        private this(Document doc) {
            const x=net;
            foreach(e; doc[]) {
                auto doc_archive=e.get!Document;
                auto archive=new Archive(net, doc_archive);
                _archives.insert(archive);
            }
        }

        package inout(Archives) archives() inout  {
            return _archives;
        }


        auto opSlice() {
            pragma(msg, typeof(this._archives));
            return _archives[];
        }

        void removeOutOfRange(ushort from, ushort to){  //TODO: write unit tests
            if(from == to) return;
            immutable ushort to_origin=(to-from) & ushort.max;
            foreach(archive; _archives){
                if(archive.type != Archive.Type.REMOVE){
                    short archiveSector = archive.fingerprint[0] | archive.fingerprint[1];
                    // writeln("CHECK STUBS: arcive fp:%s sector: %d", archive.fingerprint, archiveSector);
                    ushort sector_origin=(archiveSector-from) & ushort.max;
                    if( sector_origin >= to_origin ){
                        _archives.removeKey(archive);
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
                scope archive=new Archive(fingerprint, Archive.Type.NONE);
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

        void insert(T)(T pack, const Archive.Type type=Archive.Type.NONE) if(isDocument!T) {
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
                //result[i]=Document(a.toHiBON.serialize);
                result[i]=a.toDoc;
                i++;
            }
            return result;
        }
    }
}

/++
 +/
@safe
class Archive {
    enum Type : int {
        NONE = 0,
            REMOVE = -1,
            ADD = 1,
            //    STUB
            }
    @Label(STUB, true) immutable(Buffer) fingerprint;
    @Label("$a", true) const Document doc;
    @Label("$t", true) Type type;

//            immutable uint index;
    bool done;

    bool isStub() const {
        return .isStub(doc);
    }

    this(const HashNet net, const Document _doc, const Type type=Type.NONE)
    in {
        assert(net);
    }
    do {
        Buffer _fingerprint;
        if (.isStub(_doc)) {
            enum fingerprintLabel=GetLabel!(this.fingerprint).name;
            _fingerprint=doc[fingerprintLabel].get!Buffer;
        }
        else {
            enum archiveLabel=GetLabel!(this.doc).name;
            if (_doc.hasMember(archiveLabel)) {
                doc=_doc[archiveLabel].get!Document;
            }
            else {
                doc=_doc;
            }
            _fingerprint=net.hashOf(_doc);
        }
        fingerprint=_fingerprint;
        enum typeLabel=GetLabel!(this.type).name;
        if (type !is Type.NONE) {
            this.type=type;
        }
        else if (doc.hasMember(typeLabel)) {
            this.type=doc[typeLabel].get!Type;
        }
        //index=INDEX_NULL;
    }

//    version(none)
    this(const HashNet net, const Document _doc, const uint _index)
    in {
        assert(net);
    }
    do {
        assert(0, "Is this used");
        fingerprint=net.hashOf(_doc);
        if (!.isStub(_doc)) {
            doc=_doc;
        }
        //this.index=index;
        type=Type.NONE;
    }

    version(none)
    this(HashNet net, Document _doc) {
        uint type=_doc[Params.type].get!uint;
//                Buffer _data;
        Buffer _fingerprint;
        Document inner_doc;
        scope(success) {
            _type=cast(Type)type;
            doc=inner_doc;
            if ( _fingerprint ) {
                fingerprint=_fingerprint;
            }
            else {
                fingerprint=net.hashOf(doc);
            }
        }
        scope(exit) {
            this.index=INDEX_NULL;
        }
        with(Type) switch(type) {
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

    const(Document) toDoc() const {
        if (isStub) {
            auto hibon=new HiBON;
            enum fingerprintLabel=GetLabel!(this.fingerprint).name;
            hibon[fingerprintLabel]=fingerprint;
            return Document(hibon.serialize);
        }
        if (type !is Type.NONE) {
            auto hibon=new HiBON;
            enum typeLabel=GetLabel!(this.type).name;
            hibon[typeLabel]=type;
            enum archiveLabel=GetLabel!(this.doc).name;
            hibon[archiveLabel]=doc;
            return Document(hibon.serialize);
        }
        return doc;
    }
    // HiBON toHiBON() const {
    //     auto hibon=new HiBON;
    //     hibon[Params.type]=cast(uint)(_type);
    //     if ( doc.empty ) {
    //         hibon[Params.archive]=doc;
    //     }
    //     else {
    //         hibon[Params.fingerprint]=fingerprint;
    //     }
    //     return hibon;
    // }

    // Define a remove archive by it fingerprint
    private this(Buffer fingerprint, const Type type) {
        this.type=type;
        doc=Document(null);
        this.fingerprint=fingerprint;
    }

    final bool isRemove() pure const nothrow {
        return type is Type.REMOVE;
    }

    final bool isAdd() pure const nothrow {
        return type is Type.ADD;
    }

    // final bool isStub() pure const nothrow {
    //     return _type is Type.STUB;
    // }

    // final Type type() pure const nothrow {
    //     return _type;
    // }

    /++
     + Returns:
     +     Generates Buffer to be store in the BlockFile
     +/
    const(Document) store() const {
        if (isStub) {
            auto hibon=new HiBON;
            enum fingerprintLabel=GetLabel!(this.fingerprint).name;
            hibon[fingerprintLabel]=fingerprint;
            return Document(hibon.serialize);
        }
        .check(!doc.empty, message("Archive is %s type and it must contain data", type));
        return doc;
    }

}
