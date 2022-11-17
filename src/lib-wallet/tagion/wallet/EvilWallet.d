module tagion.wallet.EvilWallet;
import tagion.wallet.SecureWallet;

import std.format;
import std.string : representation;
import std.algorithm : map, max, min, sum, until, each, filter, cache;
import std.range : tee;
import std.array;
import std.exception : assumeUnique;
import core.time : MonoTime;
import std.conv : to;


//import std.stdio;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONException : HiBONRecordException;

import tagion.basic.Basic : basename;
import tagion.basic.Types : Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.crypto.SecureNet : scramble;
import tagion.crypto.SecureInterfaceNet : SecureNet;

// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.communication.HiRPC;
import tagion.wallet.KeyRecover;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN;
import tagion.wallet.WalletException : check;


@safe struct EvilWallet(Net) {
    SecureWallet!Net _securewallet;
    alias _securewallet this;

    bool evil_payment(const(Invoice[]) orders, ref SignedContract result, bool setfee, double fee)
    {
        checkLogin;
        const topay = orders.map!(b => b.amount).sum;

        // removed topay check.
        const size_in_bytes = 500;
        // todo set fee manually here.
        TagionCurrency fees;
        if (setfee) {
            fees = fee.to!double.TGN;
        } else {
            fees = globals.fees(topay, size_in_bytes); // 52.5
        }

        const amount = topay + fees; 
        StandardBill[] contract_bills;
        const enough = evil_collect_bills(amount, contract_bills); // change to always be true.
        if (enough)
        {
            const total = contract_bills.map!(b => b.value).sum;

            result.contract.inputs = contract_bills.map!(b => net.hashOf(b.toDoc)).array;
            const rest = total - amount;
            if (rest > 0)
            {
                Invoice money_back;
                money_back.amount = rest;
                registerInvoice(money_back);
                result.contract.output[money_back.pkey] = rest.toDoc;
            }
            orders.each!((o) {
                result.contract.output[o.pkey] = o.amount.toDoc;
            });
            result.contract.script = Script("pay");

            immutable message = net.hashOf(result.contract.toDoc);
            auto shared_net = (() @trusted { return cast(shared) net; })();
            auto bill_net = new Net;
            // Sign all inputs
            result.signs = contract_bills
                .filter!(b => b.owner in account.derives)
                .map!((b) {
                    immutable tweak_code = account.derives[b.owner];
                    bill_net.derive(tweak_code, shared_net);
                    return bill_net.sign(message);
                })
                .array;
            return true;
        }
        result = result.init;
        return false;

        return false;
    }

    bool evil_collect_bills(const TagionCurrency amount, out StandardBill[] active_bills)
    {
        import std.algorithm.sorting : isSorted, sort;
        import std.algorithm.iteration : cumulativeFold;
        import std.range : takeOne, tee;

        if (!account.bills.isSorted!"a.value > b.value")
        {
            account.bills.sort!"a.value > b.value";
        }

        // Select all bills not in use
        auto none_active = account.bills.filter!(b => !(b.owner in account.activated));

        // Check if we have enough money
        
        TagionCurrency rest = amount;
        active_bills = none_active.filter!(b => b.value <= rest)
            .until!(b => rest <= 0)
            .tee!((b) { rest -= b.value; account.activated[b.owner] = true; })
            .array;
        if (rest > 0)
        {
            // Take an extra larger bill if not enough
            StandardBill extra_bill;
            none_active.each!(b => extra_bill = b);
            account.activated[extra_bill.owner] = true;
            active_bills ~= extra_bill;
        }
        return true;

    }

}


// @safe struct EvilWallet(Net)
// {
//     static assert(is(Net : SecureNet));
//     protected RecoverGenerator _wallet;
//     protected DevicePIN _pin;

//     AccountDetails account;
//     protected SecureNet net;

//     //    @disable this();

//     this(DevicePIN pin, RecoverGenerator wallet = RecoverGenerator.init, AccountDetails account = AccountDetails
//             .init)
//     { //nothrow {
//         _wallet = wallet;
//         _pin = pin;
//         this.account = account;
//     }

//     this(const Document wallet_doc, const Document pin_doc = Document.init)
//     {
//         auto __wallet = RecoverGenerator(wallet_doc);
//         DevicePIN __pin;
//         if (!pin_doc.empty)
//         {
//             __pin = DevicePIN(pin_doc);
//         }
//         this(__pin, __wallet);
//     }

//     @nogc const(RecoverGenerator) wallet() pure const nothrow
//     {
//         return _wallet;
//     }

//     @nogc const(DevicePIN) pin() pure const nothrow
//     {
//         return _pin;
//     }

//     @nogc uint confidence() pure const nothrow
//     {
//         return _wallet.confidence;
//     }

