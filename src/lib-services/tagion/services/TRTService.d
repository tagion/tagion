module tagion.services.TRTService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.exception : assumeUnique;

import tagion.script.StandardRecords;
import tagion.services.Options;
import tagion.basic.Basic : Control, Buffer, Pubkey;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.logger.Logger;

import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.dart.BlockFile;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.Recorder: RecordFactory, Archive;

import std.typecons;
import std.file; 

@RecordType("BLO") struct BillsOwner {
    @Label("#owner") Pubkey owner;
    @Label("$value") Buffer hash;
   
    mixin HiBONRecord!(
    q{
        this(StandardBill bill, const StdHashNet net) 
        {
            this.owner = bill.owner;
            this.hash = net.hashOf(bill.toDoc);
        }
    }); 
}        

struct OwnerHashes {
    immutable(Buffer[]) buf;

    this(immutable(Buffer[]) buf) {
        this.buf = buf;
    }
}

void TRTService(immutable(Options) opts) nothrow {
    try {
        log.register("trt");

        auto net = new StdSecureNet;
        net.generateKeyPair(opts.trt.pass);
        auto factory = RecordFactory(net);
        HiRPC hirpc = HiRPC(net);
        bool stop;

        void controller(Control ctrl) {
            if (ctrl == Control.STOP) {
                stop = true;
                log("Scripting-Api %s stopped", opts.trt.task_name);
            }
        }

        immutable(RecordFactory.Recorder) makeRec(const(RecordFactory.Recorder) recorder) {
            const net = new StdSecureNet;
            auto factory = RecordFactory(net);
            auto rec = factory.recorder;
    
            foreach(r; recorder) {
                if (StandardBill.isRecord(r.filed)) {
                    with (Archive.Type) final switch(r.type) {
                        case ADD:
                            const bill = StandardBill(r.filed);
                            auto bills_owner = BillsOwner(bill, net);
                            rec.add(bills_owner);
                            break;
                        case REMOVE:
                            const bill = StandardBill(r.filed);
                            auto bills_owner = BillsOwner(bill, net);
                            rec.remove(bills_owner);
                            break;
                        case NONE:
                            // Exeption
                            break;
                    }
                }
            }
            return cast(immutable)rec;
        }

        void addRecToDB(ref DART db, immutable(RecordFactory.Recorder) rec) {
            string pass = opts.trt.pass;
    	    net.generateKeyPair(pass);	
	        const sent = hirpc.dartModify(rec);
	        const received = hirpc.receive(sent.toDoc);
	        const result = db(received, false);
        }

        DART db = (() {

            if(opts.trt.dart_file_name.exists) {
                DART db = new DART(net, opts.trt.dart_file_name, 0, 0);
                return db;
            }    
            
    	    enum BlockSize = 0x80;
	        BlockFile.create(opts.trt.dart_file_name, DARTFile.stringof, BlockSize);
            DART db = new DART(net, opts.trt.dart_file_name, 0, 0);
            return db;
        })();       

        immutable(Buffer[])  getHashes(immutable(Buffer[])  owner_hashes) {
            Buffer[] hashes; // Hashes of bills, will be returned
            // For uncnown reason we have fail in dart, when tried
            // to get more than one bills owner from DART, for this reason we take 1 by 1
        
            foreach(oh; owner_hashes) {
                Buffer[] tmp;
                tmp ~= oh;

                auto sended = db.dartRead(tmp); 
                auto received = hirpc.receive(sended.toDoc);
                auto result = db(received, false);
    
                if(result.isResponse) {
                    const rec = factory.recorder(result.response.result);
                    // writefln("%J", rec);
                    foreach(r; rec) {
                        auto b_o = BillsOwner(r.filed);
                        hashes ~= b_o.hash;
                    }
                }   
            } 
            return cast(immutable) hashes;
        }
        
        ownerTid.send(Control.LIVE);
        while (!stop) {
            
            receive(
                    (immutable(RecordFactory.Recorder) recorder) 
                    { 
                        auto rec_with_bills_owners = makeRec(recorder);
                        addRecToDB(db, rec_with_bills_owners);
                        ownerTid.send("recorder receved");
                    },

                    (string task_name, OwnerHashes owner_hashes)
                    {
                        if (cast(string)owner_hashes.buf[0] == "test_version") {
                            ownerTid.send("test_done");
                        }
                        else {

                            immutable(Buffer[]) bufs =  getHashes(owner_hashes.buf);

                            import tagion.hibon.HiBONJSON;
                            auto params_fingerprints = new HiBON;

                            foreach (i, b; bufs) {
                                if (b.length !is 0) {
                                    params_fingerprints[i] = b;
                                }
                            }
                            
                            auto request = hirpc.dartRead(params_fingerprints); 
                            auto dart_sync_tid = locate(opts.dart.sync.task_name);
                            send(dart_sync_tid, opts.transaction.service.response_task_name, request.toDoc.serialize);
                            receive(
                                    (Buffer tosend)
                                    {
                                        auto tid = locate(task_name);
                                        if (tid != Tid.init) {
                                            tid.send(tosend);
                                        }
                                    }
                            );
                        }
                    }
                    );
        }
    }   
    catch (Throwable t) {
        fatal(t);
    }
}

unittest {
    import tagion.services.LoggerService;
    import std.stdio: write, writeln, writef, writefln;
    import std.variant : Variant;
    import std.process : thisThreadID;  
    import tagion.logger.Logger;
    import tagion.services.Options : Options, setOptions, options;
    import tagion.dart.Recorder;
    
    writeln("Start test trt");

    immutable opt_log = (() @trusted {
        Options opt;

        opt.logger = Options.Logger(
            "log_task",
            "/tmp/file.log",
            false,
            true
        );
        return cast(immutable)opt;
    })();


    auto log_tid = spawn(&loggerTask, opt_log);
    const resp = receiveOnly!Control;
    log.register("trt");
    
    scope(exit) {
        log_tid.send(Control.STOP);
        auto resp_ = receiveOnly!Control;
    }

    immutable opt_trt = (() @trusted {
        Options opt;

        opt.trt = Options.TRT(
            "trt_task",
            "secret_pass",
            "DART_TEST.drt"
        );
        return cast(immutable)opt;
    })();

    auto trt_tid = spawn(&TRTService, opt_trt);

    {
        const net = new StdHashNet;
        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;

        trt_tid.send(cast(immutable)recorder);

        receive((string str) {
            assert(str == "recorder receved", "Recorder don't received");
        });

        writeln("trt test receive recorder done");
    }

    {
        Buffer[] bufs;
        Buffer buf = cast(Buffer) "test_version";
        bufs ~= buf;
        auto o_h = OwnerHashes(cast(immutable) bufs);
        trt_tid.send("wrong_name", o_h);
        receive((string str) {
            assert(str == "test_done", "Hashes don't received");
        });

        writeln("trt test receive hashes done");
    }
}
    

    