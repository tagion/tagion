// Transaction reverse table service using a DART
module tagion.services.TRTService;
import tagion.services.options : TaskNames;


import std.algorithm : map, filter;
import std.array;
import std.exception;
import std.file;
import std.format : format;
import std.path : isValidPath;
import std.path;
import std.stdio;
import tagion.actor;
import tagion.basic.Types : FileExtension;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.dart.DARTException;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.replicator;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;
import tagion.basic.Types;

@safe
struct TRTOptions {
    string folder_path = buildPath(".");
    string trt_filename = "trt".setExtension(FileExtension.dart);
    string trt_path;

    this(string folder_path, string trt_filename) {
        this.folder_path = folder_path;
        this.trt_filename = trt_filename;
        trt_path = buildPath(folder_path, trt_filename);
    }
    void setPrefix(string prefix) nothrow {
        trt_filename = prefix ~ trt_filename;
        trt_path = buildPath(folder_path, trt_filename);
    }
    mixin JSONCommon;
}




@safe
struct TRTService {
    void task(TRTOptions opts, immutable(TaskNames) task_names, shared(StdSecureNet) shared_net) {
        DART trt_db;
        Exception dart_exception;

        const net = new StdSecureNet(shared_net);

        trt_db = new DART(net, opts.trt_path);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        scope (exit) {
            trt_db.close();
        }


        void trt_read(trtReadRR req, immutable(Buffer)[] owner_keys) {

        }

        void modify(trtModify, immutable(RecordFactory.Recorder) recorder) {


        }
        



        run(&modify, &trt_read);



    }





}



