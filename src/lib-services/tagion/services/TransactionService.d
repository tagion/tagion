/// \file TransactionService.d
module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.exception : ArraySliceError;
import core.thread;
import std.exception : assumeUnique, assumeWontThrow;

import tagion.network.SSLServiceAPI;
import tagion.network.SSLFiberService : SSLFiberService, SSLFiber;
import tagion.logger.Logger;
import tagion.services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control, Buffer;
import tagion.basic.Basic : TrustedConcurrency;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.script.SmartScript;
import tagion.crypto.SecureNet : StdSecureNet;

import tagion.basic.TagionExceptions : fatal, taskfailure, TagionException;

//import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.Recorder : RecordFactory;

@safe class HiRPCNet : StdSecureNet
{
    this(string passphrase)
    {
        super();
        generateKeyPair(passphrase);
    }
}

mixin TrustedConcurrency;

/**
 * \class TransactionServiceTask
 * Task wrapper for transactions
 */
@safe struct TransactionServiceTask
{
    import tagion.tasks.TaskWrapper;

    mixin TaskBasic;
    /** options instance */
    Options options;
    /** cypher hirpc */
    HiRPC* internal_hirpc;
    /** simple hirpc */
    HiRPC* hirpc;
    /** passphrase for encrypt */
    const string passphrase = "Very secret password for the server";
    /** record factory */
    RecordFactory rec_factory;
    /** node thread id */
    Tid node_tid;
    /** dart sync id */
    Tid dart_sync_tid;
    /** SSL API access instance */
    SSLServiceAPI* script_api;

    /**
     * @brief send document message to catch
     */
    @trusted void sendPayload(Document payload)
    {
        node_tid.send(payload, true);
    }

    /**
     * @brief onSTOP event handler
     */
    void onSTOP()
    {
        writefln("Transaction STOP %d", options.transaction.service.port);
        log("Kill socket thread port %d", options.transaction.service.port);
        script_api.stop;
        this.stop = true;
    }

    /**
     * @brief request inputs
     * @param inputs - inputs array
     * @param id - request id
     */
    void requestInputs(const(Buffer[]) inputs, uint id)
    {
        auto sender = DART.dartRead(inputs, *internal_hirpc, id);
        auto tosend = sender.toDoc.serialize; //internal_hirpc.toHiBON(sender).serialize;
        dart_sync_tid.send(options.transaction.service.response_task_name, tosend);
    }

    /**
     * @brief search in dart database
     * @param doc - search data
     * @param id - search id
     */
    void search(Document doc, uint id)
    {
        import tagion.hibon.HiBONJSON;

        auto n_params = new HiBON;
        n_params["owners"] = doc;
        auto sender = internal_hirpc.search(n_params, id);
        auto tosend = sender.toDoc.serialize;
        dart_sync_tid.send(options.transaction.service.response_task_name, tosend);
    }

    /**
     * @brief perform health check
     * @param id - check id
     */
    void areWeInGraph(uint id)
    {
        auto sender = internal_hirpc.healthcheck(new HiBON(), id);
        auto tosend = sender.toDoc.serialize;
        send(node_tid, options.transaction.service.response_task_name, tosend);
    }

    /**
     * @brief receive document
     * @param document - received document
     * \return Receiver with result if complete and empty if fail
     */
    const HiRPC.Receiver receive(ref Document document) @trusted
    {
        try
        {
            return this.hirpc.receive(document);
        }
        catch(ArraySliceError e)
        {
            writeln(e.msg);
            return HiRPC.Receiver();
        }
    }

    /**
     * \class TransactionRelay
     * Class receive action to SSL fiber
     */
    @safe class TransactionRelay : SSLFiberService.Relay
    {
        TransactionServiceTask* owner;

        /**
         * @brief instace constructor
         * @param p_owner - connection to main class
         */
        this(TransactionServiceTask* p_owner)
        {
            owner = p_owner;
        }

        /**
         * @brief generate signed contact from doc
         * @param document - document for conversion
         * \return Signed contact with content if complete and empty if fail
         */
        private static SignedContract toSign(ref Document document) @trusted
        {
            try
            {
                return SignedContract(document);
            }
            catch (ArraySliceError e)
            {
                return SignedContract();
            }
        }

        /**
         * @brief extarct method id without exception
         * @param rec - receiver for method id extraction
         * \return method id or 0 complete/fail
         */
        static uint methodID(ref const HiRPC.Receiver rec) @trusted
        {
            try
            {
                return rec.method.id;
            }
            catch(Exception e)
            {
                writeln(e.msg);
                return 0;
            }
        }

        /**
         * @brief get method name without exception
         * @param rec - receiver for method name extraction
         * \return name/null if complete/fail
         */
        static string methodName(ref const HiRPC.Receiver rec) @trusted
        {
            try
            {
                return rec.method.name;
            }
            catch(Exception e)
            {
                writeln(e.msg);
                return null;
            }
        }

