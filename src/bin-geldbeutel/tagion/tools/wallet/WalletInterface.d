module tagion.tools.wallet.WalletInterface;
import std.stdio;
import tagion.tools.wallet.WalletOptions;
import tagion.wallet.SecureWallet;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords;
import tagion.utils.Term;
import tagion.wallet.AccountDetails;
import tagion.script.TagionCurrency;
import tagion.crypto.SecureNet;
import tagion.basic.Types : FileExtension, Buffer, hasExtension;
import tagion.basic.range : doFront;
import std.file : exists, mkdir;
import std.exception : ifThrown;
import tagion.hibon.HiBONRecord : fwrite, fread, isRecord, isHiBONRecord;
import std.path;
import std.format;
import std.algorithm;
import std.range;
import core.thread;
import tagion.basic.Message;
import std.string : representation;

//import tagion.basic.tagionexceptions : check;
import tagion.hibon.Document;
import std.typecons;
import std.range;
import tagion.tools.Basic;
import tagion.script.common;
import tagion.wallet.SecureWallet : check;
import tagion.script.execute : ContractExecution;
import tagion.script.Currency : totalAmount;
import tagion.hibon.HiBONtoText;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.dart.DARTBasic;
import tagion.crypto.Types : Pubkey;
import tagion.communication.HiRPC;
import tagion.dart.DARTcrud;

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

/**
 * \struct WalletInterface
 * Interface struct for wallet
 */
