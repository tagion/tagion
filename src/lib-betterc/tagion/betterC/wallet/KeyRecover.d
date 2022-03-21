/// \file KeyRecover.d

module tagion.betterC.wallet.KeyRecover;

//use net directly
import tagion.betterC.wallet.Net;

import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.SecureNet : scramble, StdSecureNet;
import tagion.utils.Miscellaneous : xor;
import tagion.basic.Basic : Buffer;
import tagion.basic.Message;
import tagion.betterC.utils.Memory;

// use better C doc, hibon, hibon record 
import tagion.betterC.hibon.HiBON : HiBONT;
import tagion.betterC.hibon.Document : Document;

// import tagion.betterC.hibon.HiBONRecord;
// import tagion.hibon.HiBONRecord;

import std.exception : assumeUnique;
import std.string : representation;
import std.range : lockstep, StoppingPolicy, indexed, iota;
import std.algorithm.mutation : copy;
import std.algorithm.iteration : map, filter;
import std.array : array;

import tagion.basic.TagionExceptions : Check, TagionException;
import tagion.betterC.wallet.WalletRecords : RecoverGenerator;

@safe
@nogc
struct KeyRecover {
    enum MAX_QUESTION = 10;
    enum MAX_SEEDS = 64;
    protected RecoverGenerator generator;

    this(RecoverGenerator generator) {
        this.generator = generator;
    }

    inout(HiBONT) toHiBON() inout {
        return generator.toHiBON;
    }

    const(Document) toDoc() {
        return generator.toDoc;
    }

    /**
     * Generates the quiz hash of the from a list of questions and answers
     */
    Buffer[] quiz(scope const(string[]) questions, scope const(char[][]) answers) const @trusted
    in {
        assert(questions.length is answers.length);
    }
    do {

        // auto results = new Buffer[questions.length];
        Buffer[] results;
        results.create(questions.length);

        foreach (ref result, question, answer; lockstep(results, questions, answers, StoppingPolicy
                .requireSameLength)) {
            scope strip_down = cast(ubyte[]) answer.strip_down;
            scope (exit) {
                strip_down.scramble;
            }
            const hash = calcHash(strip_down);
            result = calcHash(hash ~ hash);
        }
        return results;
    }

    @nogc
    static uint numberOfSeeds(const uint M, const uint N) pure nothrow
    in {
        assert(M >= N);
        assert(M <= 10);
    }
    do {
        return (M - N) * N + 1;
    }

    @nogc
    static unittest {
        assert(numberOfSeeds(10, 5) is 26);
    }

    Buffer checkHash(scope const(ubyte[]) value) const {
        return rawCalcHash(rawCalcHash(value));
    }

    static void iterateSeeds(
            const uint M, const uint N,
            scope bool delegate(scope const(uint[]) indices) @safe dg) {
        // scope include = new uint[N];
        scope uint[] include;
        include.create(N);
        iota(N).copy(include);
        bool end;
        void local_search(const int index, const int size) @safe {
            if ((index >= 0) && !end) {
                if (dg(include)) {
                    end = true;
                }
                else {
                    if (include[index] < size) {
                        include[index]++;
                        local_search(index, size);
                    }
                    else if (index > 0) {
                        include[index - 1]++;
                        local_search(index - 1, size - 1);
                    }
                }
            }
        }

        local_search(cast(int) include.length - 1, M - 1);
    }

    void createKey(scope const(string[]) questions, scope const(char[][]) answers, const uint confidence) {
        createKey(quiz(questions, answers), confidence);
    }

    void createKey(Buffer[] A, const uint confidence) {
        // scope R = new ubyte[hashSize];
        scope ubyte[] R;
        R.create(hashSize);
        scramble(R);
        scope (exit) {
            scramble(R);
        }
        quizSeed(R, A, confidence);
    }

