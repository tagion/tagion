module bakery.hashgraph.BadgerStore;

// import (
// 	"fmt"
// 	"os"
// 	"strconv"

// 	cm "github.com/babbleio/babble/common"
// 	"github.com/dgraph-io/badger"
// )

enum {
    participantPrefix = "participant",
    rootSuffix        = "root",
    roundPrefix       = "round",
    topoPrefix        = "topo"
};

class BadgerStore(H) {
    int[string] participants;
    InmemStore inmemStore;
    badger.DB db;
    string path;


//NewBadgerStore creates a brand new Store with a new database
    this(int[H] participants, int cacheSize, string path) {
      auto inmemStore = NewInmemStore(participants, cacheSize);
      auto opts = badger.DefaultOptions;
      opts.Dir = path;
      opts.ValueDir = path;
      opts.SyncWrites = false;
      handle, err := badger.Open(opts);
	if err != nil {
		return nil, err
	}
	store := &BadgerStore{
		participants: participants,
		inmemStore:   inmemStore,
		db:           handle,
		path:         path,
	}
	if err := store.dbSetParticipants(participants); err != nil {
		return nil, err
	}
	if err := store.dbSetRoots(inmemStore.roots); err != nil {
		return nil, err
	}
	return store, nil
            }

//LoadBadgerStore creates a Store from an existing database
static BadgerStore LoadBadgerStore(cacheSize int, string path) {

	if _, err := os.Stat(path); err != nil {
		return nil, err
	}

	opts := badger.DefaultOptions
	opts.Dir = path
	opts.ValueDir = path
	opts.SyncWrites = false
	handle, err := badger.Open(opts)
	if err != nil {
		return nil, err
	}
	store := &BadgerStore{
		db:   handle,
		path: path,
	}

	participants, err := store.dbGetParticipants()
	if err != nil {
		return nil, err
	}

	inmemStore := NewInmemStore(participants, cacheSize)

	//read roots from db and put them in InmemStore
	roots := make(map[string]Root)
	for p := range participants {
		root, err := store.dbGetRoot(p)
		if err != nil {
			return nil, err
		}
		roots[p] = root
	}

	if err := inmemStore.Reset(roots); err != nil {
		return nil, err
	}

	store.participants = participants
	store.inmemStore = inmemStore

	return store, nil
}


//==============================================================================
//Implement the Store interface

    int CacheSize() {
	return inmemStore.CacheSize();
    }

    int[H] Participants() {
	return s.participants;
    }

    Event!H GetEvent(key string) {
	//try to get it from cache
	event = inmemStore.GetEvent(key);
	//try to get it from db
        if ( event !is null ) {
            event = s.dbGetEvent(key)
	}
	return event;
    }

    void SetEvent(event Event) {
	//try to add it to the cache
	if err := s.inmemStore.SetEvent(event); err != nil {
            return err;
	}
	//try to add it to the db
	return s.dbSetEvents([]Event{event});
    }

    immutable(H)[] ParticipantEvents(H participant, int skip) {
	auto result = inmemStore.ParticipantEvents(participant, skip);
	if ( result is null ) {
            result = s.dbParticipantEvents(participant, skip);
	}
	return result;
    }

    immutable(H) ParticipantEvent(participant string, index int) {
	auto result = inmemStore.ParticipantEvent(participant, index);
        if ( result is null ) {
            result = s.dbParticipantEvent(participant, index);
	}
	return result;
    }

    immutable(H) LastFrom(participant string, out bool isRoot) {
	return s.inmemStore.LastFrom(participant);
    }

    int[int] Known() {
	int[int] known;
	foreach(p, pid; participants) {
          auto index = -1;
          bool isRoot;
          auto last = s.LastFrom(p, isRoot);
          if ( last !is null ) {
              if (isRoot) {
                  root = GetRoot(p);
                  if (root) {
                      last = root.X;
                      index = root.Index;
                  }
                  else {
                      auto lastEvent = s.GetEvent(last);
                      if ( lastEverr is null ) {
                          index = lastEvent.Index();
                      }
                  }
              }
          }
          known[pid] = index;
	}
	return known;
    }

    immutable(H)[] ConsensusEvents() {
	return inmemStore.ConsensusEvents();
    }

    int ConsensusEventsCount() {
	return s.inmemStore.ConsensusEventsCount();
    }

