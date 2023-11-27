module tagion.testbench.services.helper_functions;

import std.format;
import std.stdio;
import tagion.behaviour;
import tagion.behaviour.BehaviourException : check;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.hibon.HiBON;
import tagion.script.TagionCurrency;
import tagion.tools.wallet.WalletInterface;
import tagion.wallet.SecureWallet;

@safe:



alias StdSecureWallet = SecureWallet!StdSecureNet;

TagionCurrency getWalletUpdateAmount(ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) {
    auto checkread = wallet.getRequestCheckWallet(hirpc);
    auto wallet_received = sendDARTHiRPC(sock_addr, checkread, hirpc);
    writefln("Received res", wallet_received.toPretty);
    check(!wallet_received.isError, format("Received HiRPC error: %s", wallet_received.toPretty));
    check(wallet.setResponseCheckRead(wallet_received), "wallet not updated succesfully");

    return wallet.calcTotal(wallet.account.bills);
}

TagionCurrency getWalletInvoiceUpdateAmount(ref StdSecureWallet wallet, string sock_addr, HiRPC hirpc) {
    auto owner_keys = wallet.getRequestUpdateWallet(hirpc);
    auto wallet_received = sendDARTHiRPC(sock_addr, owner_keys, hirpc);
    writefln("Received res", wallet_received.toPretty);
    check(!wallet_received.isError, format("Received HiRPC error: %s", wallet_received.toPretty));
    check(wallet.setResponseUpdateWallet(wallet_received), "wallet not updated succesfully");

    return wallet.calcTotal(wallet.account.bills);
}


