module tagion.testbench.services.helper_functions;

import tagion.communication.HiRPC;
import tagion.script.TagionCurrency;
import tagion.wallet.SecureWallet;
import tagion.behaviour;
import std.stdio;
import tagion.hibon.HiBON;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.tools.wallet.WalletInterface;
import tagion.behaviour.BehaviourException : check;
import std.format;

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



