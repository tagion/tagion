module tagion.tools.wallet.WalletInterface;
import std.stdio;
import tagion.tools.wallet.WalletOptions;
import tagion.wallet.SecureWallet;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords;
import tagion.utils.Term;
import tagion.wallet.AccountDetails;
import tagion.crypto.SecureNet;
import std.file : exists, mkdir;
import tagion.hibon.HiBONRecord : fwrite, fread;
import std.algorithm;
import std.range;
import core.thread;
import tagion.basic.Message;
import tagion.basic.tagionexceptions;
import tagion.hibon.Document;
import std.typecons;

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
            Document wallet_doc;
            try {
                wallet_doc = options.walletfile.fread;
            }
            catch (TagionException e) {
                writeln(e.msg);
                return false;
            }
            const pin_doc = options.devicefile.exists ? options.devicefile.fread : Document.init;
            if (wallet_doc.isInorder && pin_doc.isInorder) {
                try {
                    secure_wallet = WalletInterface.StdSecureWallet(wallet_doc, pin_doc);
                }
                catch (TagionException e) {
                    writefln(e.msg);
                    return false;
                }
            }
            if (options.quizfile.exists) {
                const quiz_doc = options.quizfile.fread;
                if (quiz_doc.isInorder) {
                    quiz = Quiz(quiz_doc);
                    return true;
                }
            }
        }
        quiz.questions = options.questions.dup;
        return false;
    }

    void save(const(char[]) pincode, const bool recover_flag) {
        secure_wallet.login(pincode);

        if (secure_wallet.isLoggedin) {
            options.walletfile.fwrite(secure_wallet.wallet);
            options.devicefile.fwrite(secure_wallet.pin);
            if (!recover_flag) {
                options.quizfile.fwrite(quiz);
            }
        }
    }
    /**
    * @brief pseudographical UI interface, pin code reading
    * \return Check pin code result
    */
    version (none) bool loginPincode() {
        CLEARSCREEN.write;
        foreach (i; 0 .. 3) {
            HOME.write;
            writefln("%1$sAccess code required%2$s", GREEN, RESET);
            writefln("%1$sEnter empty pincode to proceed recovery%2$s", YELLOW, RESET);
            writefln("pincode:");
            char[] pincode;
            scope (exit) {
                pincode.scramble;
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
    version (none) void accountView() {

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
                char[] pincode;
                pincode.length = MAX_PINCODE_SIZE;
                readln(pincode);
                word_strip(pincode);
                scope (exit) {
                    scramble(pincode);
                }
                secure_wallet.login(pincode);
                if (secure_wallet.isLoggedin) {
                    state = LOGGEDIN;
                    continue;
                }
                else {
                    writefln("%sWrong pin%s", RED, RESET);
                    pressKey;
                    //writefln("Press %sEnter%s", YELLOW, RESET);
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
                    generateSeed(options.questions, false);
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
                                    writefln("%1$sPincode must be less than %3$d chars%2$s",
                                            RED, RESET, pincode1.length);
                                }
                                else {
                                    if (recover_flag) {
                                        const ok = secure_wallet.recover(quiz.questions, selected_answers, pincode1);
                                        if (ok) {
                                            writefln("%1$sWallet recovered%2$s", GREEN, RESET);
                                            save(pincode1, recover_flag);
                                        }
                                        else {
                                            writefln("%1$sWallet NOT recovered%2$s", RED, RESET);
                                        }
                                    }
                                    else {
                                        secure_wallet = StdSecureWallet.createWallet(
                                                quiz.questions, selected_answers, confidence, pincode1);
                                        save(pincode1, recover_flag);
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