        /**
         * @brief inteface function for transaction poces
         * @param ssl_relay - fiber instance
         * \return true/false
         */
        bool agent(SSLFiber ssl_relay)
        {
            import tagion.hibon.HiBONJSON;

            @trusted const(Document) receivessl() nothrow
            {
                try
                {
                    import tagion.hibon.Document;
                    import tagion.hibon.HiBONRecord;

                    immutable buffer = ssl_relay.receive;
                    log("buffer receiver %d", buffer.length);
                    const result = Document(buffer);
                    bool check_doc(const Document main_doc,
                        const Document.Element.ErrorCode error_code, const(Document.Element) current, const(
                        Document.Element) previous) nothrow @safe
                    {
                        return false;
                    }

                    result.valid(&check_doc);
                    return result;
                }
                catch(Exception t)
                {
                    log.warning("%s", t.msg);
                }
                return Document();
            }

            Document doc;
            uint respone_id;
            try
            {
                doc = receivessl();

                pragma(msg, "fixme(cbr): If doc is empty then return ");
                version (OLD_TRANSACTION)
                {
                    pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);

                    pragma(msg, "fixme(cbr): smartscipt should be services not a local");
                    const hirpc_received = this.owner.receive(doc); //this.owner.hirpc.receive(doc);

                    const method_name = this.methodName(hirpc_received); //hirpc_received.method.name;
                    const params = hirpc_received.method.params;
                }
                else
                    {
                        pragma(msg, "fixme(cbr): smartscipt should be services not a local");
                        const signed_contract = this.toSign(doc); //SignedContract(doc);
                        auto smartscript = new SmartScript(this.owner.hirpc.net, signed_contract);
                        const hirpc_received = owner.receive(doc); //owner.hirpc.receive(doc);
                        respone_id = this.methodID(hirpc_received); //hirpc_received.method.id;
                    }
                    {
                        void yield() @trusted
                        {
                            Fiber.yield;
                        }

                        version (OLD_TRANSACTION)
                        {
                            pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);

                        }
                        else
                        {
                            const method_name = this.methodName(hirpc_received); //hirpc_received.method.name;
                            const params = hirpc_received.method.params;
                        }
                        log("Method name: %s", method_name);
                        switch (method_name)
                        {
                        case "search":
                            owner.search(params, ssl_relay.id); //epoch number?
                            do
                            {
                                yield; /// Expects a response from the DART service
                            }
                            while (!ssl_relay.available());
                            const response = ssl_relay.response;
                            ssl_relay.send(response);
                            break;
                        case "healthcheck":

                            log("sending healthcheck request");
                            owner.areWeInGraph(ssl_relay.id);
                            do
                            {
                                yield;
                                log("available - %s", ssl_relay.available());
                            }
                            while (!ssl_relay.available());
                            const response = ssl_relay.response;
                            log("sending healthcheck response %s", Document(response).toJSON);
                            ssl_relay.send(response);
                            break;
                            version (OLD_TRANSACTION)
                            {
                                pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);

                        case "transaction":
                                // Should be EXTERNAL
                                try
                                {
                                    auto signed_contract = SignedContract(params);
                                    //                            if (signed_contract.valid) {
                                    //
                                    // Load inputs to the contract from the DART
                                    //

                                    auto inputs = signed_contract.contract.inputs;
                                    this.owner.requestInputs(inputs, ssl_relay.id);
                                    yield;
                                    //() @trusted => Fiber.yield; // Expect an Recorder resonse for the DART service
                                    const response = ssl_relay.response;
                                    const received = this.owner.internal_hirpc.receive(Document(response));
                                    //log("%s", Document(response).toJSON);
                                    const foreign_recorder = this.owner.rec_factory.recorder(
                                        received.response.result);
                                    //return recorder;
                                    log("constructed");

                                    import tagion.script.StandardRecords : StandardBill;

                                    // writefln("input loaded %d", foreign_recoder.archive);
                                    PayContract payment;

                                    //signed_contract.input.bills = [];
                                    foreach (archive; foreign_recorder[])
                                    {
                                        auto std_bill = StandardBill(archive.filed);
                                        payment.bills ~= std_bill;
                                    }
                                    signed_contract.inputs = payment.toDoc;
                                    // Send the contract as payload to the HashGraph
                                    // The data inside HashGraph is pure payload not an HiRPC
                                    SmartScript.check(this.owner.hirpc.net, signed_contract);
                                    //log("checked");
                                const payload = Document(signed_contract.toHiBON.serialize);
                                {
                                    immutable data = signed_contract.toHiBON.serialize;
                                    const json_doc = Document(data);
                                    auto json = json_doc.toJSON;

                                    //log("Contract:\n%s", json.toPrettyString);
                                }
                                this.owner.sendPayload(payload);
                                auto empty_params = new HiBON;
                                auto empty_response = this.owner.internal_hirpc.result(hirpc_received,
                                      empty_params);
                                ssl_relay.send(empty_response.toDoc.serialize);
                            }
                            catch (TagionException e)
                            {
                                log.error("Bad contract: %s", e.msg);
                                auto bad_response = this.owner.internal_hirpc.error(hirpc_received, e.msg, 1);
                                ssl_relay.send(bad_response.toDoc.serialize);
                                return true;
                            }
                            {
                                auto response = new HiBON;
                                response["done"] = true;
                                const hirpc_send = this.owner.hirpc.result(hirpc_received, response);
                                immutable send_buffer = hirpc_send.toDoc.serialize;
                                ssl_relay.send(send_buffer);
                            }
                            return true;
                            break;
                        default:
                            }
                            else
                            {
                        default:
                            const inputs = signed_contract.contract.inputs;
                            owner.requestInputs(inputs, ssl_relay.id);
                            yield;

                            const response = ssl_relay.response;
                            const received = owner.internal_hirpc.receive(Document(response));
                            immutable foreign_recorder = owner.rec_factory.uniqueRecorder(
                                received.response.result);
                            log("constructed");
                            auto fail_code = SmartScript.check(owner.hirpc.net, signed_contract, foreign_recorder);
                            if (!fail_code)
                            {
                                owner.sendPayload(signed_contract.toDoc);
                                const empty_response = owner.internal_hirpc.result(hirpc_received, Document());
                                //                            empty_params);
                                ssl_relay.send(empty_response.toDoc.serialize);
                            }
                                if (fail_code)
                            {
                                import tagion.basic.ConsensusExceptions : consensus_error_messages;

                                const error_response = owner.internal_hirpc.error(hirpc_received, consensus_error_messages[fail_code]);
                            }
                        }
                    }
                }
            }
            catch (TagionException e)
            {
                log.error("Bad contract: %s", e.msg);
                const bad_response = owner.hirpc.error(respone_id, e.msg, 1);
                ssl_relay.send(bad_response.toDoc.serialize);
            }
            catch (Exception e)
            {
                log.error("Bad connection: %s", e.msg);
                const bad_response = owner.hirpc.error(respone_id, e.msg, 1);
                ssl_relay.send(bad_response.toDoc.serialize);
            }
            log("Stop connection");
            return true;
        }
    }

    /**
     * @brief wrapper for launch system function in @safe environment
     */
    public void launchThread() @trusted
    {
        this.script_api.start();
    }

    /**
     * @brief init function
     * @parma opts - launch options for new task
     */
    @TaskMethod void opCall(immutable(Options) opts)
    {
        this.options = opts;
        this.dart_sync_tid = locate(opts.dart.sync.task_name);
        this.node_tid = locate(opts.node_name);
        this.internal_hirpc = new HiRPC(null);
        this.hirpc = new HiRPC(new HiRPCNet(passphrase));
        this.rec_factory = RecordFactory(this.hirpc.net);

        auto relay = new TransactionRelay(&this);
        script_api = new SSLServiceAPI(opts.transaction.service, relay);        
        this.launchThread();

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receiveTimeout(500.msecs,
                &control,
                &taskfailure);
        }
    }
};

