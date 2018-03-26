/**
   This takes care to the transport layer to other Baking Sheets (node)
   In the Bitcuits network
 */

module bakery.owen.BakingSheet;

import tango.time.Time;
private import bakery.owen.BitcuitBlock;

@safe
interface CoockieSheet {
    long distance(Position)(const(Position) A, const(Position)  B) const pure nothrow;
    /**
       connect to the network
     */
    bool connect(TimeSpan timeout);
    void disconnect();
    /**
       return number of modes connected
     */
    uint nodes() const pure nothrow;
    /**
        send data package on channel
    */
    void send(T)(uint channel, T data);
    /**
       broadcast the data package to all connected channels
     */
    void broadcast(T)(T data);
    @property
    uint queue() const pure nothrow;

}


@safe
class BakingSheet(Sheet) {
    static assert(is(Sheet : CoockieSheet));
    private const(Sheet) sheet;
    this(immutable(Sheet) sheet) {
        sheet = this.sheet;
    }



}
