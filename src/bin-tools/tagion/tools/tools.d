module tagion.tools.tools;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import tagionwave = tagion.tools.tagionwave;
    import dartutil = tagion.tools.dartutil;
    import hibonutil = tagion.tools.hibonutil;
    import tagionwallet = tagion.tools.tagionwallet;
    import tagionboot = tagion.tools.tagionboot;
    import blockutil = tagion.tools.blockutil;
    import tprofview = tagion.tools.tprofview;
    import recorderchain = tagion.tools.recorderchain;

    alias alltools = AliasSeq!(tagionwave, dartutil, hibonutil, tagionwallet, tagionboot, blockutil, tprofview, recorderchain);
    mixin doOneMain!(alltools);
    return do_main(args);
}
