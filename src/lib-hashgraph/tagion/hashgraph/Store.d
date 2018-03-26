module tagion.hashgraph.Store;

interface Store(H) {
    int CacheSize();
    immutable(int[H]) intParticipants();
    immutable(Event) GetEvent(string);
    bool SetEvent(Event);
    immutable(H[]) ParticipantEvents(const(H), int);
    immutable(H) ParticipantEvent(const(H) h, int);
    immutable(H) LastFrom(const(H) h, out bool inRoot);
    int[int] Known();
    H[] ConsensusEvents();
    uint ConsensusEventsCount();
    bool AddConsensusEvent(const(H));
    const(RoundInfo) GetRound(int);
    bool SetRound(int, RoundInfo) ;
    int LastRound();
    H[] RoundWitnesses(int);
    int RoundEvents(int);
    const(Root) GetRoot(const(H));
    bool Reset(const(Root)[const(H)] );
    bool Close();
}
