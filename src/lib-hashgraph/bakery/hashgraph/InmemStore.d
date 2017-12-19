module bakery.hashgraph.InMemStore;

import (
	"strconv"

	cm "github.com/babbleio/babble/common"
)

class InmemStore {
    int cacheSize;
    int[string] participants;
    *cm.LRU eventCache;
    *cm.LRU roundCache;
    *cm.RollingIndex consensusCache;
    int totConsensusEvents;
    participantEventsCache *ParticipantEventsCache
    Root [string] roots;
    int lastRound;

    this(int[H] participants, int cacheSize ) {
      roots := make(map[string]Root);
	foreach( pk; participants ) {
            roots[pk] = NewBaseRoot();
	}
	return &InmemStore{
		cacheSize:              cacheSize,
		participants:           participants,
		eventCache:             cm.NewLRU(cacheSize, nil),
		roundCache:             cm.NewLRU(cacheSize, nil),
		consensusCache:         cm.NewRollingIndex(cacheSize),
		participantEventsCache: NewParticipantEventsCache(cacheSize, participants),
		roots:     roots,
		lastRound: -1,
	}
}


    uint CacheSize() {
	return s.cacheSize;
    }

    int[H] Participants() {
	return s.participants;
    }

    Event GetEvent(H key) (Event, error) {
	res, ok := s.eventCache.Get(key);
	if !ok {
		return Event{}, cm.NewStoreErr(cm.KeyNotFound, key)
	}

	return res.(Event), nil;
    }

    void SetEvent(Event event) error {
      key := event.Hex();
	_, err := s.GetEvent(key);
	if err != nil && !cm.Is(err, cm.KeyNotFound) {
		return err
	}
	if cm.Is(err, cm.KeyNotFound) {
		if err := s.addParticpantEvent(event.Creator(), key, event.Index()); err != nil {
                    return err;
		}
	}
	s.eventCache.Add(key, event);

        return nil;
    }

    void addParticpantEvent(H participant, string hash, int index) error {
	return s.participantEventsCache.Add(participant, hash, index);
    }

    H[] ParticipantEvents(H participant, int skip) {
        return s.participantEventsCache.Get(participant, skip);
    }

    H ParticipantEvent(H particant, int index int) {
        return s.participantEventsCache.GetItem(particant, index);
    }

    H LastFrom(H participant) (H last, out bool isRoot bool) {
	//try to get the last event from this participant
	last, err = s.participantEventsCache.GetLast(participant);
        if ( err != nil ) {
            return last;
        }
	//if there is none, grab the root
        if ( last == "" ) {
            root, ok := s.roots[participant];
            if ok {
                    last = root.X;
                    isRoot = true;
		} else {
                    err = cm.NewStoreErr(cm.NoRoot, participant);
            }
	}
        return;
    }

    int[int] Known() {
        return s.participantEventsCache.Known();
    }

func (s *InmemStore) ConsensusEvents() []string {
	lastWindow, _ := s.consensusCache.GetLastWindow()
	res := []string{}
	for _, item := range lastWindow {
		res = append(res, item.(string))
	}
	return res
}

func (s *InmemStore) ConsensusEventsCount() int {
	return s.totConsensusEvents
}

func (s *InmemStore) AddConsensusEvent(key string) error {
	s.consensusCache.Add(key, s.totConsensusEvents)
	s.totConsensusEvents++
	return nil
}

func (s *InmemStore) GetRound(r int) (RoundInfo, error) {
	res, ok := s.roundCache.Get(r)
	if !ok {
		return *NewRoundInfo(), cm.NewStoreErr(cm.KeyNotFound, strconv.Itoa(r))
	}
	return res.(RoundInfo), nil
}

func (s *InmemStore) SetRound(r int, round RoundInfo) error {
	s.roundCache.Add(r, round)
	if r > s.lastRound {
		s.lastRound = r
	}
	return nil
}

func (s *InmemStore) LastRound() int {
	return s.lastRound
}

func (s *InmemStore) RoundWitnesses(r int) []string {
	round, err := s.GetRound(r)
	if err != nil {
		return []string{}
	}
	return round.Witnesses()
}

func (s *InmemStore) RoundEvents(r int) int {
	round, err := s.GetRound(r)
	if err != nil {
		return 0
	}
	return len(round.Events)
}

func (s *InmemStore) GetRoot(participant string) (Root, error) {
	res, ok := s.roots[participant]
	if !ok {
		return Root{}, cm.NewStoreErr(cm.KeyNotFound, participant)
	}
	return res, nil
}

func (s *InmemStore) Reset(roots map[string]Root) error {
	s.roots = roots
	s.eventCache = cm.NewLRU(s.cacheSize, nil)
	s.roundCache = cm.NewLRU(s.cacheSize, nil)
	s.consensusCache = cm.NewRollingIndex(s.cacheSize)
	err := s.participantEventsCache.Reset()
	s.lastRound = -1
	return err
}

func (s *InmemStore) Close() error {
	return nil
}