//     static EvilWallet createWallet(
//         scope const(string[]) questions,
//         scope const(char[][]) answers,
//         uint confidence,
//         const(char[]) pincode)
//     in
//     {
//         assert(questions.length > 3, "Minimal amount of answers is 4");
//         assert(questions.length is answers.length, "Amount of questions should be same as answers");
//     }
//     do
//     {
//         auto net = new Net;
//         //        auto hashnet = new StdHashNet;
//         auto recover = KeyRecover(net);

//         if (confidence == questions.length)
//         {
//             pragma(msg, "fixme(cbr): Due to some bug in KeyRecover");
//             // Due to some bug in KeyRecover
//             confidence--;
//         }

//         recover.createKey(questions, answers, confidence);
//         //        StdSecureNet net;
//         EvilWallet result;
//         {
//             auto R = new ubyte[net.hashSize];
//             scope (exit)
//             {
//                 scramble(R);
//             }
//             recover.findSecret(R, questions, answers);
//             net.createKeyPair(R);
//             auto wallet = RecoverGenerator(recover.toDoc);
//             result = EvilWallet(DevicePIN.init, wallet);
//             result.set_pincode(recover, R, pincode, net);

//         }
//         return result;
//     }

//     protected void set_pincode(
//         const KeyRecover recover,
//         scope const(ubyte[]) R,
//         scope const(char[]) pincode,
//         Net _net = null)
//     {
//         const hash_size = ((net) ? net : _net).hashSize;
//         auto seed = new ubyte[hash_size];
//         scramble(seed);
//         _pin.U = seed.idup;
//         const pinhash = recover.checkHash(pincode.representation, _pin.U);
//         _pin.D = xor(R, pinhash);
//         _pin.S = recover.checkHash(R);
//     }

//     bool correct(const(string[]) questions, const(char[][]) answers)
//     in
//     {
//         assert(questions.length is answers.length, "Amount of questions should be same as answers");
//     }
//     do
//     {
//         net = new Net;
//         auto recover = KeyRecover(net, _wallet);
//         scope R = new ubyte[net.hashSize];
//         return recover.findSecret(R, questions, answers);
//     }

//     bool recover(const(string[]) questions, const(char[][]) answers, const(char[]) pincode)
//     in
//     {
//         assert(questions.length is answers.length, "Amount of questions should be same as answers");
//     }
//     do
//     {
//         net = new Net;
//         auto recover = KeyRecover(net, _wallet);
//         auto R = new ubyte[net.hashSize];
//         const result = recover.findSecret(R, questions, answers);
//         if (result)
//         {
//             // auto pinhash = recover.checkHash(pincode.representation, _pin.U);
//             set_pincode(recover, R, pincode);
//             net.createKeyPair(R);
//             return true;
//         }
//         net = null;
//         return false;
//     }

//     @nogc bool isLoggedin() pure const nothrow
//     {
//         pragma(msg, "fixme(cbr): Jam the net");
//         return net !is null;
//     }

//     protected void checkLogin() pure const
//     {
//         check(isLoggedin(), "Need login first");
//     }

//     bool login(const(char[]) pincode)
//     {
//         if (_pin.D)
//         {
//             logout;
//             auto hashnet = new Net;
//             auto recover = KeyRecover(hashnet);
//             auto pinhash = recover.checkHash(pincode.representation, _pin.U);
//             auto R = new ubyte[hashnet.hashSize];
//             _pin.recover(R, pinhash);
//             if (_pin.S == recover.checkHash(R))
//             {
//                 net = new Net;
//                 net.createKeyPair(R);
//                 return true;
//             }
//         }
//         return false;
//     }

//     void logout() pure nothrow
//     {
//         net = null;
//     }

//     bool check_pincode(const(char[]) pincode)
//     {
//         const hashnet = new Net;
//         auto recover = KeyRecover(hashnet);
//         const pinhash = recover.checkHash(pincode.representation, _pin.U);
//         scope R = new ubyte[hashnet.hashSize];
//         _pin.recover(R, pinhash);
//         return _pin.S == recover.checkHash(R);
//     }

//     bool change_pincode(const(char[]) pincode, const(char[]) new_pincode)
//     {
//         const hashnet = new Net;
//         auto recover = KeyRecover(hashnet);
//         const pinhash = recover.checkHash(pincode.representation, _pin.U);
//         auto R = new ubyte[hashnet.hashSize];
//         // xor(R, _pin.D, pinhash);
//         _pin.recover(R, pinhash);
//         if (_pin.S == recover.checkHash(R))
//         {
//             // const new_pinhash = recover.checkHash(new_pincode.representation, _pin.U);
//             set_pincode(recover, R, new_pincode);
//             logout;
//             return true;
//         }
//         return false;
//     }

//     void registerInvoice(ref Invoice invoice)
//     {
//         checkLogin;
//         string current_time = MonoTime.currTime.toString;
//         scope seed = new ubyte[net.hashSize];
//         scramble(seed);
//         account.derive_state = net.rawCalcHash(
//             seed ~ account.derive_state ~ current_time.representation);
//         scramble(seed);
//         auto pkey = net.derivePubkey(account.derive_state);
//         invoice.pkey = pkey;
//         account.derives[pkey] = account.derive_state;
//     }