unittest
{
    ///Check_data_calling
    {
        TransactionServiceTask task;
        task.hirpc = new HiRPC(new HiRPCNet("STUB"));
        TransactionServiceTask.TransactionRelay relay = new TransactionServiceTask.TransactionRelay(&task);
        class StubFiber : SSLFiber
        {
            bool flag = false;
            bool locked() const pure nothrow
            {
                return 0;
            }
            void raw_send(immutable(ubyte[]) buffer) @safe {}
            void startTime() {}
            void send(immutable(ubyte[]) buffer) @safe {}
            void checkTimeout() const @safe {}
            immutable(ubyte[]) receive() @safe
            {
                static immutable ubyte[] stub = ['{', 'A', ':',  'B', '}', 0];
                this.flag = true;
                return stub;
            }
            void lock() nothrow @safe {}
            public uint id()
            {
                return 1;
            }
            void unlock() nothrow {};
            bool available()
            {
                return 1;
            }
            immutable(ubyte)[] response()
            {
                return this.receive();
            }
        }
        StubFiber fiber = new StubFiber();
        relay.agent(fiber);
        assert(fiber.flag);
    }

    ///Create_Stop_Thread
    {
        import tagion.services.Options : getOptions;
        import tagion.tasks.TaskWrapper : Task;
        auto options = getOptions();
        auto serviceTask = Task!TransactionServiceTask(options.transaction.task_name, options);
        assert(receiveOnly!Control == Control.LIVE);
        scope(exit)
        {
            serviceTask.control(Control.STOP);
        }
    }
}
