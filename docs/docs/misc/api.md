




# Shell user api
## Send contract
The user can send a hirpc contract to the shell. Two replies to user. Either succes in sending to kernel or error from shell.
* Check HiBON validity
* Send to kernel
* Reply back to user kernel status

## dart read
input: DARTIndex[] output Archive[].
The user can ask for a specific archive on dartindex.

## dart check indexes
input: DARTIndex[] output DARTIndex[] (all dartindexes that were not in the dart).
The user wants to check if there archives are located in the database without getting the archive returned.

## Network status (pure shell command from lazy cache)
output: current status and last update timestamp.
The user can ask if the network is running

# Shell kernel api
## Send contract

## async dart read
## async dart check indexes

## subscribe to recorder (list of new archives).

## subscribe to status update.

If the dartindex is in cache -> return archive. Otherwise ask kernel/dart.
If some dartindexes are in cache, but others are not. Then only request the ones not in cache from kernel.


