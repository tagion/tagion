module tagion.tools.geldbeutel;
import core.thread;
import std.format;
import std.getopt;
import std.stdio;
import std.array;
import std.path;
import std.file : exists, mkdir;
import tagion.hibon.HiBONRecord : fwrite, fread;
import std.algorithm;
import std.range;
import tagion.utils.JSONCommon;
import tagion.tools.revision;
import tagion.tools.Basic;
import tagion.basic.Types : FileExtension;
import tagion.wallet.KeyRecover;
import tagion.utils.Term;
import tagion.wallet.SecureWallet;
import tagion.wallet.WalletRecords;
import tagion.wallet.AccountDetails;
import tagion.basic.Message;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;

mixin Main!(_main, "newwallet");

import tagion.crypto.SecureNet;

import Wallet = tagion.wallet.SecureWallet;

/**
 * @brief build file path if needed file with folder long path
 * @param file - input/output parameter with filename
 * @param path - forlders destination to file
 */
@safe
static void set_path(ref string file, string path) {
    file = buildPath(path, file.baseName);
}
/**
*
 * \struct WalletOptions
 * Struct wallet options files and network status storage models
 */
struct WalletOptions {
    /** account file name/path */
    string accountfile;
    /** wallet file name/path */
    string walletfile;
    /** questions file name/path */
    string quizfile;
    /** device file name/path */
    string devicefile;
    /** contract file name/path */
    string contractfile;
    /** bills file name/path */
    string billsfile;
    /** payments request file name/path */
    string paymentrequestsfile;
    /** address part of network socket */
    string addr;
    /** port part of network socket */
    ushort port;

    /**
    * @brief set default values for wallet
    */
    void setDefault() pure nothrow {
        accountfile = "account".setExtension(FileExtension.hibon);
        walletfile = "wallet".setExtension(FileExtension.hibon);
        quizfile = "quiz".setExtension(FileExtension.hibon);
        contractfile = "contract".setExtension(FileExtension.hibon);
        billsfile = "bills".setExtension(FileExtension.hibon);
        paymentrequestsfile = "paymentrequests".setExtension(FileExtension.hibon);
        devicefile = "device".setExtension(FileExtension.hibon);
        addr = "localhost";
        port = 10800;
    }

