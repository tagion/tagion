module bakery.hashgraph.Store;

interface Store(H) {
    int CacheSize();
    immutable(int[H]) intParticipants();
    Event GetEvent(string);
    bool SetEvent(Event);
    ([]string, error) ParticipantEvents(string, int);
    (string, error) ParticipantEvent(string, int);
    (string, bool, error) LastFrom(string);
    int[int] Known();
    H[] ConsensusEvents();
    uint ConsensusEventsCount();
    error AddConsensusEvent(H);
    (RoundInfo, error) GetRound(int);
    error SetRound(int, RoundInfo) ;
    int LastRound();
    H[] RoundWitnesses(int);
    int RoundEvents(int);
    (Root, error) GetRoot(H);
    error Reset(Root[H] );
    error Close();
}
