module tagion.dart.Recorder;

import std.stdio;
import tagion.hibon.HiBONJSON;

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
        alias Archives=RedBlackTree!(Archive, (a,b) @safe => a.fingerprint < b.fingerprint);
//        protected HashNet net;
//        private Archives _archives;
        Archives _archives;
//        @disable this();
//        alias BranchRange=Archives.Range;

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
            this._archives = new Archives;
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

        const(Document) toDoc() const {
//        HiBON toHiBON() const {
            auto result=new HiBON;
            uint i;
            foreach(a; _archives) {
                result[i]=a.toDoc; //Document(a.toHiBON.serialize);
                //result[i]=a.toDoc;
                i++;
            }
            return Document(result);
        }
    }
}


@safe class Archive {
    enum Type : int {
        NONE = 0,
            REMOVE = -1,
            ADD = 1,
            }

    @Label(STUB, true) immutable(Buffer) fingerprint;
    @Label("$a", true) const Document filed;
    enum archiveLabel=GetLabel!(this.filed).name;
    enum fingerprintLabel=GetLabel!(this.fingerprint).name;
    enum typeLabel=GetLabel!(this.type).name;
    @Label("$t", true) Type type;
    @Label("") bool done;

    mixin JSONString;
    this(const HashNet net, const(Document) doc, const Type t=Type.NONE, const bool print=false)
    in {
        assert(net);
        assert(!doc.empty);
    }
    do {
        if (.isStub(doc)) {
            fingerprint=net.hashOf(doc);
        }
        else {
            if (doc.hasMember(archiveLabel)) {
                filed=doc[archiveLabel].get!Document;
            }
            else {
                filed=doc;
            }
            fingerprint=net.hashOf(filed);
        }
        if (print) {
            writefln("Archive filed=%s", filed.toPretty);
            writefln("Archive   doc=%s", doc.toPretty);
        }
        type=t;
        if (type is Type.NONE && doc.hasMember(typeLabel)) {
            type=doc[typeLabel].get!Type;
        }

    }

    const(Document) toDoc() const {
        auto hibon=new HiBON;
        if (isStub) {
            hibon[fingerprintLabel]=fingerprint;
//            return Document(hibon);
        }
        else {
            hibon[archiveLabel]=filed;
        }
        if (type !is Type.NONE) {
            hibon[typeLabel]=type;
        }
        return Document(hibon);
    }

    // Define a remove archive by it fingerprint
    private this(Buffer fingerprint, const Type t=Type.NONE) {
        type=t;
        filed=Document();
        this.fingerprint=fingerprint;
    }

    final bool isRemove() pure const nothrow {
        return type is Type.REMOVE;
    }

    final bool isAdd() pure const nothrow {
        return type is Type.ADD;
    }

    final bool isStub() pure const nothrow {
        return filed.empty;
    }

    // final Type type() pure const nothrow {
    //     return _type;
    // }

    /++
     + Returns:
     +     Generates Buffer to be store in the BlockFile
     +/
    const(Document) store() const
    out(result) {
        assert(!result.empty, format("Archive is %s type and it must contain data", type));
    }
    do {
        if ( filed.empty ) {
            auto hibon=new HiBON;
            hibon[fingerprintLabel]=fingerprint;
            return Document(hibon);
        }
        return filed;
    }


}