//     // void registerInvoices(ref Invoice[] invoices) {
//     //     invoices.each!((ref invoice) => registerInvoice(invoice));
//     // }

//     static Invoice createInvoice(string label, TagionCurrency amount, Document info = Document.init)
//     {
//         Invoice new_invoice;
//         new_invoice.name = label;
//         new_invoice.amount = amount;
//         new_invoice.info = info;
//         return new_invoice;
//     }

//     bool payment(const(Invoice[]) orders, ref SignedContract result, bool setfee, double fee)
//     {
//         checkLogin;
//         const topay = orders.map!(b => b.amount).sum;

//         // removed topay check.
//         const size_in_bytes = 500;
//         // todo set fee manually here.
//         TagionCurrency fees;
//         if (setfee) {
//             fees = fee.to!double.TGN;
//         } else {
//             fees = globals.fees(topay, size_in_bytes); // 52.5
//         }

//         const amount = topay + fees; 
//         StandardBill[] contract_bills;
//         const enough = collect_bills(amount, contract_bills); // change to always be true.
//         if (enough)
//         {
//             const total = contract_bills.map!(b => b.value).sum;

//             result.contract.inputs = contract_bills.map!(b => net.hashOf(b.toDoc)).array;
//             const rest = total - amount;
//             if (rest > 0)
//             {
//                 Invoice money_back;
//                 money_back.amount = rest;
//                 registerInvoice(money_back);
//                 result.contract.output[money_back.pkey] = rest.toDoc;
//             }
//             orders.each!((o) {
//                 result.contract.output[o.pkey] = o.amount.toDoc;
//             });
//             result.contract.script = Script("pay");

//             immutable message = net.hashOf(result.contract.toDoc);
//             auto shared_net = (() @trusted { return cast(shared) net; })();
//             auto bill_net = new Net;
//             // Sign all inputs
//             result.signs = contract_bills
//                 .filter!(b => b.owner in account.derives)
//                 .map!((b) {
//                     immutable tweak_code = account.derives[b.owner];
//                     bill_net.derive(tweak_code, shared_net);
//                     return bill_net.sign(message);
//                 })
//                 .array;
//             return true;
//         }
//         result = result.init;
//         return false;

//         return false;
//     }

//     TagionCurrency available_balance() const pure
//     {
//         return account.available;
//     }

//     TagionCurrency active_balance() const pure
//     {
//         return account.active;
//     }

//     TagionCurrency total_balance() const pure
//     {
//         return account.total;
//     }

//     @trusted
//     void deactivate_bills()
//     {
//         account.activated.clear;
//     }

//     const(HiRPC.Sender) get_request_update_wallet() const
//     {
//         HiRPC hirpc;
//         auto h = new HiBON;
//         h = account.derives.byKey.map!(p => cast(Buffer) p);
//         return hirpc.search(h);
//     }

//     bool collect_bills(const TagionCurrency amount, out StandardBill[] active_bills)
//     {
//         import std.algorithm.sorting : isSorted, sort;
//         import std.algorithm.iteration : cumulativeFold;
//         import std.range : takeOne, tee;

//         if (!account.bills.isSorted!"a.value > b.value")
//         {
//             account.bills.sort!"a.value > b.value";
//         }

//         // Select all bills not in use
//         auto none_active = account.bills.filter!(b => !(b.owner in account.activated));

//         // Check if we have enough money
        
//         TagionCurrency rest = amount;
//         active_bills = none_active.filter!(b => b.value <= rest)
//             .until!(b => rest <= 0)
//             .tee!((b) { rest -= b.value; account.activated[b.owner] = true; })
//             .array;
//         if (rest > 0)
//         {
//             // Take an extra larger bill if not enough
//             StandardBill extra_bill;
//             none_active.each!(b => extra_bill = b);
//             account.activated[extra_bill.owner] = true;
//             active_bills ~= extra_bill;
//         }
//         return true;

//     }

//     @trusted
//     bool set_response_update_wallet(const(HiRPC.Receiver) receiver) nothrow
//     {
//         if (receiver.isResponse)
//         {
//             try
//             {
//                 account.bills = receiver.response.result[].map!(e => StandardBill(e.get!Document))
//                     .array;
//                 return true;
//             }
//             catch (Exception e)
//             {
//                 import std.stdio;
//                 import std.exception : assumeWontThrow;

//                 assumeWontThrow(() => writeln("Error on setresponse: %s", e.msg));
//                 // Ingore
//             }
//         }
//         return false;
//     }

//     static TagionCurrency calcTotal(const(StandardBill[]) bills) pure
//     {
//         return bills.map!(b => b.value).sum;
//     }
// }