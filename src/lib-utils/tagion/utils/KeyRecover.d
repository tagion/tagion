module tagion.utils.KeyRecover;

import tagion.gossip.InterfaceNet : HashNet;
import tagion.utils.Miscellaneous : xor;
import tagion.basic.Basic : Buffer;
import tagion.basic.Message;
import tagion.gossip.GossipNet : scramble;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.basic.Basic : basename;

import std.exception : assumeUnique;
import std.string : representation;
import std.range : lockstep, StoppingPolicy, indexed, iota;
import std.algorithm.mutation : copy;
import std.algorithm.iteration : map, filter;
import std.array : array;

import tagion.basic.TagionExceptions : Check, TagionException;

//import std.stdio;
import tagion.utils.Miscellaneous : toHexString;

/++
 + Exception type used by for key-recovery module
 +/
@safe
class KeyRecorverException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}

alias check=Check!KeyRecorverException;


@safe
struct KeyRecover {
    enum MAX_QUESTION = 10;
    enum MAX_SEEDS = 64;
    struct RecoverSeed {
        Buffer[] Y; /// Recorvery seed
        Buffer S;   /// Check value S=H(H(R))
        @Label("N") uint confidence;
        mixin HiBONRecord;
    }
    const HashNet net;
    protected RecoverSeed seed;

    this(HashNet net) {
        this.net=net;
    }

    this(HashNet net, Document doc) {
        this.net=net;
        seed=RecoverSeed(doc);
    }

    HiBON toHiBON() const {
        return seed.toHiBON;
    }

    /++
     Generates the quiz hash of the from a list of questions and answers
     +/
    @trusted
    Buffer[] quiz(const(string[]) questions, const(string[]) answers) const
        in {
            assert(questions.length is answers.length);
        }
    do {
        auto results=new Buffer[questions.length];
        foreach(ref result, question, answer;
            lockstep(results, questions, answers, StoppingPolicy.requireSameLength)) {
            result = net.calcHash(
                net.calcHash(answer.strip_down.representation) ~
                net.calcHash(question.strip_down.representation));
        }
        return results;
    }

    static uint numberOfSeeds(const uint M, const uint N)
        in {
            assert(M >= N);
            assert(M <= 10);
        }
    do {
        return (M-N)*N+1;
    }

    static unittest {
        assert(numberOfSeeds(10, 5) is 26);
    }

    Buffer checkHash(scope const(ubyte[]) value) const {
        return net.calcHash(net.calcHash(value));
    }

    static void iterateSeeds(
        const uint M, const uint N,
        scope bool delegate(scope const(uint[]) indices) @safe dg) {
        scope include=new uint[N];
        iota(N).copy(include);
        bool end;
        void local_search(const int index, const int size) @safe {
            if ((index >= 0) && !end ) {
                if (dg(include)) {
                    end=true;
                }
                else {
                    if (include[index] < size) {
                        include[index]++;
                        local_search(index, size);
                    }
                    else if (index > 0) {
                        include[index-1]++;
                        local_search(index-1, size-1);
                    }
                }
            }
        }
        local_search(cast(int)include.length-1, M-1);
    }

    void createKey(const(string[]) questions, const(string[]) answers, const uint confidence) {
        createKey(quiz(questions, answers), confidence);
    }

    void createKey(Buffer[] A, const uint confidence) {
        scope R=new ubyte[net.hashSize];
        scramble(R);
        scope(exit) {
            scramble(R);
        }
        quizSeed(R, A, confidence);
    }

