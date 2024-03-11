module tagion.tools.boot.genesis;

@safe:

import std.algorithm;
import std.array;
import tagion.basic.Types;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONtoText : decode;
import tagion.script.common;
import tagion.script.namerecords;
import tagion.tools.Basic;
import tagion.tools.toolsexception;
import tagion.utils.StdTime;

struct NodeSettings {
    string name;
    Pubkey owner;
    string address;
    this(string name, Pubkey owner, string address) pure nothrow {
        this.name = name;
        this.owner = owner;
        this.address = address;
    }
    this(string params) {
        const list = params.split(",");
        check(list.length == 3,
            "Argument %s should have three parameter seperated with a ','", params);
        name = list[0];
        owner = Pubkey(list[1].decode);
        address = list[2];
    }
}

Document[] createGenesis(const(string[]) nodes_param, Document testamony, TagionGlobals globals) {
    const node_settings = nodes_param
        .map!((param) => NodeSettings(param))
        .array;

    return createGenesis(node_settings, testamony, globals);
}

@safe:
Document[] createGenesis(const(NodeSettings[]) node_settings, Document testamony, TagionGlobals globals) {
    import std.stdio;

    Document[] result;


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
    auto node_pubkeys = node_settings
            .map!((node_setting) => node_setting.owner.mut)
            .array;
            /* .sort; */

    genesis_epoch.nodes = node_pubkeys;
    genesis_epoch.time = cast(sdt_t) time;
    genesis_epoch.testamony = testamony;
    genesis_epoch.globals = globals;

    Active active = Active(node_pubkeys);
    
    name_cards.each!((name_card) => verbose("%s", name_card.toPretty));
    node_records.each!((name_card) => verbose("%s", name_card.toPretty));
    verbose("%s", genesis_epoch.toPretty);
    result ~= name_cards.map!((name_card) => name_card.toDoc).array;

    result ~= node_records.map!(node_record => node_record.toDoc).array;
    result ~= genesis_epoch.toDoc;
    result ~= active.toDoc;
    return result;
}
