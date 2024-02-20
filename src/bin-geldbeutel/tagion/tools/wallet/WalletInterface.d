module tagion.tools.wallet.WalletInterface;
import core.thread;
import std.algorithm;
import std.conv : to;
import std.exception : ifThrown;
import std.file : exists, mkdir;
import std.format;
import std.path;
import std.range;
import std.stdio;
import std.string : representation;
import tagion.basic.Message;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.basic.basic : isinit;
import tagion.basic.range : doFront;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : isHiBONRecord, isRecord;
import tagion.script.TagionCurrency;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.Term;
import tagion.wallet.AccountDetails;
import tagion.wallet.KeyRecover;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;

//import tagion.basic.tagionexceptions : check;
import std.range;
import std.typecons;
import tagion.communication.HiRPC;
import tagion.crypto.Types : Pubkey, Fingerprint;
import tagion.dart.DARTBasic;
import tagion.dart.DARTcrud;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONtoText;
import tagion.script.common;
import tagion.script.execute : ContractExecution;
import tagion.script.standardnames;
import tagion.tools.Basic;
import tagion.wallet.SecureWallet : check;
import tagion.wallet.WalletException;
import tagion.tools.secretinput;

//import tagion.wallet.WalletException : check;
/**
 * @brief strip white spaces in begin/end of text
 * @param word - input parameter with out
 * return dublicate out parameter
 */
const(char[]) trim(return scope const(char)[] word) pure nothrow @safe @nogc {
    import std.ascii : isWhite;

    while (word.length && word[0].isWhite) {
        word = word[1 .. $];
    }
    while (word.length && word[$ - 1].isWhite) {
        word = word[0 .. $ - 1];
    }
    return word;
}

/**
 * @brief Write in console warning message
 */
void warning() {
    writefln("%sWARNING%s: This wallet should only be used for the Tagion Dev-net%s", RED, BLUE, RESET);
}

void word_strip(scope ref char[] word_strip) pure nothrow @safe @nogc {
    import std.ascii : isWhite;

    scope not_change = word_strip;
    scope (exit) {
        assert((word_strip.length is 0) || (&not_change[0] is &word_strip[0]), "The pincode should not be reallocated");
    }
    size_t current_i;
    foreach (c; word_strip) {
        if (!c.isWhite) {
            word_strip[current_i++] = c;
        }
    }
    word_strip = word_strip[0 .. current_i];
}

enum MAX_PINCODE_SIZE = 128;
enum LINE = "------------------------------------------------------";

pragma(msg, "Fixme(lr)Remove trusted when nng is safe");
HiRPC.Receiver sendSubmitHiRPC(string address, HiRPC.Sender contract, HiRPC hirpc = HiRPC(null)) @trusted {
    import nngd;
    import std.exception;
    import tagion.hibon.Document;
    import tagion.hibon.HiBONtoText;

    int rc;
    NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    sock.sendtimeout = 1000.msecs;
    sock.sendbuf = 0x4000;
    sock.recvtimeout = 3000.msecs;

    rc = sock.dial(address);
    if (rc != 0) {
        throw new WalletException(format("Could not dial address %s: %s", address, nng_errstr(rc)));
    }

    rc = sock.send(contract.toDoc.serialize);
    check(sock.m_errno == nng_errno.NNG_OK, format("NNG_ERRNO %d", cast(int) sock.m_errno));
    check(rc == 0, format("Could not send bill to network %s", nng_errstr(rc)));

    auto response_data = sock.receive!Buffer;
    auto response_doc = Document(response_data);
    // We should probably change these exceptions so it always returns a HiRPC.Response error instead?
    check(response_doc.isRecord!(HiRPC.Receiver), format("Error in response when sending bill %s", response_doc.toPretty));

    return hirpc.receive(response_doc);
}

