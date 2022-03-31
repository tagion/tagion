module tagion.betterC.wallet.WalletRecords;

import tagion.betterC.hibon.HiBON;
import tagion.betterC.hibon.Document : Document;
import tagion.betterC.wallet.KeyRecover : KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey;
import tagion.betterC.utils.Memory;

// import\ tagion.betterC.funnel.TagionCurrency;
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
            foreach (element; received_questions[])
            {
                questions[element.index] = element.get!string;
            }
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            auto tmp_arr = HiBON();
            foreach (i, question; questions)
            {
                tmp_arr[i] = question;
            }
            // GetLabel
            hibon["Q"] = tmp_arr;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
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
            return Document(toHiBON.serialize);
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
            auto tmp_arr = HiBON();
            foreach (i, y; Y)
            {
                tmp_arr[i] = y;
            }
            tmp_arr["S"] = S;
            tmp_arr["N"] = confidence;
            hibon = tmp_arr;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        this(Document doc) {
            auto Y_data = doc["Y"].get!Document;
            Y.create(Y_data.length);
            foreach (element; Y_data[])
            {
                Y[element.index] = element.get!Buffer;
            }
            S = doc["S"].get!Buffer;
            confidence = doc["N"].get!uint;
        }
    }

}
