
# Methods
The DART accepts the following hirpc methods from the shell to be send to it. 


## Cache elements
The cache should contain the following.
* The newest TagionHead. This points to the newest epoch that there is consensus on. See common.d TagionHead. It also includes a reference to the newest epoch as well as the global parameters.
* Newest bullseye. This should be the newest bullseye of the system. This information can be sent in the recorder.
* TagionBills. For now the cache contains only tagionbills. It should always point to the newest archive meaning that if a bill is in the cache. And the shell receives a new modify log deleting the bill from the dart, then it should be marked as deleted but still be present in the shell. 


It is very important that the archives received from the replicator log always are checked if they are in the cache and updated. This is to ensure that we do not show information in the cache which is not in the actual dart.

## HiRPC.search
```json
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@ss9OlT-gJvLzf0Ry09aYghIAWbiiXOzbH6mXMU0WNaI="
    ],
    "$msg": {
        "id": [
            "u32",
            1351920343
        ],
        "method": "search",
        "params": [
            [
                "*",
                "@TWFzxC7p7Tcw1aHC5CN2gNPSqi7dq7Z798o2WKCApgs="
            ],
            [
                "*",
                "@jkqA36nxWCBLUTI0mJU_vgYuVmOHAKuy0xmy-_sEIYY="
            ]
        ]
    },
    "$sign": [
        "*",
        "@NgUxEXyCAZNQq6BxHz3bZcowrNha6W-eDMHpJ_O7wC6TTNbBQ6OvpUsKvyceNrBcbfTEz6Ve2P9Gq9LspJ64yg=="
    ]
}
```
Where the params are the pubkeys of the TagionBills "$Y".
The above returns a HiRPC.Receiver containing all the bills that match the pubkeys. 
The cache logic is as follows.

Check the cache if the any bills pubkeys match the bills in cache pubkeys that are of `Archive.Type.ADD`. For the pubkeys who could not be found in the cache ask the dart with the same request removing the pubkeys that were found in the cache.

## HiRPC.checkRead
```json
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@ss9OlT-gJvLzf0Ry09aYghIAWbiiXOzbH6mXMU0WNaI="
    ],
    "$msg": {
        "method": "dartCheckRead",
        "params": {
            "dart_indices": [
                [
                    "*",
                    "@ymKqHokMS0HHzJnJuTJJtITMbColV5ycW0rXBAhnuOc="
                ],
                [
                    "*",
                    "@YRd5DG_gPfOopt0aleHWNVUt-cNLHhgZx_qtcsycfek="
                ],
                [
                    "*",
                    "@-9tYig8RuWw25sZGhBIc6I4QH3RScnJbxu-95se7s7Y="
                ]
            ]
        }
    },
    "$sign": [
        "*",
        "@HW1MxzMHrN0aMTDt5vneCNjjjZBL6yIQB4A_xj3i5rimfY39NmH8m7C--NgnWptoPlL9ThZ7sLaAqM49fzBRfA=="
    ]
}
```
The following command gives dart_indexes and returns all the indexes that were not found in the database. In other words we return all the DART_indexes back to the client where they could not be found in the dart. This means if all the users tagionbills are in the dart. We return an empty hirpc.checkRead response. This command is much faster than the hirpc.search and should be preffered any time it can.

Cache logic.
Check the cache if any of the dart_indexes marked as Archive.Type.ADD match. For all matches we remove the dartindex from our response.

## HiRPC.dartRead

Lowest priority since it is rarely used at the moment.

Looks up if the indexes are in the cache. If so return these. Else ask the system.



# The Archive structure.
The elements for the cache should be of type Archive. See: https://github.com/tagion/tagion/blob/current/src/lib-dart/tagion/dart/Recorder.d. 
The recorder that is received from the modify log contains all the archives. It can be deserialized in the following way:
auto `deserialized_recorder = factory.recorder(doc);`. Many examples can be found in the code for this.
To get a range on all the archives use the range operator:

```
foreach (archive; deserialized_recorder[]) {
...
}
```
The cache should always update all the archives it has. An idea for the cache to start with is to use a hashmap.
```
Archive[DARTIndex] cache;
```
Each time it receives something from the recorder it should update itself overwriting the archives that were in the cache with the new ones.

The archives that were marked as deleted will most likely never be inserted again. Therefore they will have to be deleted by the cache on a periodic basis based on their age.