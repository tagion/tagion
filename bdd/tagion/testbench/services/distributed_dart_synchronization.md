Feature is a service that synchronize the DART local database with real remote nodes.
It should be used on node start up to ensure that local database is up-to-date.
In this test scenario we require that the remote database is static (not updated).

Scenario we run multiple nodes as a separate programs and synchronize the local database with them.
Given we have the empty local database.
Given we run multiple remote nodes with databases as a separate programs.
When we check that local database is not up-to-date.
Then we run the local database synchronization.
Then we check that bullseyes match.