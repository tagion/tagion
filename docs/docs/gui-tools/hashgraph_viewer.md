# Hashgraph Websocket viewer

## Howto get

https://github.com/tagion/tagion-visual-hashgraph

* /hashgraph-app - exactly javascript widget
* /hashgraph-d/src - example of the websocket backend
* /hashgraph-d/hashgraph-monitor - example of the frontend

## Howto build

- cd hashgraph-app 
- `npm install` to init pachage dependencies
- `npm run build` to build package
- use `dist/hashgraph.js`, `dist/hashgraph.js.map`, `assets/hashgraph.css` to deploy

## Hosto use

```
    <link rel="stylesheet" href=".../hashgraph.css"/>
    <script src=".../hashgraph.js"></script>
    ...

    hg = HG.hashgraph(
        'hashgraph',{                   // id of container div
            'tag':'HG INIT',            // tag o instance
            'transport': 'socket.io',   // "socket.io" or "websocket" - depending on backend
            'eventid': 'node',          // socket.io event type to subscribe
            'path':'/tagion/socket.io', // relative URL path to socket.io endpoint to get "tick" events
            'scrollctl': 'scrollgraph'  // id of checkbox input to associalte with "autoscroll" feature

        });

    // how to handle the "reset" button
    $('#rehashgraph').click(() => { hg.setAutoScroll(true); hg._reset(); });

```

WARNING!  Please note that the widget is based on the monitor json structure and should be updated if the structure changes. Refer to  https://github.com/tagion/tagion/blob/master/src/bin-tagionshell/tagion/tools/tagionshell.d and check the monitor\_map table in the dart\_worker function.