    /**
     * Generates the quiz seed values from the privat key R and the quiz list
     */
    void quizSeed(scope ref const(ubyte[]) R, Buffer[] A, const uint confidence) {
        scope (success) {
            generator.confidence = confidence;
            generator.S = checkHash(R);
        }
        scope (failure) {
            generator.Y = null;
            generator.S = null;
            generator.confidence = 0;
        }
        const number_of_questions = cast(uint) A.length;
        const seeds = numberOfSeeds(number_of_questions, confidence);

        // generator.Y = new Buffer[seeds];
        generator.Y.create(seeds);
        uint count;
        bool calculate_this_seeds(scope const(uint[]) indices) {
            scope list_of_selected_answers_and_the_secret = indexed(A, indices);
            generator.Y[count] = xor(R, xor(list_of_selected_answers_and_the_secret));
            count++;
            return false;
        }

        iterateSeeds(number_of_questions, confidence, &calculate_this_seeds);
    }

    bool findSecret(scope ref ubyte[] R, scope const(string[]) questions, scope const(char[][]) answers) const {
        return findSecret(R, quiz(questions, answers));
    }

    bool findSecret(scope ref ubyte[] R, Buffer[] A) const {
        const number_of_questions = cast(uint) A.length;
        const seeds = numberOfSeeds(number_of_questions, generator.confidence);

        bool result;
        bool search_for_the_secret(scope const(uint[]) indices) {
            scope list_of_selected_answers_and_the_secret = indexed(A, indices);
            const guess = xor(list_of_selected_answers_and_the_secret);
            foreach (y; generator.Y) {
                xor(R, y, guess);
                if (generator.S == checkHash(R)) {
                    result = true;
                    return true;
                }
            }
            return false;
        }

        iterateSeeds(number_of_questions, generator.confidence, &search_for_the_secret);
        return result;
    }
}

char[] strip_down(const(char[]) text) pure @safe
out (result) {
    assert(result.length > 0);
}
do {
    import std.ascii : toLower, isAlphaNum;

    return text
        .map!(c => cast(char) toLower(c))
        .filter!(c => isAlphaNum(c))
        .array;
}

static immutable(string[]) standard_questions;

shared static this() {
    standard_questions = [
        "What is your favorite book?",
        "What is the name of the road you grew up on?",
        "What is your mother’s maiden name?",
        "What was the name of your first/current/favorite pet?",
        "What was the first company that you worked for?",
        "Where did you meet your spouse?",
        "Where did you go to high school/college?",
        "What is your favorite food?",
        "What city were you born in?",
        "Where is your favorite place to vacation?"
    ];
}

unittest {
    import tagion.crypto.SecureNet : StdHashNet;
    import std.array : join;

    auto selected_questions = indexed(standard_questions, [0, 2, 3, 7, 8]).array.idup;
    //pragma(msg, typeof(selected_questions));
    //writefln("%s", selected_questions.join("\n"));
    string[] answers = [
        "mobidick",
        "Mother Teresa!",
        "Pluto",
        "Pizza",
        "Maputo"
    ];
    KeyRecover recover;
    recover.createKey(selected_questions, answers, 3);

    // auto R = new ubyte[net.hashSize];
    ubyte[] R;
    R.create(hashSize);

    { // All the ansers are correct
        const result = recover.findSecret(R, selected_questions, answers);
        //writefln("R=%s", R.toHexString);
        assert(R.length == hashSize);
        assert(result); // Password found
    }

    { // 3 out of 5 answers are correct. This is a valid answer to generate the secret key
        string[] good_answers = [
            "MobiDick",
            "MOTHER TERESA",
            "Fido",
            "pizza",
            "Maputo"
        ];
        // auto goodR = new ubyte[hashSize];
        ubyte[] goodR;
        goodR.create(hashSize);
        const result = recover.findSecret(goodR, selected_questions, good_answers);
        assert(R.length == hashSize);
        assert(result); // Password found
        assert(R == goodR);
    }

    { // 2 out of 5 answers are correct. This is NOT a valid answer to generate the secret key
        string[] bad_answers = [
            "mobidick",
            "Monalisa",
            "Fido",
            "Burger",
            "Maputo"
        ];
        // auto badR = new ubyte[net.hashSize];
        ubyte[] badR;
        badR.create(hashSize);
        const result = recover.findSecret(badR, selected_questions, bad_answers);
        assert(!result); // Password not found
        assert(R != badR);

    }
}