HiRPC.Receiver sendShellHiRPC(string address, Document doc, HiRPC hirpc) {
    import nngd;

    WebData rep = WebClient.post(address, cast(ubyte[]) doc.serialize, [
        "Content-type": "application/octet-stream"
    ]);

    if (rep.status != http_status.NNG_HTTP_STATUS_OK || rep.type != "application/octet-stream") {
        throw new WalletException(format("send shell submit, received: %s code(%d): %s", rep.type, rep.status, rep.msg));
    }

    Document response_doc = Document(cast(immutable) rep.rawdata);
    return hirpc.receive(response_doc);
}

HiRPC.Receiver sendShellHiRPC(string address, HiRPC.Sender req, HiRPC hirpc) {
    return sendShellHiRPC(address, req.toDoc, hirpc);
}

pragma(msg, "Fixme(lr)Remove trusted when nng is safe");
HiRPC.Receiver sendDARTHiRPC(string address, HiRPC.Sender dart_req, HiRPC hirpc, Duration recv_duration = 15_000.msecs) @trusted {
    import nngd;
    import std.exception;
    import tagion.hibon.HiBONException;

    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    scope (exit) {
        s.close();
    }
    s.recvtimeout = recv_duration;

    while (1) {
        writefln("REQ to dial... %s", address);
        rc = s.dial(address);
        if (rc == 0) {
            break;
        }
        if (rc == nng_errno.NNG_ECONNREFUSED) {
            nng_sleep(100.msecs);
        }
        if (rc != 0) {
            throw new WalletException(format("Could not dial kernel %s, %s", address, nng_errstr(rc)));
        }
    }
    rc = s.send(dart_req.toDoc.serialize);
    if (s.errno != 0) {
        throw new WalletException(format("error in send of darthirpc: %s", s.errno));
    }
    Document received_doc = s.receive!Buffer;
    if (s.errno != 0) {
        throw new WalletException(format("REQ Socket error after receive: %s", s.errno));
    }

    try {
        hirpc.receive(received_doc);
    }
    catch (HiBONException e) {
        writefln("::error::ERROR in hirpc receive: %s %s", e, received_doc.toPretty);
    }

    return hirpc.receive(received_doc);
}

struct WalletInterface {
    const(WalletOptions) options;
    alias StdSecureWallet = SecureWallet!StdSecureNet;
    StdSecureWallet secure_wallet;
    Invoices payment_requests;
    Quiz quiz;
    this(const WalletOptions options) {
        this.options = options;
    }

    bool load() {
        if (options.walletfile.exists) {
            const wallet_doc = options.walletfile.fread;
            const pin_doc = options.devicefile.exists ? options.devicefile.fread : Document.init;
            if (wallet_doc.isInorder && pin_doc.isInorder) {
                secure_wallet = WalletInterface.StdSecureWallet(wallet_doc, pin_doc);
            }
            if (options.quizfile.exists) {
                quiz = options.quizfile.fread!Quiz;
            }
            if (options.accountfile.exists) {
                secure_wallet.account = options.accountfile.fread!AccountDetails;
            }
            return true;
        }
        quiz.questions = options.questions.dup;
        return false;
    }

    void save(const bool recover_flag) {
        if (secure_wallet.isLoggedin && !dry_switch) {
            verbose("Write %s", options.walletfile);

            options.walletfile.fwrite(secure_wallet.wallet);
            verbose("Write %s", options.devicefile);
            options.devicefile.fwrite(secure_wallet.pin);
            if (!recover_flag) {
                verbose("Write %s", options.quizfile);
                options.quizfile.fwrite(quiz);
            }
            if (secure_wallet.account !is AccountDetails.init) {
                verbose("Write %s", options.accountfile);
                options.accountfile.fwrite(secure_wallet.account);
            }
        }
    }

    enum FKEY = YELLOW;
    /**
    * @brief console UI waiting cursor
    */
    static void pressKey() {
        writefln("Press %1$sEnter%2$s", YELLOW, RESET);
        readln;
    }

