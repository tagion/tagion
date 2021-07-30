module test.dtest;
import std.stdio;
import p2p.node;
import lib = p2p.cgo.libp2p;
import p2p.go_helper;
import p2p.cgo.helper;

import std.conv : to;
import std.random;
import std.concurrency;
import std.conv;
import core.thread;
import std.concurrency;
import std.getopt;

void main(string[] args) {
    bool logger = true;
    ulong port = 81;
    string ip = "0.0.0.0";
     auto main_args = getopt(args,
        "ip|i", &ip,
        "logger|l", &logger,
        "port|p", &port
        );
    if(logger){
        EnableLogger();
    }
    auto node = new shared Node("/ip4/"~ ip ~"/tcp/" ~ to!string(port), 0);
    spawn(&eventListener, node);
    writeln(node.LlistenAddress);
    node.SubscribeToAddressUpdated("event_listener");
    node.SubscribeToRechabilityEvent("event_listener");

    // auto nat = node.startAutoNAT();

        auto bootstrap =         [
            "/ip4/13.95.3.250/tcp/4003/p2p/QmcWDHgRZxmDjbzb9LvhBk3aADPE8y1ZxZZrDBNhGpejDU",
            "/ip4/104.46.59.133/tcp/4002/p2p/QmUcW2v94aXUpFNUTiTcDW2e5kUpXG6KamP137zW2cxdfw",
            "/ip4/51.144.176.126/tcp/4001/p2p/QmWFJGCPGE9HgsTnVTX1AvdDyf2kZfM6QyzKhnBqLsoGKt",
            "/ip4/51.144.75.34/tcp/4000/p2p/QmUyGTxdqKpCyDT9hvL814fiDGJVKLZ4wZEoxGi1kZpmUq",
        ];
        foreach(addr; bootstrap){
            node.connect(addr);
        }
    do{
        // writeln("status: %s", nat.status);

        auto addr = readln();
        if(addr.length){
            addr=addr[0..$-1];
            node.connect(addr);
        }
        Thread.sleep(4.seconds);
        writeln(node.Addresses);
        // if(nat.status == NATStatus.NATStatusPublic){
        //     writeln(nat.address);
        // }
    // }while(nat.status == NATStatus.NATStatusUnknown);
    }while(true);
    writeln("done");
    readln();
}

static void eventListener(shared Node node){
    register("event_listener", thisTid);
    do{
        receive(
            (immutable(ubyte)[] data){
                writeln("RECEIVED EVENT");
                writeln(cast(string) data);
                writeln("PUBLIC ADDR: ", node.PublicAddress);
            }
        );
    }while(true);
}