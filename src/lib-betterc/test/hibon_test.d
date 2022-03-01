// /// \file hibon_test.d

// import beterC_hibon = tagion.betterC.hibon.HiBON;
// import usual_hibon = tagion.hibon.HiBON;

// unittest {
//     auto betterC_h = beterC_hibon.HiBON();
//     auto d_hibon = new usual_hibon.HiBON();

//     betterC_h["a"] = 1;
//     betterC_h["b"] = 2;
//     betterC_h["c"] = 3;
//     betterC_h["d"] = 4;

//     d_hibon["a"] = 1;
//     d_hibon["b"] = 2;
//     d_hibon["c"] = 3;
//     d_hibon["d"] = 4;

//     assert(betterC_h.hasMember("b"));
//     betterC_h.remove("b");
//     assert(!betterC_h.hasMember("b"));

//     assert(d_hibon == betterC_h);

// }