    /++
     Generates the quiz seed values from the privat key R and the quiz list
     +/
    void quizSeed(scope ref const(ubyte[]) R, Buffer[] A, const uint confidence) {
        scope(success) {
            seed.confidence=confidence;
            seed.S = checkHash(R);
        }
        scope(failure) {
            seed.Y=null;
            seed.S=null;
            seed.confidence=0;
        }
        .check(A.length > 1, message("Number of questions must be more than one"));
        .check(confidence <= A.length, message("Number qustions must be lower than or equal to the confidence level (M=%d and N=%d)",
                A.length, confidence));
        .check(A.length <= MAX_QUESTION, message("Mumber of question is %d but it should not exceed %d",
                A.length, MAX_QUESTION));
        const number_of_questions=cast(uint)A.length;
        const seeds = numberOfSeeds(number_of_questions, confidence);
        .check(seeds <= MAX_SEEDS, message("Number quiz-seeds is %d which exceed that max value of %d",
                seeds, MAX_SEEDS));
        seed.Y=new Buffer[seeds];
        uint count;
        bool calculate_this_seeds(scope const(uint[]) indices) {
            scope list_of_selected_answers_and_the_secret=indexed(A, indices);
            seed.Y[count] = xor(R, xor(list_of_selected_answers_and_the_secret));
            count++;
            return false;
        }
        iterateSeeds(number_of_questions, confidence, &calculate_this_seeds);
    }

    bool findSecret(scope ref ubyte[] R, const(string[]) questions, const(string[]) answers) const {
        return findSecret(R, quiz(questions, answers));
    }

    bool findSecret(scope ref ubyte[] R, Buffer[] A) const {
        .check(A.length > 1, message("Number of questions must be more than one"));
        .check(seed.confidence <= A.length,
            message("Number qustions must be lower than or equal to the confidence level (M=%d and N=%d)",
                A.length, seed.confidence));
        const number_of_questions=cast(uint)A.length;
        const seeds = numberOfSeeds(number_of_questions, seed.confidence);
        .check(seed.Y.length == seeds, message("Number of answers does not match the number of quiz seeds"));
        bool result;
        bool search_for_the_secret(scope const(uint[]) indices) {
            scope list_of_selected_answers_and_the_secret=indexed(A, indices);
            const guess = xor(list_of_selected_answers_and_the_secret);
            foreach(y; seed.Y) {
                xor(R, y, guess);
                if (seed.S == checkHash(R)) {
                    result=true;
                    return true;
                }
            }
            return false;
        }
        iterateSeeds(number_of_questions, seed.confidence, &search_for_the_secret);
        return result;
    }
}

string strip_down(string text)
    out(result) {
        assert(result.length > 0);
        }
do {
    import std.ascii : toLower, isAlphaNum;
    return assumeUnique(
        text
        .map!(c => cast(char)toLower(c))
        .filter!(c => isAlphaNum(c))
        .array);
}

static shared string[] standard_questions;

shared static this() {
    standard_questions=[
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
    import tagion.gossip.GossipNet : StdHashNet;
    import std.array : join;
    auto selected_questions=indexed(standard_questions, [0,2,3,7,8]).array.idup;
    //pragma(msg, typeof(selected_questions));
    //writefln("%s", selected_questions.join("\n"));
    string[] answers=[
        "mobidick",
        "Mother Teresa!",
        "Pluto",
        "Pizza",
        "Maputo"
        ];
    auto net=new StdHashNet;
    auto recover=KeyRecover(net);
    recover.createKey(selected_questions, answers, 3);



    auto R=new ubyte[net.hashSize];

    { // All the ansers are correct
        const result = recover.findSecret(R, selected_questions, answers);
        //writefln("R=%s", R.toHexString);
        assert(R.length == net.hashSize);
        assert(result); // Password found
    }

    { // 3 out of 5 answers are correct. This is a valid answer to generate the secret key
        string[] good_answers=[
            "MobiDick",
            "MOTHER TERESA",
            "Fido",
            "pizza",
            "Maputo"
        ];
        auto goodR=new ubyte[net.hashSize];
        const result = recover.findSecret(goodR, selected_questions, good_answers);
        assert(R.length == net.hashSize);
        assert(result); // Password found
        assert(R == goodR);
    }

    { // 2 out of 5 answers are correct. This is NOT a valid answer to generate the secret key
        string[] bad_answers=[
            "mobidick",
            "Monalisa",
            "Fido",
            "Burger",
            "Maputo"
        ];
        auto badR=new ubyte[net.hashSize];
        const result = recover.findSecret(badR, selected_questions, bad_answers);
        assert(!result); // Password not found
        assert(R != badR);

    }
}
