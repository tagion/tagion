module tagion.betterC.wallet.WalletRecords;

import tagion.betterC.hibon.HiBON;
import tagion.betterC.hibon.Document : Document;
import tagion.betterC.wallet.KeyRecover : KeyRecover;
import tagion.basic.Basic : Buffer, Pubkey, Signature, basename;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.BinBuffer;

import tagion.betterC.funnel.TagionCurrency;
// import tagion.script.StandardRecords : StandardBill;

struct RecordType {
    string name;
    string code; // This is is mixed after the Document constructor
}

struct Label {
    string name; /// Name of the HiBON member
    bool optional; /// This flag is set to true if this paramer is optional
}

enum VOID = "*";

template GetLabel(alias member) {
    import std.traits : getUDAs, hasUDA;

    static if (hasUDA!(member, Label)) {
        enum label = getUDAs!(member, Label)[0];
        static if (label.name == VOID) {
            enum GetLabel = Label(basename!(member), label.optional);
        }
        else {
            enum GetLabel = label;
        }
    }
    else {
        enum GetLabel = Label(basename!(member));
    }
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
            hibon["$Q"] = tmp_arr;
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
        struct AccountDetails {
        @Label("$derives") Buffer[Pubkey] derives;
        @Label("$bills") StandardBill[] bills;
        @Label("$state") BinBuffer derive_state;
        @Label("$active") bool[Pubkey] activated; /// Actived bills
        import std.algorithm : map, sum, filter, any, each;

        this(Document doc) {
            // auto received__derives = doc["derives"].get!Buffer;
            // derives = received__derives[Pubkey];

            auto received_bills = doc["bills"].get!Document;
            bills.create(received_bills.length);
            foreach (element; received_bills[])
            {
                // bills[element.index] = element.get!StandardBill;
            }
            // derive_state = doc["state"].get!Buffer;
            // owner = doc["Y"].get!Pubkey;
            // gene = doc["G"].get!Buffer;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }

        bool remove_bill(Pubkey pk) {
            import std.algorithm : remove, countUntil;

            const index = countUntil!"a.owner == b"(bills, pk);
            if (index > 0) {
                bills = bills.remove(index);
                return true;
            }
            return false;
        }

        void add_bill(StandardBill bill) {
            bills.resize(bills.length + 1);
            bills[$ - 1] = bill;
        }

        /++
         Clear up the Account
         Remove used bills
         +/
        void clearup() pure {
            // bills
            //     .filter!(b => b.owner in derives)
            //     .each!(b => derives.remove(b.owner));
            // bills
            //     .filter!(b => b.owner in activated)
            //     .each!(b => activated.remove(b.owner));
        }

        const pure {
            /++
         Returns:
         true if the all transaction has been registered as processed
         +/
            bool processed() {
                bool res = false;
                foreach (bill; bills)
                {
                    // if (bill.owner in activated) {
                //         res = true;
                //     }
                }
                return res;
            }
            /++
         Returns:
         The available balance
         +/
            // TagionCurrency available() {
                // return bills
                //     // .filter!(b => !(b.owner in activated))
                //     .map!(b => b.value)
                //     .sum;
            // }
            /++
        //  Returns:
        //  The total active amount
        //  +/
        //     TagionCurrency active() {
        //         return bills
        //             .filter!(b => b.owner in activated)
        //             .map!(b => b.value)
        //             .sum;
        //     }
        //     /++
        //  Returns:
        //  The total balance including the active bills
        //  +/
            // TagionCurrency total() {
            //     return bills
            //         .map!(b => b.value)
            //         .sum;
            // }
        }
    }
        @RecordType("BIL") struct StandardBill {
        @Label("$V") TagionCurrency value; // Bill type
        @Label("$k") uint epoch; // Epoch number
        //        @Label("$T", true) string bill_type; // Bill type
        @Label("$Y") Pubkey owner; // Double hashed owner key
        @Label("$G") Buffer gene; // Bill gene
        this(Document doc) {
            // value = doc["Y"].get!TagionCurrency;
            epoch = doc["k"].get!uint;
            // owner = doc["Y"].get!Pubkey;
            gene = doc["G"].get!Buffer;
        }

        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            // hibon["V"] = value;
            hibon["k"] = epoch;
            // hibon["Y"] = owner;
            hibon["G"] = gene;
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }
        @RecordType("Invoice") struct Invoice {
        string name;
        TagionCurrency amount;
        Pubkey pkey;
        @Label("*", true) Document info;
        this(Document doc) {
        }
        inout(HiBONT) toHiBON() inout {
            auto hibon = HiBON();
            return cast(inout) hibon;
        }

        const(Document) toDoc() {
            return Document(toHiBON.serialize);
        }
    }
        @RecordType("SMC") struct Contract {
        @Label("$in") Buffer[] input; /// Hash pointer to input (DART)
        @Label("$read", true) Buffer[] read; /// Hash pointer to read-only input (DART)
        @Label("$out") Document[Pubkey] output; // pubkey of the output
        @Label("$run") Script script; // TVM-links / Wasm binary
        bool verify() {
            return (input.length > 0);
        }
    }

    @RecordType("SSC") struct SignedContract {
        @Label("$signs") Signature[] signs; /// Signature of all inputs
        @Label("$contract") Contract contract; /// The contract must signed by all inputs
        @Label("$in", true) Document input; /// The actual inputs
    }
        struct Script {
        @Label("$name") string name;
        @Label("$env", true) Buffer link; // Hash pointer to smart contract object;
        // mixin HiBONRecord!(
        //         q{
        //         this(string name, Buffer link=null) {
        //             this.name = name;
        //             this.link = link;
        //         }
        //     });
        // bool verify() {
        //     return (wasm.length is 0) ^ (link.empty);
        // }

    }
}


