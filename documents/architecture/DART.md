# DART Services

Takes care for DART CRUD commands.

Note.
The DART does not support `update` only `add` and `delete`. 

The DART database support 4 **DART(crud)** commands.
  - `dartBullseye` returns the bullseye (Merkle root) of the DART.
  - `dartRim` reads a list of branch(tree) for a given rim.
  - `dartRead` reads a list of archives from a list of fingerprints.
  - `dartModify` adds and deletes a list of archives form a Recorder.

The `dartModify` can only be executed inside the core node not externally.

The read-only dart command **DART(ro)** is defined as `dartBullseye`, `dartRim` and `dartRead`.

All archives in the database has a unique hash-value called fingerprint.

Input:
  - Recorder from the Transcript Service.
  - Recorder undo-instruction form the Transcript Service.

Request:
  - **DART(crud)** commands from DARTInterface services

Output:
  - Archive list as a Recorder format.

The acceptance criteria specification can be found in [DART Service](
/bdd/tagion/testbench/services/DART_Service.md)

```mermaid
sequenceDiagram
    participant Transcript
    participant DART 
    participant DARTInterface 
    participant Collector
    Transcript ->> DART: In/Out Archives(Recorder)
    DART ->> Collector: Archives(Recorder)
    DARTInterface ->> DART: DART(crud) 
```





