module tagion.dart.WriteAheadLog;

class WriteAheadLog {
    enum extension="hbson";
    enum pattern="*."~extension;

    private RequestNet _net;
    private immutable string _workdir;
    private immutable string _ground_file;
    private GroundBlock _ground_block;
    static class GoundBlock {
        immutable(Buffer) gound_fingerprint;

        this(immutable(Buffer) data) inout {
            auto doc=Document(data);
            foreach(i, ref m; this.tupleof) {
                alias typeof(m) type;
                enum name=basename!(this.tupleof[i]);
                if ( doc.hasElement(name) ) {
                    static if ( is(type : immutable(ubyte[])) ) {
                        this.tupleof[i]=(doc[name].get!type);
                    }
                    else {
                        this.tupleof[i]=doc[name].get!type;
                    }
                }
            }
        }

        static GoundBlock opCall(string filename) {
            immutable(Buffer) data=file.read(filename);
            return new GoundBlock(Document(data));
        }

        HBSON toBSON() const {
            auto bson=new HBSON;
            foreach(i, m; this.tupleof) {
                enum name=basename!(this.tupleof[i]);
                static if ( __traits(compiles, m.toBSON) ) {
                    bson[name]=m.toBSON;
                }
                else {
                    bson[name]=m;
                }
            }
        }

        immutable(Buffer) serialize() const {
            return toBSON.serialize;
        }
    }

    class LogBlock {
        immutable int number;
        private const(Document[]) logs;
        // Pointer to the previous logblock
        immutable(Buffer) previous;
        this(immutable(Buffer) data) inout {
            auto doc=Document(data);
            foreach(i, ref m; this.tupleof) {
                alias typeof(m) type;
                enum name=basename!(this.tupleof[i]);
                if ( doc.hasElement(name) ) {
                    static if ( is(type : immutable(ubyte[])) ) {
                        this.tupleof[i]=(doc[name].get!type);
                    }
                    else {
                        this.tupleof[i]=doc[name].get!type;
                    }
                }
            }
        }

        this(const(LogBlock) log) {
            logs=log.logs.dup;
            previuos=log.previous;
            number=log.number;
        }

        private this(const(Document[]) logs, immutable uint number=0, const(Buffer) previous=null ) {
            this.logs=logs;
            this.number=number;
            this.previuos=previous;
        }


        HBSON toBSON() const {
            auto bson=new HBSON;
            foreach(i, m; this.tupleof) {
                enum name=basename!(this.tupleof[i]);
                static if ( __traits(compiles, m.toBSON) ) {
                    bson[name]=m.toBSON;
                }
                else {
                    bson[name]=m;
                }
            }
        }

        immutable(Buffer) serialize() const {
            return toBSON.serialize;
        }

        // static LogBlock opCall(string filename) {
        //     immutable(Buffer) data=file.read(filename);
        //     return new LogBlock(Document(data));
        // }

    }

    void reconstruct() {
        if ( _ground_file.exist ) {
            _ground_block=GoundBlock(_gound_file);
        }
        static struct LogElement {
            bool seen;
            const(LogBlock) logblock;
            this(LogBlock logblock) {
                this.logblock=logblock;
            }
        }

        scope LogElement[Buffer] logelements;
        foreach (DirEntry d; dirEntries(workdir, pattern, SpanMode.shallow, false)) {
            writefln("file %s", e.name);
            if ( d.isFile ) {
                immutable(Buffer) data=file.read(d.name);
                immutable fingerprint=_net.calcHash(data);
                logelements[fingerprint]=new LogElement(data);
            }
        }
        scope LogElement topelement;
        foreach(ref e; logelements) {
            if (!e.seen) {
                topelement=e;
                void chaincheck(ref LogElement elog) {
                    if ( elog.logblock.seen ) {
                        elog.logblock.seen=true;
                        if ( elog.logblock.previous != _gound_block.gound_fingerprint ) {
                            chaincheck(logelements[elog.logblock.previous]);
                        }
                    }
                }
                chaincheck(e);
            }
        }
        if ( topelement.seen ) {
            _top_logblock=new LogBlock(topelement.logblock);
        }
    }


    this(string workdir, string ground_file,  RequestNet net) {
        _net=net;
        _workdir=workdir;
        _ground_file=setExtention(buildPath(_workdir, ground_file), extension);
        reconstruct();
    }

    string logblock_filename(const(Buffer) fingerprint) pure const {
        return setExtension(buildPath(_workdir, fingerprint.toHexString), extension);
    }

    // And a log to the write the wrire ahead
    void log(const(Document[]) list) {
        if ( _top_logblock ) {
            scope immutable data=_top_logblock.serialize;
            scope const fingerprint=_net.calcHash(data);
            _top_logblock=new LogBlock(list, _top_logblock.number+1, fingerprint);
        }
        else if ( _ground_block ) {
            _top_logblock=new LogBlock(list, _ground_block, _ground_block.fingerprint);
        }
        else {
            _top_logblock=new LogBlock(list);
        }
        // Write the log to file
        scope immutable data=_top_logblock.serialize;
        scope const fingerprint=_net.calcHash(data);
        immutable filename=logblock_filename(fingerprint);
        filename.write(data);
    }

    // Return the backlog logblock in reverse order
    const(LogBlock[]) backlog() const {
        LogBlock[] list;
        if ( _top_logblock ) {
            uint i;
            void collect(LogBlock block, immutable uint len=1) {
                if ( block.previous != _ground_block.fingerprint ) {
                    immutable filename=logblock_filename(fingerprint);
                    immutable(Buffer) data=(cast(ubyte[])filename.read(data)).idup;
                    auto tmp_block=new LogBlock(data);
                    collect(tmp_block, len+1);
                }
                if ( list !is null ) {
                    list=new LogBlock[len];
                }
                list[i]=block;
                i++;
            }
            collect(_top_logblock);
        }
        return list;
    }


}