    enum retry = 4;
    /**
    * @brief change pin code interface
    */
    bool loginPincode(const bool changepin) {
        //CLEARSCREEN.write;
        char[] old_pincode;
        char[] new_pincode1;
        char[] new_pincode2;
        scope (exit) {
            // Scramble the code to prevent memory leaks
            old_pincode[] = 0;
            new_pincode1[] = 0;
            new_pincode2[] = 0;
        }
        foreach (i; 0 .. retry) {
            //HOME.write;
            writefln("%1$sAccess code required%2$s", GREEN, RESET);
            writefln("%1$sEnter empty pincode to proceed recovery%2$s", YELLOW, RESET);
            //writefln("pincode:");
            scope (exit) {
                old_pincode[] = 0;
            }
            info("Press ctrl-C to break");
            info("Press ctrl-A to show the pincode");
            getSecret("pincode: ", old_pincode);
            old_pincode.word_strip;
            if (old_pincode.length) {
                secure_wallet.login(old_pincode);
                if (secure_wallet.isLoggedin) {
                    if (!changepin) {
                        return true;
                    }
                    break;
                }
                error("Wrong pincode");
            }
        }
        //CLEARSCREEN.write;
        if (changepin && secure_wallet.isLoggedin) {
            foreach (i; 0 .. retry) {
                //HOME.write;
                //CLEARSCREEN.write;
                scope (success) {
                    CLEARSCREEN.write;
                }
                LINE.writeln;
                info("Change you pin code");
                LINE.writeln;
                if (secure_wallet.pin.D) {
                    bool ok;
                    do {
                        info("New pincode:%s", CLEARDOWN);
                        getSecret("pincode: ", new_pincode1);
                        new_pincode1.word_strip;
                        info("Repeaté:");
                        getSecret("pincode: ", new_pincode2);
                        new_pincode2.word_strip;
                        ok = (new_pincode1.length >= 4);
                        if (ok && (ok = (new_pincode1 == new_pincode2)) is true) {
                            secure_wallet.changePincode(old_pincode, new_pincode1);
                            secure_wallet.login(new_pincode1);
                            options.devicefile.fwrite(secure_wallet.pin);
                            return true;
                        }
                        else {
                            writefln("%1$sPincode to short or does not match%2$s", RED, RESET);
                        }
                    }
                    while (!ok);
                    return true;
                }
                writefln("%1$sPin code is missing. You need to recover you keys%2$s", RED, RESET);
            }
        }
        return false;
    }

    bool generateSeedFromPassphrase(const(char[]) passphrase, const(char[]) pincode, const(char[]) salt = null) {
        auto tmp_secure_wallet = StdSecureWallet(passphrase, pincode, salt);
        if (!secure_wallet.wallet.isinit && secure_wallet.wallet.S != tmp_secure_wallet.wallet.S) {
            return false;
        }
        secure_wallet = tmp_secure_wallet;
        return true;
    }