struct WalletInterface {
    const(WalletOptions) options;
    alias StdSecureWallet = SecureWallet!StdSecureNet;
    StdSecureWallet secure_wallet;
    Invoices payment_requests;
    Quiz quiz;
    this(const WalletOptions options) {
        //this.secure_wallet=secure_wallet;
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
        // secure_wallet.login(pincode);

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
    * @rief chenge pin code interface
    */
    bool loginPincode(const Flag!"ChangePin" change = Yes.ChangePin) {
        CLEARSCREEN.write;
        char[] old_pincode;
        char[] new_pincode1;
        char[] new_pincode2;
        scope (exit) {
            // Scramble the code to prevent memory leaks
            old_pincode.scramble;
            new_pincode1.scramble;
            new_pincode2.scramble;
        }
        foreach (i; 0 .. retry) {
            HOME.write;
            writefln("%1$sAccess code required%2$s", GREEN, RESET);
            writefln("%1$sEnter empty pincode to proceed recovery%2$s", YELLOW, RESET);
            writefln("pincode:");
            scope (exit) {
                old_pincode.scramble;
            }
            readln(old_pincode);
            old_pincode.word_strip;
            if (old_pincode.length) {
                secure_wallet.login(old_pincode);
                if (secure_wallet.isLoggedin) {
                    if (No.ChangePin) {
                        return true;
                    }
                    break;
                }
                writefln("%1$sWrong pincode%2$s", RED, RESET);
            }
        }
        CLEARSCREEN.write;
        if (Yes.ChangePin && secure_wallet.isLoggedin) {
            foreach (i; 0 .. retry) {
                HOME.write;
                CLEARSCREEN.write;
                scope (success) {
                    CLEARSCREEN.write;
                }
                LINE.writeln;
                writefln("%1$sChange you pin code%2$s", YELLOW, RESET);
                LINE.writeln;
                if (secure_wallet.pin.D) {
                    bool ok;
                    do {
                        writefln("New pincode:%s", CLEARDOWN);
                        readln(new_pincode1);
                        new_pincode1.word_strip;
                        writefln("Repeate:");
                        readln(new_pincode2);
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
                    /*    
                }
                    else {
                        writefln("%1$sWrong pin%2$s", GREEN, RESET);
                        pressKey;
                    }
*/
                    return true;
                }
                writefln("%1$sPin code is missing. You need to recover you keys%2$s", RED, RESET);
            }
        }
        return false;
    }

    void generateSeedFromPassphrase(const(string) passphrase, string pincode) {
        secure_wallet = StdSecureWallet.createWallet(passphrase, pincode);
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
                                .each!((ref a) { scramble(a); a = null; });
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
                                    scramble(pincode1);
                                    scramble(pincode2);
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
                                        secure_wallet = StdSecureWallet.createWallet(
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

    string toText(const TagionBill bill, string mark = null) {
        import tagion.utils.StdTime : toText;
        import std.format;
        import tagion.hibon.HiBONtoText;

        const value = format("%10.3f", bill.value.value);
        return format("%2$s%3$s %4$s %5$13.6fTGN%1$s",
                RESET, mark,
                bill.time.toText,
                secure_wallet.net.calcHash(bill)
                .encodeBase64,
                bill.value.value);
    }

    void listAccount(File fout) {
        const line = format("%-(%s%)", "- ".repeat(40));
        fout.writefln("%-5s %-27s %-45s %-40s", "No", "Date", "Fingerprint", "Value");
        fout.writeln(line);
        auto bills = secure_wallet.account.bills ~ secure_wallet.account.requested.values;

        bills.sort!(q{a.time < b.time});
        foreach (i, bill; bills) {
            string mark = GREEN;
            if (bill.owner in secure_wallet.account.requested) {
                mark = RED;
            }
            else if (bill.owner in secure_wallet.account.activated) {
                mark = YELLOW;
            }
            writefln("%4s] %s", i, toText(bill, mark));
            verbose("%s", show(bill));
        }
        fout.writeln(line);
    }

    void sumAccount(File fout) {
        with (secure_wallet.account) {
            fout.writefln("Available : %13.6fTGN", available.value);
            fout.writefln("Locked    : %13.6fTGN", locked.value);
            fout.writefln("Total     : %13.6fTGN", total.value);

        }
    }

    pragma(msg, "Fixme(lr)Remove trusted when nng is safe");
    void sendSubmitHiRPC(string address, HiRPC.Sender contract) @trusted {
        import nngd;
        import std.exception;
        import tagion.hibon.Document;
        import tagion.hibon.HiBONtoText;

        int rc;
        NNGSocket send_sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        rc = send_sock.dial(address);
        if (rc != 0) {
            throw new Exception(format("Could not dial address %s: %s", address, nng_errstr(rc)));
        }
        send_sock.sendtimeout = 1000.msecs;
        send_sock.sendbuf = 4096;

        rc = send_sock.send(contract.toDoc.serialize);
        if (rc != 0) {
            throw new Exception(format("Could not send bill %s: %s", secure_wallet.net.calcHash(contract).encodeBase64, nng_errstr(
                    rc)));
        }
    }

    pragma(msg, "Fixme(lr)Remove trusted when nng is safe");
    Document sendDARTHiRPC(string address, HiRPC.Sender dart_req) @trusted {
        import nngd;
        import std.exception;


        int rc;
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = 1000.msecs;
        while(1) {
            writefln("REQ to dial...");
            rc = s.dial(address);
            if (rc == 0) {
                break;
            }
            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(100.msecs);
            }
            if (rc != 0) {
                throw new Exception(format("Could not dial kernel %s", nng_errstr(rc)));
            }
        }
        while (1) {
            rc = s.send!(immutable(ubyte[]))(dart_req.toDoc.serialize);
            if (s.errno != 0) {
                throw new Exception("error in response");
            }
            Document received_doc = s.receive!(immutable(ubyte[]))();
            return received_doc;
        }
    }

    struct Switch {
        bool force;
        bool list;
        bool sum;
        bool send;
        bool pay;
        bool request;
        bool update;
        double amount;
        string output_filename;
    }

    enum update_tag = "update";
    void operate(Switch wallet_switch, const(string[]) args) {
        if (secure_wallet.isLoggedin) {
            with (wallet_switch) {
                bool save_wallet;
                scope (success) {
                    if (save_wallet) {
                        save(false);
                    }
                }
                if (amount !is amount.init) {
                    const bill = secure_wallet.requestBill(amount.TGN);
                    output_filename = (output_filename.empty) ? "bill".setExtension(FileExtension.hibon) : output_filename;
                    output_filename.fwrite(bill);
                    writefln("%1$sCreated %3$s%2$s of %4$s", GREEN, RESET, output_filename, bill.value.toString);
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
                            bill = secure_wallet.account.requested.get(Pubkey(index), TagionBill.init); /// Find bill by owner key     

                            if (bill is TagionBill.init) {
                                // Find bill by fingerprint 
                                bill = secure_wallet.account.requested.byValue
                                    .filter!(b => index == secure_wallet.net.dartIndex(b))
                                    .doFront;

                            }

                        }
                        if (bill !is TagionBill.init) {
                            writefln("%s", toText(bill));
                            verbose("%s", show(bill));
                            secure_wallet.addBill(bill);
                            save_wallet = true;
                        }
                    }
                }
                if (list) {
                    listAccount(stdout);
                    sum = true;
                }
                if (sum) {
                    sumAccount(stdout);
                }
                if (request) {
                    secure_wallet.account.requested.byValue
                        .each!(bill => secure_wallet.net.dartIndex(bill)
                                .encodeBase64.setExtension(FileExtension.hibon).fwrite(bill));
                }
                if (update) {
                    const fingerprints = [secure_wallet.account.bills, secure_wallet.account.requested.values]
                        .joiner
                        .map!(bill => secure_wallet.net.dartIndex(bill))
                        .array;
                    const update_net = secure_wallet.net.derive(update_tag.representation);
                    const hirpc = HiRPC(update_net);
                    const dartcheckread = dartCheckRead(fingerprints, hirpc);

                    if (output_filename !is string.init) {
                        output_filename.fwrite(dartcheckread);
                    }
                    if (send) {
                        auto received_doc = sendDARTHiRPC(options.dart_address, dartcheckread);
                        check(received_doc.isRecord!(HiRPC.Receiver), "Error in response. Aborting");
                        auto receiver = hirpc.receive(received_doc);
                        auto res = secure_wallet.setResponseCheckRead(receiver);
                        writeln(res ? "wallet updated succesfully" : "wallet not updated succesfully");
                        listAccount(stdout);
                        save_wallet=true;
                    }
                    
                }
                if (pay) {
                    SignedContract signed_contract;
                    TagionBill[] to_pay = args[1 .. $]
                        .filter!(file => file.hasExtension(FileExtension.hibon))
                        .map!(file => file.fread)
                        .map!(doc => TagionBill(doc))
                        .array;
                    TagionCurrency fees;
                    auto created_payment = secure_wallet.createPayment(to_pay, signed_contract, fees);
                    check(created_payment, "payment was not successful");

                    output_filename = (output_filename.empty && !send) ? "submit".setExtension(FileExtension.hibon) : output_filename;
                    const message = secure_wallet.net.calcHash(signed_contract);
                    pragma(msg, "Message ", typeof(message));
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
                        sendSubmitHiRPC(options.contract_address, hirpc_submit);
                    }
                }
            }
        }
    }
}
