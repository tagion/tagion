import std.getopt;
import std.path;
import std.format;
import std.algorithm : map, max, min, filter, each, splitter;
import std.range : lockstep, zip, takeExactly, only;
import std.string : strip, toLower;
import std.conv : to;
import std.array : join;
import std.exception : assumeUnique, assumeWontThrow;
import std.string : representation;
import core.time : MonoTime;
import std.socket : InternetAddress, AddressFamily;
import core.thread;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;

import tagion.basic.Basic : basename, Buffer, Pubkey;
import tagion.script.TagionCurrency;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet, scramble;
import tagion.wallet.WalletRecords : RecoverGenerator, DevicePIN, Quiz;
import tagion.utils.Term;
import tagion.basic.Message;
import tagion.utils.Miscellaneous;
import tagion.options.HostOptions;

import tagion.communication.HiRPC;
import tagion.network.SSLSocket;
import tagion.Keywords;
import std.stdio;
import std.file; 
import std.range : iota;
import std.array;
import std.csv;

import std.algorithm;

import tagion.communication.HandlerPool;
import tagion.crypto.Cipher;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.aes.AESCrypto;
import tagion.script.StandardRecords;
import tagion.wallet.KeyRecover;
import tagion.wallet.SecureWallet;
import std.typecons;
import std.base64;


alias StdSecureWallet = SecureWallet!StdSecureNet;

int main(string[] args){

    immutable program = args[0];
    string path_wallet;
    string path_device;
    string pin_code;
    string path_contract = "contract.hibon";
    string path_csv = "data.csv";
    

    if (args.length > 1) {
        path_wallet = args[1];
        
        if (args.length > 2) {
            path_device = args[2];
            
            if (args.length > 3) {
                pin_code = args[3];

                if (args.length > 4) {
                    path_contract = args[4];
                }

                if (args.length > 5) {
                    path_csv = args[5];
                }

                if (args.length > 6) {
                    assert(0, "A lot of arguments");
                }
            }
            else {
                assert(0, "No pincode");
            }
        }
        else {
            assert(0, "No device pincode file");
        }
    }
    else {
        assert(0, "No input file");
    }
   
    auto file_r = File(path_csv, "r");
    Buffer[] invoises_buf;
    foreach (record; file_r.byLine.joiner("\n").csvReader!(Tuple!(string, string, int)))
    {
        writeln(record[0]);
        invoises_buf ~= cast(Buffer)Base64.decode(record[0]);
    }

    Invoice[] invoices;
    foreach (buf; invoises_buf)
    {
        auto doc = Document(buf);
        writeln(doc);
        Invoice invoice = Invoice(doc);
        invoices ~= invoice;
    }

    writeln(invoices);

    Document doc_wallet = path_wallet.fread;
    Document doc_pin = "device.hibon".fread;

    StdSecureWallet secure_wallet = StdSecureWallet(doc_wallet, doc_pin);

    secure_wallet.login(pin_code);

    SignedContract s_contract;
    secure_wallet.payment(cast(const)invoices, s_contract);
    writeln(s_contract.signs); 
    writeln(s_contract.input);


    std.file.write(path_contract, s_contract.toHiBON.serialize);

    return 1;
}