    /**
    * @brief generate q/a pair keys
    * @param questions - string array
    * @param recover_flag - recover/create flag (true mean creating)
    */
    void generateSeed(const(string[]) questions, const bool recover_flag) {
        auto answers = new char[][questions.length];
        auto translated_questions = questions.map!(s => message(s));
        CLEARSCREEN.write;
        scope (success) {
            CLEARSCREEN.write;
        }
        int ch;
        KeyStroke key;
        uint select_index = 0;
        uint confidence;
        if (recover_flag) {
            confidence = secure_wallet.confidence;
        }
        while (ch != 'q') {
            //    import core.stdc.stdio : getc, stdin;
            HOME.write;
            // warning();
            if (recover_flag) {
                writefln("%sRecover account%s", YELLOW, RESET);
                writefln("Answers %d to more of the questions below", confidence);
            }
            else {
                writefln("%sCreate a new account%s", BLUE, RESET);
                writefln("Answers two to more of the questions below");
            }
            LINE.writeln;
            uint number_of_answers;
            foreach (i, question, answer; lockstep(translated_questions, answers)) {
                string select_code;
                string chosen_code;
                if (select_index == i) {
                    select_code = BLUE ~ BACKGOUND_WHITE;
                }
                if (answer.length) {
                    chosen_code = GREEN;
                    number_of_answers++;
                }
                writefln("%2d %s%s%s%s %s%s", i, select_code, chosen_code, question, RESET, answer.trim, CLEAREOL);
            }
            writefln("recover_flag=%s", recover_flag);
            if (!recover_flag) {
                confidence = min(confidence, number_of_answers);
            }
            writefln("Confidence %d", confidence);

            LINE.writefln;
            if (recover_flag) {
                writefln("%1$sq%2$s:quit %1$sEnter%2$s:select %1$sUp/Down%2$s:move %1$sc%2$s:recover%3$s",
                        FKEY, RESET, CLEARDOWN);
            }
            else {
                writefln("%1$sq%2$s:quit %1$sEnter%2$s:select %1$sUp/Down%2$s:move %1$sLeft/Right%2$s:confidence %1$sc%2$s:create%3$s",
                        FKEY, RESET, CLEARDOWN);
            }
            const keycode = key.getKey(ch);
            with (KeyStroke.KeyCode) {
                switch (keycode) {
                case UP:
                    select_index = (select_index - 1) % questions.length;
                    break;
                case DOWN:
                    select_index = (select_index + 1) % questions.length;
                    break;
                case LEFT:
                    if (!recover_flag && confidence > 2) {
                        confidence--;
                    }
                    break;
                case RIGHT:
                    if (!recover_flag) {
                        confidence = max(confidence + 1, number_of_answers);
                    }
                    break;
                case ENTER:
                    writefln("%s%s%s", questions[select_index], CLEAREOL, CLEARDOWN);
                    char[] answer;
                    answer.length = MAX_PINCODE_SIZE;
                    readln(answer);
                    //answer.word_strip;
                    answers[select_index] = answer;
                    if (!recover_flag) {
                        confidence++;
                    }
                    break;
                case NONE:
                    switch (ch) {
                    case 'c': // Create Wallet
                        scope (exit) {
                            // Erase the answer from memory
                            answers
                                .filter!(a => a.length > 0)
                                .each!((ref a) { a[] = 0; a = null; });
                            pressKey;
                        }
                        auto quiz_list = zip(questions, answers)
                            .filter!(q => q[1].length > 0);
                        quiz.questions = quiz_list.map!(q => q[0]).array.dup;
                        auto selected_answers = quiz_list.map!(q => q[1]).array;
                        if (selected_answers.length < 3) {
                            writefln("%1$sThen number of answers must be more than %4$d%2$s%3$s",
                                    RED, RESET, CLEAREOL, selected_answers.length);
                        }
                        else {
                            if (recover_flag) {
                                writefln("RECOVER_FLAG");
                                stdout.flush;
                                const ok = secure_wallet.correct(quiz.questions, selected_answers);
                                writefln("RECOVER %s", ok);
                                if (ok) {
                                    writefln("%1$s%3$d or more answers was correct%2$s", GREEN, RESET, confidence);
                                }
                                else {
                                    writefln("%1$sSome wrong answers. The account has not been recovered%2$s", RED, RESET);
                                    secure_wallet.logout;
                                    continue;
                                }
                            }
                            do {
                                char[] pincode1;
                                pincode1.length = MAX_PINCODE_SIZE;
                                char[] pincode2;
                                pincode2.length = MAX_PINCODE_SIZE;
                                scope (exit) {
                                    pincode1[] = 0;
                                    pincode2[] = 0;
                                }
                                writefln("Pincode:%s", CLEARDOWN);
                                readln(pincode1);
                                pincode1.word_strip;
                                writefln("Repeate:");
                                readln(pincode2);
                                pincode2.word_strip;

                                if (pincode1 != pincode2) {
                                    writefln("%sPincode is not the same%s", RED, RESET);
                                }
                                else if (pincode1.length < 4) {
                                    writefln("%sPincode must be at least 4 chars%s", RED, RESET);
                                }
                                else if (pincode1.length > MAX_PINCODE_SIZE) {
                                    writefln("%1$sPincode must be less than %3$d chars%2$s",
                                            RED, RESET, pincode1.length);
                                }
                                else {
                                    if (recover_flag) {
                                        const ok = secure_wallet.recover(quiz.questions, selected_answers, pincode1);
                                        if (ok) {
                                            writefln("%1$sWallet recovered%2$s", GREEN, RESET);
                                            save(recover_flag);
                                        }
                                        else {
                                            writefln("%1$sWallet NOT recovered%2$s", RED, RESET);
                                        }
                                    }
                                    else {
                                        secure_wallet = StdSecureWallet(
                                                quiz.questions, selected_answers, confidence, pincode1);
                                        save(recover_flag);
                                    }
                                }
                            }
                            while (!secure_wallet.isLoggedin);
                            return;
                        }
                        break;
                    default:
                        //writefln("Ignore %s '%s'", keycode, cast(char) ch);
                        // ignore
                    }
                    break;
                default:
                    // ignore
                }
            }

        }
    }

