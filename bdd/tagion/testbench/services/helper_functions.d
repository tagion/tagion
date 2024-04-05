module tagion.testbench.services.helper_functions;

import std.format;
import std.stdio;
import std.array;
import std.algorithm;
import tagion.behaviour;
import tagion.behaviour.BehaviourException : check;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.hibon.HiBON;
import tagion.script.TagionCurrency;
import tagion.tools.wallet.WalletInterface;
import tagion.wallet.SecureWallet;
import tagion.wallet.request;
import tagion.trt.TRT : TRTContractArchive;
import tagion.hibon.Document : Document;
import tagion.Keywords;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONRecord : isRecord;

@safe:

alias StdSecureWallet = SecureWallet!StdSecureNet;
pragma(msg, "remove trusted when nng is safe");

TagionCurrency getWalletUpdateAmount(ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) @trusted {
    auto checkread = wallet.getRequestCheckWallet(hirpc);
    auto wallet_received = sendHiRPC(sock_addr, checkread, hirpc);
    writefln("Received res", wallet_received.toPretty);
    check(!wallet_received.isError, format("Received HiRPC error: %s", wallet_received.toPretty));
    check(wallet.setResponseCheckRead(wallet_received), "wallet not updated successfully");

    return wallet.calcTotal(wallet.account.bills);
}

TagionCurrency getWalletInvoiceUpdateAmount(ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) @trusted {
    auto owner_keys = wallet.getRequestUpdateWallet(hirpc);
    auto wallet_received = sendHiRPC(sock_addr, owner_keys, hirpc);
    writefln("Received res", wallet_received.toPretty);
    check(!wallet_received.isError, format("Received HiRPC error: %s", wallet_received.toPretty));
    check(wallet.setResponseUpdateWallet(wallet_received), "wallet not updated successfully");

    return wallet.calcTotal(wallet.account.bills);
}

TagionCurrency getWalletTRTUpdateAmount(ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) @trusted {
    const sender = wallet.readIndicesByPubkey(hirpc);
    auto indices_received = sendHiRPC(sock_addr, sender, hirpc);
    writefln("received res", indices_received.toPretty);
    check(!indices_received.isError, format("Received HiRPC error: %s", indices_received.toPretty));

    const difference_req = wallet.differenceInIndices(indices_received);
    if (difference_req is HiRPC.Sender.init) {
        return wallet.calcTotal(wallet.account.bills);
    }
    auto dart_received = sendHiRPC(sock_addr, difference_req, hirpc);
    writefln("received res", dart_received.toPretty);
    check(!dart_received.isError, format("Received HiRPC error: %s", dart_received.toPretty));
    check(wallet.updateFromRead(dart_received), "dart req, wallet not updated successfully");
    return wallet.calcTotal(wallet.account.bills);
}

TRTContractArchive[] getTRTStoredContracts(const(Document)[] contracts, ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) {
    const sender = wallet.readContractsTRT(contracts, hirpc);
    auto receiver = sendHiRPC(sock_addr, sender, hirpc);

    auto recorder_doc = receiver.message[Keywords.result].get!Document;

    auto net = new StdHashNet;
    RecordFactory record_factory = RecordFactory(net);

    const recorder = record_factory.recorder(recorder_doc);
    return recorder[].map!(a => a.filed)
        .filter!(doc => doc.isRecord!TRTContractArchive)
        .map!(doc => TRTContractArchive(doc))
        .array;

}