    mixin JSONCommon;
    mixin JSONConfig;
}
/**
 * @brief strip white spaces in begin/end of text
 * @param word - input parameter with out
 * \return dublicate out parameter
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

    /**
    * @brief pseudographical UI interface, pin code reading
    * \return Check pin code result
    */
    bool loginPincode() {
        CLEARSCREEN.write;
        foreach (i; 0 .. 3) {
            HOME.write;
            writefln("%1$sAccess code required%2$s", GREEN, RESET);
            writefln("%1$sEnter empty pincode to proceed recovery%2$s", YELLOW, RESET);
            writefln("pincode:");
            char[] pincode;
            scope (exit) {
                scramble(pincode);
            }
            readln(pincode);
            pincode.word_strip;
            //writefln("pincode.length=%d", pincode.length);
            if (pincode.length) {
                secure_wallet.login(pincode);
                if (secure_wallet.isLoggedin) {
                    return true;
                }
                writefln("%1$sWrong pincode%2$s", RED, RESET);
            }
            else {

                //                writefln("quiz.questions=%s", quiz.questions);
                generateSeed(quiz.questions, true);
                return secure_wallet.isLoggedin;
            }
        }
        CLEARSCREEN.write;
        return false;
    }

    /**
    * @brief wallet pseudographical UI interface
    */
    void accountView() {

        enum State {
            CREATE_ACCOUNT,
            WAIT_LOGIN,
            LOGGEDIN
        }

        State state;

        int ch;
        KeyStroke key;
        CLEARSCREEN.write;
        while (ch != 'q') {
            HOME.write;
            warning();
            writefln(" Account overview ");

            LINE.writeln;
            const processed = secure_wallet.account.processed;
            if (!processed) {
                writefln("                                 available %s", secure_wallet
                        .account.available);
                writefln("                                    locked %s", secure_wallet
                        .account.locked);
            }
            (processed ? GREEN : RED).write;
            writefln("                                     total %s", secure_wallet.account.total);
            RESET.write;
            LINE.writeln;
            with (State) final switch (state) {
            case CREATE_ACCOUNT:
                if (secure_wallet.isLoggedin) {
                    writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sp%2$s:change pin%3$s", FKEY, RESET, CLEARDOWN);
                }
                else {
                    writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sc%2$s:create%3$s", FKEY, RESET, CLEARDOWN);
                }
                break;
            case WAIT_LOGIN:
                writefln("Pincode:%s", CLEARDOWN);
                //char[MAX_PINCODE_SIZE] stack_pincode;
                char[] pincode;
                pincode.length = MAX_PINCODE_SIZE;
                readln(pincode);
                //pincode = pincode[0..size];
                word_strip(pincode);
                scope (exit) {
                    //pincode = stack_pincode;
                    scramble(pincode);
                }
                secure_wallet.login(pincode);
                if (secure_wallet.isLoggedin) {
                    state = LOGGEDIN;
                    continue;
                }
                else {
                    writefln("%sWrong pin%s", RED, RESET);
                    writefln("Press %sEnter%s", YELLOW, RESET);
                }
                break;
            case LOGGEDIN:
                writefln("%1$sq%2$s:quit %1$sa%2$s:account %1$sr%2$s:recover%3$s", FKEY, RESET, CLEARDOWN);
                break;
            }
            CLEARDOWN.writeln;
            const keycode = key.getKey(ch);
            switch (ch) {
            case 'a':
                if (options.walletfile.exists) {
                    version (none)
                        accounting;
                }
                else {
                    writeln("Account doesn't exists");
                    Thread.sleep(1.seconds);
                }
                break;
            case 'c':
                if (!secure_wallet.isLoggedin) {
                    generateSeed(standard_questions.idup, false);
                }
                break;
            case 'p':
                changePin;
                break;
            default:
                // ignore
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

    /**
    * @brief chenge pin code interface
    */
    void changePin() {
        CLEARSCREEN.write;
        if (secure_wallet.isLoggedin) {
            foreach (i; 0 .. 3) {
                HOME.write;
                CLEARSCREEN.write;
                scope (success) {
                    CLEARSCREEN.write;
                }
                writeln("Change you pin code");
                LINE.writeln;
                if (secure_wallet.pin.D) {
                    char[] old_pincode;
                    char[] new_pincode1;
                    char[] new_pincode2;
                    scope (exit) {
                        // Scramble the code to prevent memory leaks
                        old_pincode.scramble;
                        new_pincode1.scramble;
                        new_pincode2.scramble;
                    }
                    writeln("Current pincode:");
                    readln(old_pincode);
                    old_pincode.word_strip;
                    //            secure_wallet.login(old_pincode);
                    if (secure_wallet.checkPincode(old_pincode)) {
                        writefln("%1$sCorrect pin%2$s", GREEN, RESET);
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
                                return;
                            }
                            else {
                                writefln("%1$sPincode to short or does not match%2$s", RED, RESET);
                            }
                        }
                        while (!ok);
                    }
                    else {
                        writefln("%1$sWrong pin%2$s", GREEN, RESET);
                        pressKey;
                    }
                    return;
                }
                writefln("%1$sPin code is missing. You need to recover you keys%2$s", RED, RESET);
            }
        }
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
            warning();
            if (recover_flag) {
                writefln("Recover account");
                writefln("Answers %d to more of the questions below", confidence);
            }
            else {
                writefln("Create a new account");
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
                            writefln("%1$sThen number of answers must be more than %4$d%2$s%3$s", RED, RESET, CLEAREOL, selected_answers
                                    .length);
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
                                    writefln("%1$sPincode must be less than %3$d chars%2$s", RED, RESET, pincode1
                                            .length);
                                }
                                else {
                                    if (recover_flag) {
                                        const ok = secure_wallet.recover(quiz.questions, selected_answers, pincode1);
                                        if (ok) {
                                            writefln("%1$sWallet recovered%2$s", GREEN, RESET);
                                        }
                                        else {
                                            writefln("%1$sWallet NOT recovered%2$s", RED, RESET);
                                        }
                                        options.walletfile.fwrite(secure_wallet.wallet);
                                        options.devicefile.fwrite(secure_wallet.pin);
                                    }
                                    else {
                                        secure_wallet = StdSecureWallet.createWallet(quiz.questions, selected_answers, confidence, pincode1);
                                        secure_wallet.login(pincode1);
                                        options.walletfile.fwrite(secure_wallet.wallet);
                                        options.devicefile.fwrite(secure_wallet.pin);
                                        options.quizfile.fwrite(quiz);

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
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool overwrite_switch; /// Overwrite the config file
    bool create_account;
    bool change_pin;
    bool set_default_quiz;
    string path;
    string pincode;
    bool wallet_ui;
    GetoptResult main_args;
    WalletOptions options;
    auto config_file = "wallet.json";
    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "overwrite|O", "Overwrite the config file and exits", &overwrite_switch,
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "C|create", "Create a new account", &create_account,
                "c|changepin", "Change pin-code", &change_pin,//"questions", "Questions for wallet creation", &questions_str,
                //"answers", "Answers for wallet creation", &answers_str,
                /*
                "path", format("Set the path for the wallet files : default %s", path), &path,
                "wallet", format("Wallet file : default %s", options.walletfile), &options.walletfile,
                "device", format("Device file : default %s", options.devicefile), &options.devicefile,
                "quiz", format("Quiz file : default %s", options.quizfile), &options.quizfile,
                "invoice|i", format("Invoice file : default %s", invoicefile), &invoicefile,
                "create-invoice|c", "Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000", &create_invoice_command,
                "contract|t", format("Contractfile : default %s", options.contractfile), &options.contractfile,
                "send|s", "Send contract to the network", &send_flag,
                "amount", "Display the wallet amount", &print_amount,
                "pay|I", format("Invoice to be payed : default %s", payfile), &payfile,
                "update|U", "Update your wallet", &update_wallet,
                "item|m", "Invoice item select from the invoice file", &item,
                "pin|x", "Pincode", &pincode,
                "port|p", format("Tagion network port : default %d", options.port), &options.port,
                "url|u", format("Tagion url : default %s", options.addr), &options.addr,
                "visual|g", "Visual user interface", &wallet_ui,
                "questions", "Questions for wallet creation", &questions_str,
                "answers", "Answers for wallet creation", &answers_str,
                "generate-wallet", "Create a new wallet", &generate_wallet,
                "health", "Healthcheck the node", &check_health,
                "unlock", "Remove lock from all local bills", &unlock_bills,
                "nossl", "Disable ssl encryption", &none_ssl_socket,
    */
        
        );
    }
    catch (GetOptException e) {
        stderr.writeln(e.msg);
        return 1;
    }
    if (version_switch) {
        revision_text.writeln;
        return 0;
    }
    if (main_args.helpWanted) {
        //            writeln(logo);
        defaultGetoptPrinter(
                [
                // format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <config.json> <files>", program),
                "",

                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }
    auto wallet_interface = WalletInterface(options);
    if (create_account) {
        wallet_interface.generateSeed(standard_questions.idup, false);
    }
    else if (change_pin) {
        wallet_interface.changePin;
    }
    const new_config = (!config_file.exists || overwrite_switch);
    if (path) {
        if (!new_config) {
            writefln("To change the path you need to use the overwrite switch -O");
            return 10;
        }
        options.walletfile.set_path(path);
        options.quizfile.set_path(path);
        options.devicefile.set_path(path);
        options.accountfile.set_path(path);
        options.billsfile.set_path(path);
        options.paymentrequestsfile.set_path(path);
        const dir = options.walletfile.dirName;
        if (!dir.exists) {
            dir.mkdir;
        }
    }
    if (new_config) {
        options.save(config_file);
        if (overwrite_switch) {
            return 0;
        }
    }
    if (options.walletfile.exists) {
        Document wallet_doc;
        try {
            wallet_doc = options.walletfile.fread;
        }
        catch (TagionException e) {
            writeln(e.msg);
            return 1;
        }
        const pin_doc = options.devicefile.exists ? options.devicefile.fread : Document.init;
        if (wallet_doc.isInorder && pin_doc.isInorder) {
            try {
                wallet_interface.secure_wallet = WalletInterface.StdSecureWallet(wallet_doc, pin_doc);
            }
            catch (TagionException e) {
                writefln(e.msg);
                return 1;
            }
        }
        if (options.quizfile.exists) {
            const quiz_doc = options.quizfile.fread;
            if (quiz_doc.isInorder) {
                wallet_interface.quiz = Quiz(quiz_doc);
            }
        }
    }
    else {
        wallet_ui = true;
        writefln("Wallet dont't exists");
        WalletInterface.pressKey;
        wallet_interface.quiz.questions = standard_questions.dup;
    }

    if (wallet_interface.secure_wallet != WalletInterface.StdSecureWallet.init) {
        if (pincode) {
            const flag = wallet_interface.secure_wallet.login(pincode);
            if (!flag) {
                stderr.writefln("%sWrong pincode%s", RED, RESET);
                return 3;
            }
            //   wallet_ui = true;
        }
        else if (!wallet_interface.loginPincode) {
            wallet_ui = true;
            writefln("Wallet not loggedin");
            WalletInterface.pressKey;

            return 4;
        }
    }

    return 0;
}
