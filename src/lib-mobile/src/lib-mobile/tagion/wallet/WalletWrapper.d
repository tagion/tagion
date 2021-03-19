module tagion.wallet.WalletWrapper;

import std.format;
import std.string: representation;
import std.algorithm : map, max, min;
import std.array;
import std.exception : assumeUnique;
import core.time : MonoTime;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;

import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.script.StandardRecords;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet, scramble;
// import tagion.gossip.GossipNet : StdSecureNet, StdHashNet, scramble;
import tagion.wallet.KeyRecover;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.Keywords;
import tagion.wallet.TagionCurrency;
import tagion.communication.HiRPC;

struct WalletData{
    protected @Label("$wallet") Wallet _wallet;
    protected @Label("$account") Buffer[Pubkey] _account;
    protected @Label("$bills") StandardBill[] _bills;
    protected @Label("$drive_state") Buffer _drive_state;

    mixin HiBONRecord!(
            q{
                this(ref Wallet wallet, Buffer[Pubkey] account = null, Buffer drive_state = null, StandardBill[] bills = null){
                    _wallet = wallet;
                    _account = account;
                    _bills = bills;
                    _drive_state = drive_state;
                }
            }
    );
}
// @safe
struct WalletWrapper {
    protected WalletData data;
    protected StdSecureNet net;


    this(ref Wallet wallet, Buffer[Pubkey] account = null, Buffer drive_state = null, StandardBill[] bills = null){
        data._wallet = wallet;
        data._account = account;
        data._bills = bills;
        data._drive_state = drive_state;
    }


    this(ref WalletData data){
        this.data = data;        
    }

    @trusted final inout(HiBON) toHiBON() inout {
        return data.toHiBON();
    }

    static WalletWrapper createWallet(const(string[]) questions, const(string[]) answers, uint confidence, Buffer pincode)
    in{
        assert(questions.length >3, "Minimal amount of answers is 3");
        assert(questions.length is answers.length, "Amount of questions should be same as answers");
    }
    do{
        auto hashnet = new StdHashNet;
        auto recover = KeyRecover(hashnet);

        if (confidence == questions.length) {
            // Due to some bug in KeyRecover
            confidence--;
        }

        recover.createKey(questions, answers, confidence);
        StdSecureNet net; 
        Wallet wallet;
        {
            net=new StdSecureNet;
            auto R=new ubyte[net.hashSize];

            recover.findSecret(R, questions, answers);
            //writefln("R=0x%s", R.idup.hex);
            // import std.string : representation;
            auto pinhash=recover.checkHash(pincode);
            //writefln("R.length=%d pinhash.length=%d", R.length, pinhash.length);
            wallet.Y=xor(R, pinhash);
            wallet.check=recover.checkHash(R);
            net.createKeyPair(R);
            wallet.pubkey=net.pubkey;
            const seed_data=recover.toHiBON.serialize;
            const seed_doc=Document(seed_data);
            wallet.seed=KeyRecover.RecoverSeed(seed_doc);
        }
        return WalletWrapper(wallet);
    }

    bool isLogedin(){
        return net !is null;
    }
    
    void checkLogin() { assert(isLogedin(), "Need login first"); }

    bool login(string pincode){
        auto hashnet=new StdHashNet;
        auto recover=new KeyRecover(hashnet);
        auto pinhash=recover.checkHash(pincode.representation);
        auto R=new ubyte[hashnet.hashSize];
        xor(R, data._wallet.Y, pinhash);
        if (data._wallet.check == recover.checkHash(R)) {
            net=new StdSecureNet;
            net.createKeyPair(R);
            return true;
        }
        return false;
    }

    ulong total() nothrow{
        return WalletWrapper.calcTotal(data._bills);
    }

