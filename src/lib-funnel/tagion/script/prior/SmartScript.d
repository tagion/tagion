module tagion.script.prior.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep, zip;
import std.format;
import std.algorithm.iteration : sum, map, filter;
import std.algorithm.searching : all;

import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.basic.tagionexceptions : TagionException;
import tagion.script.prior.StandardRecords : SignedContract, StandardBill, PayContract, OwnerKey, Contract, Script, Globals, globals;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Fingerprint;
import tagion.script.TagionCurrency;
import tagion.dart.Recorder : RecordFactory;
import tagion.dart.DARTBasic;

import tagion.hibon.HiBONRecord : GetLabel;

import tagion.logger.Logger;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import std.bitmanip : nativeToBigEndian;

//import tagion.script.ScriptCrypto;

alias check = Check!SmartScriptException;

@safe
const(TagionCurrency) calcTotal(const(StandardBill[]) bills) pure {
    return bills.map!(b => b.value).sum;
}

version (OLD_TRANSACTION) {
    @safe
    class SmartScript {
        pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);
        const SignedContract signed_contract;
        this(const SignedContract signed_contract) {
            this.signed_contract = signed_contract;
        }

        void check(const SecureNet net) const {
            SmartScript.check(net, signed_contract);
        }

        @trusted
        static void check(const SecureNet net, const SignedContract signed_contract)
        in {
            assert(net);
        }
        do {

            

                .check(signed_contract.signs.length > 0, ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE);
            const message = net.calcHash(signed_contract.contract.toDoc);

            

            .check(signed_contract.signs.length == signed_contract.inputs.length,
                    ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS);

            

            .check(signed_contract.contract.inputs.length == signed_contract.inputs.length,
                    ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);
            foreach (i, print, input, signature; lockstep(signed_contract.contract.inputs, signed_contract.inputs, signed_contract
                    .signs)) {

                immutable fingerprint = net.calcHash(input.toDoc);

                

                .check(print == fingerprint,
                        ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT);
                Pubkey pkey = input.owner;

                

                .check(net.verify(message, signature, pkey),
                        ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY);
            }
        }

        protected StandardBill[] _output_bills;

        const(StandardBill[]) output_bills() const pure nothrow {
            return _output_bills;
        }

        void run(
                const uint epoch,
                ref uint index_in_epoch,
                const Fingerprint bullseye,
                const HashNet net) {
            enum transactions_name = "#trans";
            const total_input = calcTotal(signed_contract.inputs);
            TagionCurrency total_output;
            foreach (pkey, doc; signed_contract.contract.output) {
                StandardBill bill;
                bill.epoch = epoch;
                pragma(msg, "fixme(cbr): Check for overflow");
                const amount = TagionCurrency(doc);
                total_output += amount;
                bill.value = amount;
                bill.owner = pkey;
                auto index_hash = net.rawCalcHash(nativeToBigEndian(index_in_epoch));
                bill.gene = net.rawCalcHash(bullseye ~ index_hash);
                _output_bills ~= bill;
                index_in_epoch++;
            }

            

            .check(total_output <= total_input - globals.fees(),
                    ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
        }
    }
}
else {
    @safe
    class SmartScript {
        SignedContract signed_contract;
        RecordFactory.Recorder inputs;
        this(const SecureNet net, ref const SignedContract signed_contract) {
            //     this.signed_contract = signed_contract;
        }

        //    @trusted
        static ConsensusFailCode check(
                const SecureNet net,
                const ref SignedContract signed_contract,
                const RecordFactory.Recorder inputs) nothrow
        in {
            assert(net);
        }
        do {
            try {
                if (signed_contract.contract.output.length == 0) {
                    return ConsensusFailCode.SMARTSCRIPT_NO_OUTPUT;
                }
                if (signed_contract.signs.length == 0) {
                    return ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE;
                }
                const message = net.calcHas(signed_contract.contract.toDoc);
                if (signed_contract.signs.length != inputs.length) {
                    return ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS;
                }
                if (!inputs[].all!(a => a.filed.hasMember(OwnerKey) && a
                        .filed[OwnerKey].isType!Pubkey)) {
                    return ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING;
                }
                if (signed_contract.contract.inputs.length != inputs.length) {
                    return ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING;
                }

                auto check_range = () @trusted => lockstep(
                        signed_contract.contract.inputs,
                        inputs[],
                        signed_contract.signs);

                foreach (print, input, signature; zip(signed_contract.contract.inputs,
                        inputs[],
                        signed_contract.signs)) {
                    immutable fingerprint = net.dartIndex(input);

                    if (print != fingerprint) {
                        return ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT;
                    }
                    Pubkey pkey = input.filed[OwnerKey].get!Buffer;

                    if (!net.verify(message, signature, pkey)) {
                        return ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY;
                    }
                }
            }
            catch (TagionException e) {
                log.warning(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_TAGIONEXCEPTION;
            }
            catch (Exception e) {
                log.warning(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_EXCEPTION;
            }
            return ConsensusFailCode.NONE;
        }

        static ConsensusFailCode run(const(SecureNet) net, /*const(string) method,*/
                const ref SignedContract signed_contract,
                const RecordFactory.Recorder inputs,
                ref RecordFactory.Recorder outputs) {
            try {
                // check(net, signed_contract, inputs);
                auto total_input = inputs[]
                    .map!(a => a.filed)
                    .filter!(a => StandardBill.isRecord(a))
                    .map!(a => TagionCurrency(a["$V"].get!Document))
                    .sum;

                TagionCurrency total_output;
                foreach (key; signed_contract.contract.output) {
                    total_output += TagionCurrency(key["$V"].get!Document);
                }
                if (total_output > total_input - globals.fees()) {
                    return ConsensusFailCode.SMARTSCRIPT_INVALID_OUTPUT;
                }

                foreach (contract_output; signed_contract.contract.output) {
                    outputs.insert(contract_output);
                }
            }
            catch (SmartScriptException e) {
                log.error(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_SMARTSCRIPTEXCEPTION;
            }
            return ConsensusFailCode.NONE;
        }

        // version(none)
        // void run(const uint epoch) {
        //     assert(0);
        // }

        // // check values
        // version (none) void run(const uint epoch) {
        //     // immutable source=signed_contract.contract.script;
        //     enum transactions_name = "#trans";
        //     immutable source = (() @trusted =>
        //             format(": %s %s ;", transactions_name, signed_contract.contract.script)
        //     )();
        //     auto src = ScriptParser(source);
        //     Script script;
        //     auto builder = ScriptBuilder(src[]);
        //     builder.build(script);

        //     auto sc = new ScriptContext(10, 10, 10, 100);
        //     script.execute(transactions_name, sc);

        //     const payment = PayContract(signed_contract.input);
        //     const total_input = calcTotal(payment.bills);
        //     TagionCurrency total_output;
        //     foreach (pkey, doc; signed_contract.contract.output) {
        //         StandardBill bill;
        //         bill.epoch = epoch;
        //         const num = sc.pop.get!Number;
        //         pragma(msg, "fixme(cbr): Check for overflow");
        //         const amount = TagionCurrency(cast(long) num);
        //         total_output += amount;
        //         bill.value = amount;
        //         bill.owner = pkey;
        //         //            bill.bill_type = "TGN";
        //         _output_bills ~= bill;
        //     }

        //     .check(total_output <= total_input, ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
        // }
    }
}
version (OLD_TRANSACTION) {
    unittest {
        import std.stdio : writefln, writeln;
        import tagion.crypto.SecureNet;
        import tagion.hibon.HiBON;
        import tagion.script.prior.StandardRecords : Script;

        const net = new StdSecureNet;
        import std.array;

        SecureNet alice = new StdSecureNet;
        {
            alice.generateKeyPair("Alice's secret password");
        }
        auto bob = new StdSecureNet;
        {
            bob.generateKeyPair("Bob's secret password");
        }
        uint epoch = 42;
        StandardBill[] bills;

        bills ~= StandardBill(1000.TGN, epoch, alice.pubkey, null);
        bills ~= StandardBill(1200.TGN, epoch, alice.derivePubkey("alice0"), null);
        bills ~= StandardBill(3000.TGN, epoch, alice.derivePubkey("alice1"), null);
        bills ~= StandardBill(4300.TGN, epoch, alice.derivePubkey("alice2"), null);
        SignedContract createSSC(TagionCurrency amount) {
            auto input_bill = StandardBill(1000.TGN, epoch, alice.pubkey, null);

            SignedContract ssc;
            Contract contract;

            contract.inputs = [net.HashNet.dartIndex(input_bill)];
            contract.output[bob.pubkey] = amount.toDoc;
            contract.script = Script("pay");

            ssc.contract = contract;
            ssc.signs = [alice.sign(net.calcHash(contract.toDoc))];
            ssc.inputs = [input_bill];
            return ssc;
        }

        // function for signing all bills
        void sign_all_bills(
                const StandardBill[] input_bills,
                const StandardBill[] output_bills,
                const SecureNet net,
                ref SignedContract signed_contract) {
            Contract contract;
            contract.inputs = input_bills.map!(b => net.dartIndex(b.toDoc)).array;
            foreach (bill; output_bills) {
                contract.output[bill.owner] = bill.value.toDoc;
            }
            contract.script = Script("pay");
            foreach (bill; input_bills) {
                auto signed_doc = net.sign(contract.toDoc);
                signed_contract.signs ~= signed_doc.signature;
                assert(net.verify(contract.toDoc, signed_doc.signature, net.pubkey));
            }
            signed_contract.contract = contract;
        }
        /// SmartScript reject contracts without fee included
        {
            auto ssc = createSSC(1000.TGN);
            auto smart_script = new SmartScript(ssc);
            uint index = 1;
            try {
                smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
                assert(false, "Input and Output amount not checked");
            }
            catch (SmartScriptException e) {
                assert(e.code == ConsensusFailCode
                        .SMARTSCRIPT_NOT_ENOUGH_MONEY);
            }
        }
        /// SmartScript accept contracts with fee included
        {
            auto ssc = createSSC(1000.TGN - globals.fees());
            auto smart_script = new SmartScript(ssc);
            uint index = 1;
            try {
                smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
            }
            catch (SmartScriptException e) {
                assert(false, format("Exception code: %s", e.code));
            }
        }

        /// SmartScript accept contracts with output less then input
        {
            auto ssc = createSSC(900.TGN - globals.fees());
            auto smart_script = new SmartScript(ssc);
            uint index = 1;
            try {
                smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
            }
            catch (SmartScriptException e) {
                assert(false, format("Exception code: %s", e.code));
            }
        }
        StandardBill[] outputbills;
        /// Output bills with same owner get diffrent gene
        {
            SignedContract signed_contract_1;
            SignedContract signed_contract_2;
            outputbills ~= StandardBill(100.TGN, epoch, bob.pubkey, null);
            sign_all_bills([bills[0]], outputbills, alice, signed_contract_1);
            signed_contract_1.inputs ~= bills[0];
            sign_all_bills([bills[1]], outputbills, alice, signed_contract_2);
            signed_contract_2.inputs ~= bills[1];

            SmartScript ssc_1 = new SmartScript(signed_contract_1);
            SmartScript ssc_2 = new SmartScript(signed_contract_2);
            uint index = 1;
            ssc_1.run(55, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
            ssc_2.run(55, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
            assert(index == 3);
            assert(ssc_1.output_bills.length == 1, "Smart contract generate more than one output");
            auto output_bill1 = ssc_1.output_bills[0];
            auto output_bill2 = ssc_2.output_bills[0];
            assert(output_bill1.gene.length != 0, "Output bill gene is empty");
            assert(output_bill1.gene != output_bill2.gene, "Output bill gene are same");
            assert(net.HashNet.dartIndex(output_bill1) != net.HashNet.dartIndex(output_bill2), "Bills with same owner key has same hash");
        }
    }
}
else {
    unittest {
        import std.stdio : writefln, writeln;
        import tagion.dart.Recorder : Add, Remove;
        import tagion.crypto.SecureNet;
        import tagion.basic.Types : FileExtension;
        import tagion.hibon.HiBON;
        import std.array;

        // function for signing all bills
        void sign_all_bills(const StandardBill[] bills, const SecureNet net, ref SignedContract signed_contract) {
            Contract contract;
            foreach (bill; bills) {
                Document doc;
                {
                    auto h = new HiBON;
                    enum bill_name = GetLabel!(StandardBill).name;
                    h[bill_name] = bill;
                    doc = Document(h);
                }

                auto signed_doc = net.sign(doc);
                contract.inputs ~= net.dartIndex(bill);
                signed_contract.signs ~= signed_doc.signature;
                assert(net.verify(doc, signed_doc.signature, net.pubkey));
            }
            signed_contract.contract = contract;
        }

        const net = new StdSecureNet;
        SecureNet alice = new StdSecureNet;
        {
            alice.generateKeyPair("Alice's secret password");
        }
        auto bob = new StdSecureNet;
        {
            bob.generateKeyPair("Bob's secret password");
        }
        uint epoch = 42;
        StandardBill[] bills;

        bills ~= StandardBill(1000.TGN, epoch, alice.pubkey, null);
        bills ~= StandardBill(1200.TGN, epoch, alice.derivePubkey("alice0"), null);
        bills ~= StandardBill(3000.TGN, epoch, alice.derivePubkey("alice1"), null);
        bills ~= StandardBill(4300.TGN, epoch, alice.derivePubkey("alice2"), null);

        auto factory = RecordFactory(net);
        const alices_bills = factory.recorder(bills);
        auto output_bills = factory.recorder();

        import tagion.dart.DART : DART;
        import tagion.basic.basic : fileId;

        immutable filename = fileId!SmartScript(FileExtension.dart).fullpath;

        DART.create(filename);
        auto dart_db = new DART(net, filename);
        dart_db.modify(alices_bills, Add);
        writefln("dart-file %s", filename);
        dart_db.dump(true);

        // SmartScript.check tests
        {
            // simple valid scenario
            // {
            //     SignedContract signed_contract;
            //     sign_all_bills(bills, alice, signed_contract);

            //     auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
            //     signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

            //     assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.NONE);
            // }

            // simple invalid scenario (no output docs)
            {
                SignedContract signed_contract;
                sign_all_bills(bills, alice, signed_contract);

                assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode
                        .SMARTSCRIPT_NO_OUTPUT);
            }

            // invalid scenario (unsigned bill)
            {
                SignedContract signed_contract;
                sign_all_bills(bills[0 .. $ - 1], alice, signed_contract);

                auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
                signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

                assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode
                        .SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS);
            }

            //contract.imput.length more than inputs.length
            {
                SignedContract signed_contract;
                Contract contract;
                foreach (bill; bills) {
                    Document doc;
                    {
                        auto h = new HiBON;
                        enum bill_name = GetLabel!(StandardBill).name;
                        h[bill_name] = bill;
                        doc = Document(h);
                    }

                    auto signed_doc = alice.sign(doc);
                    contract.inputs ~= alice.dartIndex(bill);
                    signed_contract.signs ~= signed_doc.signature;
                    assert(alice.verify(doc, signed_doc.signature, alice.pubkey));
                }
                auto other_bill = StandardBill(4300.TGN, epoch, alice.derivePubkey("alice3"), null);
                contract.inputs ~= alice.dartIndex(other_bill);
                signed_contract.contract = contract;

                auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
                signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

                assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode
                        .SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);
            }
        }

        //SmartScript run tests
        {
            // simple valid scenario
            // {
            //     SignedContract signed_contract;
            //     sign_all_bills(bills, alice, signed_contract);

            //     auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
            //     signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

            //     assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.NONE);

            //     assert(SmartScript.run(alice, signed_contract, alices_bills, output_bills) == ConsensusFailCode.NONE);
            // }

            // output value > input value
            // {
            //     SignedContract signed_contract;
            //     sign_all_bills(bills, alice, signed_contract);

            //     StandardBill[] bob_bills;
            //     bob_bills ~= StandardBill(1000.TGN, epoch, bob.pubkey, null);
            //     bob_bills ~= StandardBill(1000.TGN, epoch, bob.derivePubkey("bob0"), null);
            //     bob_bills ~= StandardBill(1000.TGN, epoch, bob.derivePubkey("bob1"), null);
            //     bob_bills ~= StandardBill(10000000.TGN, epoch, bob.derivePubkey("bob2"), null);

            //     foreach(bill; bob_bills) {
            //         signed_contract.contract.output[bill.owner] = bill.toDoc;
            //     }
            //     assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.NONE);

            //     assert(SmartScript.run(alice, signed_contract, alices_bills, output_bills) == ConsensusFailCode.SMARTSCRIPT_INVALID_OUTPUT);
            // }

            //output value > input value (1 bill)
            // {
            //     SignedContract signed_contract;
            //     sign_all_bills(bills, alice, signed_contract);

            //     auto bob_bill = StandardBill(1000000.TGN, epoch, bob.pubkey, null);
            //     signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

            //     assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.NONE);

            //     assert(SmartScript.run(alice, signed_contract, alices_bills, output_bills) == ConsensusFailCode.SMARTSCRIPT_INVALID_OUTPUT);
            // }
        }
    }
}
