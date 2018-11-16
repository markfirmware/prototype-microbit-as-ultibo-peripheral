#!/bin/bash

elm make src/Main.elm

rm -f encodedspa*.inc

FULLSIZE=$(stat -c %s index.html)
REMAINING=$FULLSIZE
OFFSET=0
FILENUMBER=0
MAXLENGTH=32768
while (( 1 ))
do
    LENGTH=$REMAINING
    if (( $LENGTH == 0 ))
    then
        break
    fi
    if (( $LENGTH > $MAXLENGTH ))
    then
        LENGTH=$MAXLENGTH
    fi

    (( FILENUMBER+=1 ))
    FILENAME=encodedspa${FILENUMBER}.inc
    echo "{\$include $FILENAME}" >> encodedspa.inc
    echo "procedure AddPart${FILENUMBER};" > $FILENAME
    echo "begin" >> $FILENAME
    hexdump -s $OFFSET -n $LENGTH -v -e '16/1 "$%02.2x," "\n"' index.html \
        | sed "s/^/ AddData([/" \
        | sed "s/,$/]);/" \
        | sed "s/,\$  /    /g" \
        >> $FILENAME
    echo "end;" >> $FILENAME
    (( REMAINING-=LENGTH ))
    (( OFFSET+=LENGTH ))
done

cat >> encodedspa.inc << __EOF__

procedure BuildSpaBuffer;
begin
 Allocate($FULLSIZE);
__EOF__

I=1
while (( $I <= $FILENUMBER))
do
    echo " AddPart${I};" >> encodedspa.inc
    (( I+=1 ))
done
echo "end;" >> encodedspa.inc

mv encodedspa*.inc ..
