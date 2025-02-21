Feature is a service that synchronize the DART database with another one.
It should be used on node start up to ensure that local database is up-to-date.
In this test scenario we require that the remote database is static (not updated).

Scenario is to connect to remote database which is up-to-date and read its bullseye.
Given we have a local database.
Given we have a remote node with a database.
When we read the bullseye from the remote database.
Then we check that the remote database is different from the local one.
This means that bullseyes are not the same. 

Scenario is to synchronize the local database.
Given we have the local database.
Given we have the remote database.
When the local database is not up-to-date.
Then we run the synchronization.
Then we check that bullseyes match.

Scenario is to synchronize the local database with multiple remote databases.
Given we have the local database.
Given we have multiple remote database.
When the local database is not up-to-date.
Then we check that those databases contain data.
Then we run the synchronization.
Then we check that bullseyes match.