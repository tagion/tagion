CHARS1=bcdfghklmnpqrstvwxz
CHARS2=aeiouy
CHARS3=bdfgklmnpstvxz
RESULT=${CHARS1:RANDOM%${#CHARS1}:1}
RESULT=$RESULT${CHARS2:RANDOM%${#CHARS2}:1}
RESULT=$RESULT${CHARS1:RANDOM%${#CHARS1}:1}
RESULT=$RESULT${CHARS2:RANDOM%${#CHARS2}:1}
RESULT=$RESULT${CHARS1:RANDOM%${#CHARS1}:1}
RESULT=$RESULT${CHARS2:RANDOM%${#CHARS2}:1}
RESULT=$RESULT${CHARS3:RANDOM%${#CHARS1}:1}

echo $RESULT