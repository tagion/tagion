# DART Recorder 

The Recorder is use to add/remove and undo data stored in the DART.

A recorder contains a list of Archives and each archive has a type. 
**[NONE, REMOVE, ADD]**

Archive types.
  - NONE : Typical use when a archives is read from the DART.
  - REMOVE : Set if an archives should be removed form the DART.
  - ADD : Set if an archive should be added to the DART.


## Archive

[Archive](https://ddoc.tagion.org/tagion.dart.Recorder.Archive)

| Name        | D-Type     | Description                                   | Required  |
| ----------- | ---------- | ----------------------                        | :-------: |
| `$t`        | [Type]     | Is the archive-type                           | Yes       |
| `$a`        | [Document] | Is the filed(leave) as a Document             | No        |
| `$#`        | [Buffer]   | Is a hash of the filed(leave) (Called a STUB) | No        |

Note. An archive should contain either a `$a` value or `$#`. 

The STUB `$#` is used to hold the hash for filed data when the DART in sharding.