    void AddConsensusEvent(key string) {
	inmemStore.AddConsensusEvent(key);
    }

    const(RoundInfo) GetRound(int r) {
	auto result = inmemStore.GetRound(r)
            if ( result is null ) {
		result = dbGetRound(r);
            }
	return result;
    }

    bool SetRound(int r, RoundInfo round) {

	if ( inmemStore.SetRound(r, round) ) {
            return true;
	}
	return dbSetRound(r, round);
    }

    int LastRound() {
	return inmemStore.LastRound();
    }

    H[] RoundWitnesses(int r) {
	auto round = s.GetRound(r);
	if (round is null) {
            return null;
	}
	return round.Witnesses();
    }

    int RoundEvents(int r) {
	auto round = GetRound(r);
	return round.Events.length;
    }

    const(Root) GetRoot(const(H) participant) {
	auto root = inmemStore.GetRoot(participant);
	if (root is null) {
            root = dbGetRoot(participant);
	}
	return root;
    }

    bool Reset(Root[H] roots)  {
	return s.inmemStore.Reset(roots);
    }

    bool Close() {
	if ( inmemStore.Close() ) {
            return true;
	}
	return db.Close();
    }
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//DB Methods

    const(Event) dbGetEvent(H key) {
	immutable(ubyte)[] eventBytes;
	err := s.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte(key))
		if err != nil {
			return err
		}
		eventBytes, err = item.Value()
		return err
	})

	if err != nil {
		return nullEvent{}, err
	}

	event := new(Event)
	if err := event.Unmarshal(eventBytes); err != nil {
		return Event{}, err
	}

	return *event;
    }

    bool dbSetEvents(Event[] events) error {
      auto tx = db.NewTransaction(true);
      defer tx.Discard();
      foreach( event; events) {
        auto eventHex := event.Hex();
          auto val = event.Marshal();
		if err != nil {
			return err
		}
		//check if it already exists
		bool isnew = false;
		_, err = tx.Get([]byte(eventHex))
		if err != nil && isDBKeyNotFound(err) {
			new = true
		}
		//insert [event hash] => [event bytes]
		if err := tx.Set([]byte(eventHex), val); err != nil {
			return err
		}

		if new {
			//insert [topo_index] => [event hash]
			topoKey := topologicalEventKey(event.topologicalIndex)
			if err := tx.Set(topoKey, []byte(eventHex)); err != nil {
				return err
			}
			//insert [participant_index] => [event hash]
			peKey := participantEventKey(event.Creator(), event.Index())
			if err := tx.Set(peKey, []byte(eventHex)); err != nil {
				return err
			}
		}
	}
	return tx.Commit(nil)
}

    const(Event)[] dbTopologicalEvents() {
        Event[] result;
	int t;
	err := s.db.View(func(txn *badger.Txn) error {
		key := topologicalEventKey(t)
		item, errr := txn.Get(key)
		for errr == nil {
			v, errrr := item.Value()
			if errrr != nil {
				break
			}

			evKey := string(v)
			eventItem, err := txn.Get([]byte(evKey))
			if err != nil {
				return err
			}
			eventBytes, err := eventItem.Value()
			if err != nil {
				return err
			}

			event := new(Event)
			if err := event.Unmarshal(eventBytes); err != nil {
				return err
			}
			res = append(res, *event)

			t++
			key = topologicalEventKey(t)
			item, errr = txn.Get(key)
		}

		if !isDBKeyNotFound(errr) {
			return errr
		}

		return nil
	})

	return res, err
            }

    immutable(H)[] dbParticipantEvents(H participant, int skip) {
        immutable(H)[] result;
	err := s.db.View(func(txn *badger.Txn) {
              immutable i = skip + 1;
              immutable key = participantEventKey(participant, i);
              item = txn.Get(key);
		for errr == nil {
			v, errrr := item.Value()
			if errrr != nil {
				break
			}
			res = append(res, string(v))

			i++
			key = participantEventKey(participant, i)
			item, errr = txn.Get(key)
		}

		if !isDBKeyNotFound(errr) {
			return errr
		}

		return nil
	})
            return result;
}

    immutable(H) dbParticipantEvent(H participant, int index int) {
	data := []byte{}
      key := participantEventKey(participant, index);
	err := s.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get(key)
		if err != nil {
			return err
		}
		data, err = item.Value()
		return err
	})
	if err != nil {
		return "", err
	}
	return string(data), nil
            }

