
                module tagion.testbench.services.dart_Synchronization;
                // Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;


                enum feature = Feature(
                    "is a service that synchronizes the DART database with another one.",
                    ["It should be used on node start up to ensure that local database is up-to-date.",
"In this test scenario we require that the remote database is static (not updated)."]);
                
                alias FeatureContext = Tuple!(
                    IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye, "IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye",
IsToSynchronizeTheLocalDatabase, "IsToSynchronizeTheLocalDatabase",
FeatureGroup*, "result"
                );
            

                @safe @Scenario("is to connect to remote database which is up-to-date and read its bullseye.",
[])
                    class IsToConnectToRemoteDatabaseWhichIsUptodateAndReadItsBullseye {
                        
                @Given("we have a local database.")
                Document localDatabase() {
                        return Document();
                    }
                
                @Given("we have a remote node with a database.")
                Document aDatabase() {
                        return Document();
                    }
                
                @When("we read the bullseye from the remote database.")
                Document remoteDatabase() {
                        return Document();
                    }
                
                @Then("we check that the remote database is different from the local one.")
                Document localOne() {
                        return Document();
                    }
                
                    }
                
                @safe @Scenario("is to synchronize the local database.",
[])
                    class IsToSynchronizeTheLocalDatabase {
                        
                @Given("we have the local database.")
                Document localDatabase() {
                        return Document();
                    }
                
                @Given("we have the remote database.")
                Document remoteDatabase() {
                        return Document();
                    }
                
                @When("the local database is not up-to-date.")
                Document notUptodate() {
                        return Document();
                    }
                
                @Then("we run the synchronization.")
                Document theSynchronization() {
                        return Document();
                    }
                
                @Then("we check that bullseyes match.")
                Document bullseyesMatch() {
                        return Document();
                    }
                
                    }
                
