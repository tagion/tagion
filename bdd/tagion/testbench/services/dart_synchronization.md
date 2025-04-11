Feature is a service that synchronize the DART database with multiple nodes.
It should be used on node start up to ensure that local database is up-to-date.
In this test scenario we require that the remote database is static (not updated).

Scenario is to synchronize the local database with multiple remote databases.
Given we have the local database.
Given we have multiple remote database.
When the local database is not up-to-date.
Then we run the synchronization.
Then we check that bullseyes match.