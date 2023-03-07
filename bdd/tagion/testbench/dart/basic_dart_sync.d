
                module tagion.testbench.dart.basic_dart_sync;
                // Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;


                enum feature = Feature(
                    "DARTSynchronization",
                    ["All test in this bdd should use dart fakenet."]);
                
                alias FeatureContext = Tuple!(
                    FullSync, "FullSync",
PartialSync, "PartialSync",
RemoveArchive, "RemoveArchive",
FeatureGroup*, "result"
                );
            

                @safe @Scenario("Full sync.",
[])
                    class FullSync {
                        
                @Given("I have a dartfile1 with pseudo random data.")
                Document randomData() {
                        return Document();
                    }
                
                @Given("I have a empty dartfile2.")
                Document emptyDartfile2() {
                        return Document();
                    }
                
                @Given("I synchronize dartfile1 with dartfile2.")
                Document withDartfile2() {
                        return Document();
                    }
                
                @Then("the bullseyes should be the same.")
                Document theSame() {
                        return Document();
                    }
                
                    }
                
                @safe @Scenario("Partial sync.",
[])
                    class PartialSync {
                        
                @Given("I have a dartfile1 with pseudo random data.")
                Document randomData() {
                        return Document();
                    }
                
                @Given("I have added some of the pseudo random data to dartfile2.")
                Document toDartfile2() {
                        return Document();
                    }
                
                @Given("I synchronize dartfile1 with dartfile2.")
                Document withDartfile2() {
                        return Document();
                    }
                
                @Then("the bullseyes should be the same.")
                Document theSame() {
                        return Document();
                    }
                
                    }
                
                @safe @Scenario("Remove archive",
[])
                    class RemoveArchive {
                        
                @Given("#two_archives")
                Document twoarchives() {
                        return Document();
                    }
                
                @Given("i remove archive1.")
                Document archive1() {
                        return Document();
                    }
                
                @Then("check that archive2 has been moved from the branch in sector A.")
                Document a() {
                        return Document();
                    }
                
                @Then("check the bullseye.")
                Document bullseye() {
                        return Document();
                    }
                
                    }
                