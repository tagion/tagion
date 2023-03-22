# Tagion develop tools

This tool name `tagiondev` enables the of the contract interface and the DART database.

The tool should have support the flowing commands switches.
 
```
Usage:
tagiondev [<option>...] 
tagiondev <config.json>
                 --version display the version
-O             --overwrite Overwrite the config file
                      --ip Host gossip ip
                    --port Host gossip port 
                     --pid Write the pid to  file
-E                         Epoch time: default (5000 ms)
                     --tmp Sets temporaty work directory: default '/tmp/'
-p      --transaction-port Sets the listener transcation port: default 10800
                  --epochs Sets the number of epochs (0 for infinite): default: 4294967295
          --transcript-log Transcript log filename: default: transcript
           --dart-filename DART file name. Default: ./data/dart.drt
         --logger-filename Logger file name: default: /tmp/tagion.log
-l           --logger-mask Logger mask: default: 31
          --passphrasefile File with setted passphrase for keys pair
-h                  --help This help information.
```




