module tagion.tools.boot.genesis;

import tagion.hibon.HiBONtoText : decode;
import tagion.crypto.Types : Pubkey;
import std.algorithm;
import std.array;
import tagion.tools.toolsexception;
import tagion.utils.StdTime;
import tagion.script.namerecords;
import tagion.hibon.HiBONJSON;
import tagion.basic.Types;
import tagion.hibon.Document;
import tagion.script.common;

@safe:
void createGenesis(const(string[]) nodes_param, Document testamony) {
    import std.stdio;

    static struct NodeSettings {
        string name;
        Pubkey owner;
        string address;
        this(string params) {
            const list = params.split(",");
            check(list.length == 3,
                    "Argument %s should have three parameter seperated with a ','", params);
            name = list[0];
            owner = Pubkey(list[1].decode);
            address = list[2];
        }
    }

    const node_settings = nodes_param
        .map!((param) => NodeSettings(param))
        .array;
    writefln("%s", node_settings);

    const time = currentTime;
    NetworkNameCard[] name_cards;
    NetworkNodeRecord[] node_records;
    foreach (node_setting; node_settings) {
        NetworkNameCard name_card;
        name_card.name = node_setting.name;
        name_card.owner = node_setting.owner.mut;
        //name_card.address=node_setting.address;
        name_card.lang = "en";
        name_card.time = cast(sdt_t) time;
        name_cards ~= name_card;
        NetworkNodeRecord node_record;
        node_record.channel = node_setting.owner.mut;
        node_record.name = node_setting.name;
        node_record.time = cast(sdt_t) time;
        node_record.state = NetworkNodeRecord.State.ACTIVE;
        node_record.address = node_setting.address;
        node_records ~= node_record;
    }
    GenesisEpoch genesis_epoch;
    genesis_epoch.epoch_number = 0;
    genesis_epoch.nodes = node_settings
        .map!((node_setting) => node_setting.owner.mut)
        .array;
    //.sort;
    genesis_epoch.time = cast(sdt_t) time;
    genesis_epoch.testamony = testamony;
    name_cards.each!((name_card) => writefln("%s", name_card.toPretty));
    node_records.each!((name_card) => writefln("%s", name_card.toPretty));
    writefln("%s", genesis_epoch.toPretty);
    version (none) {
        const nodekeys = nodekey_text
            .map!(key => Pubkey(key.decode))
            .array;
        writefln("nodekeys=%(%(%02x%) %)", nodekeys);
    }
}