    import tagion.script.common : TagionBill;

    string show(in TagionBill bill) {
        const index = secure_wallet.net.dartIndex(bill);
        const deriver = secure_wallet.account.derivers.get(bill.owner, Buffer.init);
        return format("dartIndex %s\nDeriver   %s\n%s",
                index.encodeBase64, deriver.encodeBase64, bill.toPretty);
    }

    string show(const Document doc) {
        const index = secure_wallet.net.calcHash(doc);
        const deriver = secure_wallet.account.derivers.get(Pubkey(doc[StdNames.owner].get!Buffer), Buffer.init);
        return format("fingerprint %s\nDeriver   %s\n%s",
                index.encodeBase64, deriver.encodeBase64, doc.toPretty);
    }

    string show(T)(T rec) if (isHiBONRecord!T) {
        return show(rec.toDoc);
    }

    static string toText(
            const(HashNet) hash_net,
            const TagionBill bill,
            string mark = null) {
        import std.format;
        import tagion.hibon.HiBONtoText;
        import tagion.utils.StdTime : toText;

        return format("%2$s%3$27-s %4$s %5$17.6fTGN%1$s",
                RESET, mark,
                bill.time.toText,
                hash_net.calcHash(bill)
                .encodeBase64,
                bill.value.value);
    }

    void listAccount(File fout, const(HashNet) hash_net = null) {
        void innerAccount(const(HashNet) _hash_net) {
            const line = format("%-(%s%)", "- ".repeat(40));
            fout.writefln("%-5s %-27s %-45s %-40s", "No", "Date", "Fingerprint", "Value");
            fout.writeln(line);
            auto bills = secure_wallet.account.bills ~ secure_wallet.account.requested.values;
            bills.sort!(q{a.time < b.time});
            foreach (i, bill; bills) {
                string mark = GREEN;
                const bill_index = hash_net.dartIndex(bill);
                if (bill_index in secure_wallet.account.requested) {
                    mark = RED;
                }
                else if (bill_index in secure_wallet.account.activated) {
                    mark = YELLOW;
                }
                writefln("%4s] %s", i, toText(_hash_net, bill, mark));
                verbose("%s", show(bill));
            }
            fout.writeln(line);
        }

        if (hash_net) {
            innerAccount(hash_net);
            return;
        }
        innerAccount(secure_wallet.net);
    }