unittest {
    import std.stdio;
    import std.format;
    import tagion.hibon.HiBONJSON;
    import tagion.dart.DARTFakeNet;
    import tagion.utils.Miscellaneous : toHex=toHexString;
    import std.string : representation;


    auto net=new DARTFakeNet;
    auto manufactor=Factory(net);

    static assert(isHiBONRecord!Archive);
    writeln("### Start Archve unittest");
    Document filed_doc; // This is the data which is filed in the DART
    {
        auto hibon=new HiBON;
        hibon["text"]="Some text";
        filed_doc=Document(hibon);
    }
    immutable filed_doc_fingerprint=net.hashOf(filed_doc);

    writefln("filed_doc=%s", filed_doc.toPretty);
    Archive a;
    { // Simple archive
        a=new Archive(net, filed_doc);
        writefln("a=%s", a.toPretty);
        assert(!a.isStub);
        assert(a.fingerprint == filed_doc_fingerprint);
        assert(a.filed == filed_doc);
        assert(a.type is Archive.Type.NONE);

        const archived_doc=a.toDoc;
        assert(archived_doc[Archive.archiveLabel].get!Document == filed_doc);
        const result_a=new Archive(net, archived_doc);
        writefln("result_a=%s", result_a.toPretty);
        assert(result_a.fingerprint == a.fingerprint);
        assert(result_a.filed == a.filed);
        assert(result_a.type == a.type);
        assert(!result_a.isStub);
        assert(result_a.store == filed_doc);

    }

    a.type = Archive.Type.ADD;
    { // Simple archive with ADD/REMOVE Type
        // a=new Archive(net, filed_doc);
        writefln("a=%s", a.toPretty);
        assert(!a.isStub);
        assert(a.fingerprint == filed_doc_fingerprint);
        const archived_doc=a.toDoc;

        { // Same type
            const result_a=new Archive(net, archived_doc);
            assert(result_a.fingerprint == a.fingerprint);
            assert(result_a.filed == a.filed);
            assert(result_a.type == a.type);
            assert(!result_a.isStub);
            assert(result_a.store == filed_doc);
        }

        { // Chnage type
            const result_a=new Archive(net, archived_doc, Archive.Type.REMOVE);
            assert(result_a.fingerprint == a.fingerprint);
            assert(result_a.filed == a.filed);
            assert(result_a.type == Archive.Type.REMOVE);
            assert(!result_a.isStub);
            assert(result_a.store == filed_doc);
        }
    }


    { // Create Stub
        auto stub=new Archive(a.fingerprint);
        writefln("stub=%s", stub.toPretty);
        assert(stub.isStub);
        assert(stub.fingerprint == a.fingerprint);
        assert(stub.filed.empty);
        const filed_stub=stub.toDoc;
        assert(filed_stub[STUB].get!Buffer == a.fingerprint);
        assert(isStub(filed_stub));
        writefln("stub.store=%s", stub.store.toPretty);

        {
            const result_stub=new Archive(net, filed_stub, Archive.Type.NONE, true);
            assert(result_stub.isStub);
            writefln("stub=%J", result_stub);
            writefln("filed=%s", result_stub.filed.toPretty);
            writefln("net.hashOf(filed_stub) =%s", net.hashOf(filed_stub).toHex);
            writefln("result_stub.fingerprint=%s", result_stub.fingerprint.toHex);
            writefln("stub.fingerprint       =%s", stub.fingerprint.toHex);

            assert(result_stub.fingerprint == stub.fingerprint);
            assert(result_stub.type == stub.type);
            assert(result_stub.filed.empty);
            assert(result_stub.toDoc == stub.toDoc);
            assert(result_stub.store == stub.store);
            assert(isStub(result_stub.store));
        }

        { // Stub with type
            stub.type = Archive.Type.REMOVE;
            const result_stub=new Archive(net, stub.toDoc, Archive.Type.NONE, true);
            assert(result_stub.fingerprint == stub.fingerprint);
            assert(result_stub.type == stub.type);
            assert(result_stub.type == Archive.Type.REMOVE);
            assert(result_stub.store == stub.store);
            assert(isStub(result_stub.store));

            writefln("stub=%s", stub.toPretty);

        }
    }

    { // Filed archive with hash-key
        enum key_name="#name";
        enum keytext="some_key_text";
        immutable hashkey_fingerprint=net.calcHash(keytext.representation);
        Document filed_hash;
        {
            auto hibon=new HiBON;
            hibon[key_name]=keytext;
            filed_hash=Document(hibon);
        }
        auto hash=new Archive(net, filed_hash, Archive.Type.NONE, true);
        writefln("net.hashOf(filed_hash) =%s", net.hashOf(filed_hash).toHex);
        writefln("hashkey_fingerprint    =%s", hashkey_fingerprint.toHex);
        writefln("hash.fingerprint       =%s", hash.fingerprint.toHex);

        assert(hash.fingerprint == hashkey_fingerprint);
    }
//        assert(stub.fingerprint == a.fingerprint);


    writeln("### End Archve unittest");

}