func (s *BadgerStore) dbSetRoots(roots map[string]Root) error {
	tx := s.db.NewTransaction(true)
	defer tx.Discard()
	for participant, root := range roots {
		val, err := root.Marshal()
		if err != nil {
			return err
		}
		key := participantRootKey(participant)
		//insert [participant_root] => [root bytes]
		if err := tx.Set(key, val); err != nil {
			return err
		}
	}
	return tx.Commit(nil)
}

func (s *BadgerStore) Root dbGetRoot(participant string) (Root, error) {
	var rootBytes []byte
            immutable key = participantRootKey(participant);
	err := s.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get(key)
		if err != nil {
			return err
		}
		rootBytes, err = item.Value()
		return err
	})

	if err != nil {
		return Root{}, err
	}

	root := new(Root)
	if err := root.Unmarshal(rootBytes); err != nil {
		return Root{}, err
	}

	return *root, nil
}

RoundInfo dbGetRound(int index) {
    immutable(ubyte)[] roundBytes;
    immutable key = roundKey(index);
  err := s.db.View(func(txn *badger.Txn) error {
          immutable item = txn.Get(key)
		if err != nil {
			return err
		}
		roundBytes, err = item.Value()
		return err
	})

	if err != nil {
		return *NewRoundInfo(), err
	}

	roundInfo := new(RoundInfo)
	if err := roundInfo.Unmarshal(roundBytes); err != nil {
		return *NewRoundInfo(), err
	}

	return *roundInfo, nil
}

func (s *BadgerStore) dbSetRound(index int, round RoundInfo) error {
	tx := s.db.NewTransaction(true)
	defer tx.Discard()

	key := roundKey(index)
	val, err := round.Marshal()
	if err != nil {
		return err
	}

	//insert [round_index] => [round bytes]
	if err := tx.Set(key, val); err != nil {
		return err
	}

	return tx.Commit(nil)
}

func (s *BadgerStore) dbGetParticipants() (map[string]int, error) {
	res := make(map[string]int)
	err := s.db.View(func(txn *badger.Txn) error {
		it := txn.NewIterator(badger.DefaultIteratorOptions)
		prefix := []byte(participantPrefix)
		for it.Seek(prefix); it.ValidForPrefix(prefix); it.Next() {
			item := it.Item()
			k := string(item.Key())
			v, err := item.Value()
			if err != nil {
				return err
			}
			//key is of the form participant_0x.......
			pubKey := k[len(participantPrefix)+1:]
			id, err := strconv.Atoi(string(v))
			if err != nil {
				return err
			}
			res[pubKey] = id
		}
		return nil
	})
	return res, err
}

func (s *BadgerStore) dbSetParticipants(participants map[string]int) error {
	tx := s.db.NewTransaction(true)
	defer tx.Discard()
	for participant, id := range participants {
		key := participantKey(participant)
		val := []byte(strconv.Itoa(id))
		//insert [participant_participant] => [id]
		if err := tx.Set(key, val); err != nil {
			return err
		}
	}
	return tx.Commit(nil)
}
}
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

func isDBKeyNotFound(err error) bool {
	return err.Error() == badger.ErrKeyNotFound.Error()
}

// func mapError(err error, key string) error {
//     if err != nil {
//             if isDBKeyNotFound(err) {
//                     return cm.NewStoreErr(cm.KeyNotFound, key);
//                         }
// 	}
//     return err
// }
//==============================================================================
//Keys

immutable(byte)[] topologicalEventKey(int index) {
    return []byte(fmt.Sprintf("%s_%09d", topoPrefix, index));
}

immutable(ubyte)[] participantKey(H participant) {
    return []byte(fmt.Sprintf("%s_%s", participantPrefix, participant));
}

immutable(ubyte)[] participantEventKey(H participant, int index) {
    return []byte(fmt.Sprintf("%s_%09d", participant, index));
}

immutable(ubyte)[] participantRootKey(H participant string) {
    return []byte(fmt.Sprintf("%s_%s", participant, rootSuffix));
}

immutable(ubyte)[] roundKey(index int) {
    return []byte(fmt.Sprintf("%s_%09d", roundPrefix, index));
}
