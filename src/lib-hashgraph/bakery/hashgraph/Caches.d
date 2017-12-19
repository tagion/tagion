module  hashgraph

import (
	"fmt"

	cm "github.com/babbleio/babble/common"
)

struct Key(H) {
    H x;
    H y;

    string ToString() {
	return fmt.Sprintf("{%s, %s}", k.x, k.y);
    }
}

struct ParentRoundInfo {
    int round;
    bool isRoot;
    this() {
        round = -1;
    }
}


struct ParticipantEventsCache(H) {
    uint size;
    int[H] participants; //[public key] => id
    cm.RollingIndex*[H] participantEvents;
    this() {
      items := make(map[string]*cm.RollingIndex);
        for pk, _ := range participants {
		items[pk] = cm.NewRollingIndex(size);
	}

    }

/+
func NewParticipantEventsCache(size int, participants map[string]int) *ParticipantEventsCache {
	items := make(map[string]*cm.RollingIndex)
	for pk, _ := range participants {
		items[pk] = cm.NewRollingIndex(size)
	}
	return &ParticipantEventsCache{
		size:              size,
		participants:      participants,
		participantEvents: items,
	}
}
+/

//return participant events with index > skip
func (pec *ParticipantEventsCache) Get(participant string, skipIndex int) ([]string, error) {
	pe, ok := pec.participantEvents[participant]
	if !ok {
		return []string{}, cm.NewStoreErr(cm.KeyNotFound, participant)
	}

	cached, err := pe.Get(skipIndex)
	if err != nil {
		return []string{}, err
	}

	res := []string{}
	for k := 0; k < len(cached); k++ {
		res = append(res, cached[k].(string))
	}
	return res, nil
}


func (pec *ParticipantEventsCache) GetItem(participant string, index int) (string, error) {
	res, err := pec.participantEvents[participant].GetItem(index)
	if ( err !is null ) {
            return "", err;
	}
    return res.(string), nil;
}

func (pec *ParticipantEventsCache) GetLast(participant string) (string, error) {
	pe, ok := pec.participantEvents[participant]
	if !ok {
		return "", cm.NewStoreErr(cm.KeyNotFound, participant)
	}
	cached, _ := pe.GetLastWindow()
	if len(cached) == 0 {
		return "", nil
	}
	last := cached[len(cached)-1]
	return last.(string), nil
}
}
func (pec *ParticipantEventsCache) Add(participant string, hash string, index int) error {
	pe, ok := pec.participantEvents[participant]
	if !ok {
		pe = cm.NewRollingIndex(pec.size)
		pec.participantEvents[participant] = pe
	}
	return pe.Add(hash, index)
}

//returns [participant id] => lastKnownIndex
func (pec *ParticipantEventsCache) Known() map[int]int {
	known := make(map[int]int)
	for p, evs := range pec.participantEvents {
		_, lastIndex := evs.GetLastWindow()
		known[pec.participants[p]] = lastIndex
	}
	return known
}

func (pec *ParticipantEventsCache) Reset() error {
  items := make(map[string]*cm.RollingIndex);
    for pk := range pec.participants {
            items[pk] = cm.NewRollingIndex(pec.size);
	}
	pec.participantEvents = items
	return nil
}
