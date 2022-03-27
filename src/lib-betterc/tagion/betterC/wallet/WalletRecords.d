module tagion.betterC.wallet.WalletRecords;

import tagion.betterC.hibon.HiBON;
import tagion.betterC.hibon.Document : Document;
import tagion.betterC.wallet.KeyRecover : KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;
import tagion.betterC.utils.Memory;

// import tagion.betterC.funnel.TagionCurrency;
// import tagion.script.StandardRecords : StandardBill;

struct RecordType {
    string name;
    string code; // This is is mixed after the Document constructor
}

struct Label {
    string name; /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional
}

@trusted {
    import std.algorithm;
    import std.array;

    @RecordType("Quiz")
    struct Quiz {
        @Label("$Q") string[] questions;
        this(Document doc) {
            auto received_questions = doc["$Q"].get!Document;
            questions.create(received_questions.length);
            // questions[0 .. $] = received_questions;
            // foreach (i, question; received_questions)
            // {
            //     questions[i] = question;
            // }
            // for (int i = 0; i < received_questions.length; i++) {
            //     questions[i] = received_questions[i];
            // }
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            // hibon["Q"] = questions;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            auto doc = Document(toHiBON.serialize);
            return cast(const) doc;
        }
    }

    @RecordType("PIN")
    struct DevicePIN {
        Buffer Y;
        Buffer check;

        this(Document doc) {
            Y = doc["Y"].get!Buffer;
            check = doc["C"].get!Buffer;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            hibon["Y"] = Y;
            hibon["C"] = check;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            auto doc = Document(toHiBON.serialize);
            return cast(const) doc;
        }
    }

    @RecordType("Wallet")
    struct RecoverGenerator {
        Buffer[] Y; /// Recorvery seed
        Buffer S; /// Check value S=H(H(R))
        @Label("N") uint confidence;
        import tagion.betterC.hibon.HiBON;

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            // hibon["Y"] = Y;
            hibon["S"] = S;
            hibon["N"] = confidence;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            auto doc = Document(toHiBON.serialize);
            return cast(const) doc;
        }

        this(Document doc) {
            auto Y_data = doc["Y"].get!Document;
            // Y = Y_data[]
            //     .map!(a => a.get!Buffer)
            //     .array.dup;
            S = doc["S"].get!Buffer;
            confidence = doc["N"].get!uint;
        }
        // mixin HiBONRecord;
    }

}