    void registerInvoice(ref Invoice invoice) 
    in{
        checkLogin;
    }
    do{
        string current_time=MonoTime.currTime.toString;
        scope seed=new ubyte[net.hashSize];
        scramble(seed);
        data._drive_state=net.calcHash(seed~data._drive_state~current_time.representation);
        scramble(seed);
        const pkey=net.derivePubkey(data._drive_state);
        invoice.pkey=cast(Buffer)pkey;
        data._account[pkey]=data._drive_state;
    }

    static Invoice createInvoice(string label, TagionCurency tagions = TagionCurency.init){
        Invoice new_invoice;
        new_invoice.name=label;
        if(tagions==TagionCurency.init){
            new_invoice.amount=tagions.axios();
        }
        return new_invoice;
    }   

    bool payment(const(Invoice[]) orders, ref SignedContract result) 
    in{
        checkLogin;
    } 
    do{
        ulong calcTotal(const(Invoice[]) invoices) {
            ulong result;
            foreach(b; invoices) {
                result+=b.amount;
            }
            return result;
        }
        const topay=calcTotal(orders);

        StandardBill[] contract_bills;
        if (topay > 0) {
            string source;
            uint count;
            foreach(o; orders) {
                source=assumeUnique(format("%s %s", o.amount, source));
                count++;
            }

            // Input
            ulong amount=topay;


            foreach(b; data._bills) {
                amount-=min(amount, b.value);
                contract_bills~=b;
                if (amount == 0) {
                    break;
                }
            }
            if(amount != 0){
                return false;
            }
//        result.input=contract_bills; // Input _bills
//        Buffer[] inputs;
            foreach(b; contract_bills) {
                result.contract.input~=net.hashOf(b.toDoc);
            }
            const _total_input=WalletWrapper.calcTotal(contract_bills);
            if ( _total_input >= topay) {
                const _rest=_total_input-topay;
                count++;
                result.contract.script=assumeUnique(format("%s %s %d pay", source, _rest, count));
                // output
                Invoice money_back;
                money_back.amount=_rest;
                registerInvoice(money_back);
                result.contract.output~=money_back.pkey;
                foreach(o; orders) {
                    result.contract.output~=o.pkey;
                }
            }
            else {
                return false;
            }
        }

        // Sign all inputs
        immutable message=net.hashOf(result.contract.toDoc);
        shared shared_net=cast(shared)net;
        foreach(i, b; contract_bills) {
            Pubkey pkey=b.owner;
            if (pkey in data._account) {
                immutable tweak_code=data._account[pkey];
                auto bill_net=new StdSecureNet;
                bill_net.derive(tweak_code, shared_net);
                immutable signature=bill_net.sign(message);
                result.signs~=signature;
            }
        }

        return true;
    }

    Document get_request_update_wallet(){
        HiRPC hirpc;
        Buffer prepareSearch(Buffer[] owners){
            HiBON params = new HiBON;
            foreach(i, owner; owners){
                params[i] = owner;
            }
            const sender=hirpc.action("search", params);
            immutable data=sender.toDoc.serialize;
            return data;
        }
        Buffer[] pkeys;
        foreach(pkey, dkey; data._account){
            pkeys~=cast(Buffer)pkey;
        }

        return Document(prepareSearch(pkeys));
    }

    bool set_response_update_wallet(Document response_doc){
        HiRPC hirpc;
        StandardBill[] new_bills;
        auto received = hirpc.receive(response_doc);
        if(HiRPC.getType(received) == HiRPC.Type.result){
            foreach(bill; received.response.result[]){
                auto std_bill = StandardBill(bill.get!Document);
                new_bills ~= std_bill;
            }
            data._bills = new_bills;
            // writeln("Wallet updated");
            return true;
        }else{
            // writeln("Wallet update failed");
            return false;
        }
    }

    ulong get_balance(){
        const balance = calcTotal(data._bills);
        return balance;
    }



    static protected{
        ulong calcTotal(const(StandardBill[]) bills) nothrow{
            ulong result;
            foreach(b; bills) {
                result+=b.value;
            }
            return result;
        }
    }
}