    void listInvoices(File fout) {
        const invoices = secure_wallet.account.requested_invoices;
        if (invoices.empty) {
            return;
        }

        fout.writeln("Outstanding invoice requests");
        const line = format("%-(%s%)", "- ".repeat(40));
        fout.writefln("%-5s %-10s %-45s", "No", "Label", "Deriver");
        foreach (i, invoice; invoices) {
            fout.writefln("%4s] %-10s %s", i, invoice.name, invoice.pkey.encodeBase64);
        }
        fout.writeln(line);
    }

    void sumAccount(File fout) {
        with (secure_wallet.account) {
            fout.writefln("Available : %17.6fTGN", available.value);
            fout.writefln("Locked    : %17.6fTGN", locked.value);
            fout.writefln("Total     : %17.6fTGN", total.value);

        }
    }

    struct Switch {
        bool force;
        //        bool list;
        //        bool sum;
        bool send;
        bool sendkernel;
        bool pay;
        bool request;
        bool update;
        bool trt_update;
        bool trt_read;
        double amount;
        bool faucet;
        bool save_wallet;
        string invoice;
        string output_filename;
    }

    enum update_tag = "update";
    void operate(Switch wallet_switch, const(string[]) args) {
        if (secure_wallet.isLoggedin) {
            with (wallet_switch) {
                scope (success) {
                    if (save_wallet) {
                        save(false);
                    }
                }
                if (amount !is amount.init || invoice !is invoice.init) {
                    Document request;
                    if (invoice !is invoice.init) {
                        scope invoice_args = invoice.splitter(":");
                        import tagion.basic.range : eatOne;

                        auto new_invoice = secure_wallet.createInvoice(
                                invoice_args.eatOne,
                                invoice_args.eatOne.to!double.TGN
                        );
                        check(new_invoice.name !is string.init, "Invalid name on invoice");
                        check(new_invoice.amount > 0, "Invoice amount not valid");
                        secure_wallet.registerInvoice(new_invoice);
                        request = new_invoice.toDoc;
                        if (faucet) {
                            sendShellHiRPC(options.addr ~ options.faucet_shell_endpoint, request, HiRPC(secure_wallet.net));
                        }
                    }
                    else {
                        auto bill = secure_wallet.requestBill(amount.TGN);
                        request = bill.toDoc;
                    }
                    const default_name = invoice ? "invoice" : "bill";
                    output_filename = (output_filename.empty) ? default_name.setExtension(FileExtension.hibon) : output_filename;
                    output_filename.fwrite(request);
                    writefln("%1$sCreated %3$s%2$s", GREEN, RESET, output_filename);
                    save_wallet = true;
                    return;
                }
                if (force) {
                    foreach (arg; args[1 .. $]) {
                        TagionBill bill;
                        if (arg.hasExtension(FileExtension.hibon)) {
                            bill = arg.fread!TagionBill;
                        }
                        if ((arg.extension.empty) && (bill is TagionBill.init)) {
                            verbose("index %s", arg);
                            const index = arg.decode.ifThrown(Buffer.init);
                            check(index !is Buffer.init, format("Illegal fingerprint %s", arg));
                            bill = secure_wallet.account.requested.get(DARTIndex(index), TagionBill.init); /// Find bill by owner key     

                            if (bill is TagionBill.init) {
                                // Find bill by fingerprint 
                                bill = secure_wallet.account.requested.byValue
                                    .filter!(b => index == secure_wallet.net.dartIndex(b))
                                    .doFront;

                            }

                        }
                        if (bill !is TagionBill.init) {
                            writefln("%s", toText(secure_wallet.net, bill));
                            verbose("%s", show(bill));
                            secure_wallet.addBill(bill);
                            save_wallet = true;
                        }
                    }
                }
                if (request) {
                    secure_wallet.account.requested.byValue
                        .each!(bill => secure_wallet.net.dartIndex(bill)
                                .encodeBase64.setExtension(FileExtension.hibon).fwrite(bill));
                }
                if (update || trt_update || trt_read) {
                    const update_net = secure_wallet.net.derive(
                            secure_wallet.net.calcHash(
                            update_tag.representation));
                    const hirpc = HiRPC(update_net);

                    const(HiRPC.Sender) getRequest() {
                        if (trt_update) {
                            return secure_wallet.getRequestUpdateWallet(hirpc);
                        }
                        else if (trt_read) {
                            return secure_wallet.readIndicesByPubkey(hirpc);
                        }
                        return secure_wallet.getRequestCheckWallet(hirpc);
                    }

                    const req = getRequest();

                    if (output_filename !is string.init) {
                        output_filename.fwrite(req);
                    }
                    if (send || sendkernel) {
                        HiRPC.Receiver received = sendkernel ?
                            sendDARTHiRPC(options.dart_address, req, hirpc) : sendShellHiRPC(
                                    options.addr ~ options.dart_shell_endpoint, req, hirpc);

                        verbose("Received response", received.toPretty);

                        version (TRT_READ_REQ) {
                            bool setRequest(const(HiRPC.Receiver) receiver) {
                                if (trt_update) {
                                    return secure_wallet.setResponseUpdateWallet(receiver);
                                }
                                else if (update) {
                                    return secure_wallet.setResponseCheckRead(receiver);
                                }
                                else {
                                    const difference_req = secure_wallet.differenceInIndices(receiver);
                                    if (difference_req is HiRPC.Sender.init) {
                                        return true;
                                    }
                                    HiRPC.Receiver dart_received = sendkernel ?
                                        sendDARTHiRPC(options.dart_address, difference_req, hirpc) : sendShellHiRPC(options.addr ~ options.dart_shell_endpoint, difference_req, hirpc);

                                    return secure_wallet.updateFromRead(dart_received);
                                }
                            }

                            bool res = setRequest(received);
                        }
                        else {
                            bool res = trt_update ? secure_wallet.setResponseUpdateWallet(
                                    received) : secure_wallet.setResponseCheckRead(received);
                        }
                        writeln(res ? "wallet updated succesfully" : "wallet not updated succesfully");
                        save_wallet = true;
                    }

                }

                if (pay) {

                    Document[] requests_to_pay = args[1 .. $]
                        .filter!(file => file.hasExtension(FileExtension.hibon))
                        .map!(file => file.fread)
                        .array;

                    TagionBill[] to_pay;
                    foreach (doc; requests_to_pay) {
                        if (doc.isRecord!TagionBill) {
                            to_pay ~= TagionBill(doc);
                        }
                        else if (doc.isRecord!Invoice) {
                            import tagion.utils.StdTime : currentTime;

                            auto read_invoice = Invoice(doc);
                            to_pay ~= TagionBill(read_invoice.amount, currentTime, read_invoice.pkey, Buffer.init);
                        }
                        else {
                            check(0, "File supplied not TagionBill or Invoice");
                        }
                    }

                    SignedContract signed_contract;
                    TagionCurrency fees;
                    secure_wallet.createPayment(to_pay, signed_contract, fees).get;

                    //   check(created_payment, "payment was not successful");

                    output_filename = (output_filename.empty) ? "submit".setExtension(FileExtension.hibon) : output_filename;
                    const message = secure_wallet.net.calcHash(signed_contract);
                    const contract_net = secure_wallet.net.derive(message);
                    const hirpc = HiRPC(contract_net);
                    const hirpc_submit = hirpc.submit(signed_contract);
                    if (!output_filename.empty) {
                        output_filename.fwrite(hirpc_submit);
                    }
                    verbose("submit\n%s", show(hirpc_submit));
                    secure_wallet.account.hirpcs ~= hirpc_submit.toDoc;
                    save_wallet = true;
                    if (send) {
                        sendShellHiRPC(options.addr ~ options.contract_shell_endpoint, hirpc_submit, hirpc);
                    }
                    else if (sendkernel) {
                        sendSubmitHiRPC(options.contract_address, hirpc_submit, hirpc);
                    }
                }
            }
        }
    }
}
