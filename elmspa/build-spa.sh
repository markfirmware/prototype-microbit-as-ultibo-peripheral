#!/bin/bash

elm make src/Main.elm --optimize --output=elm.js

uglifyjs elm.js --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output=elm.min.js

rm -f index.html
cat >> index.html << __EOF__
<html>
  <head>
    <script>
__EOF__
cat elm.min.js >> index.html
cat >> index.html << __EOF__

    </script>
  </head>
  <body>
    <div id="elm"/>
    <script> var app = Elm.Main.init({node: document.getElementById('elm')}); </script>
    <script> var clipboard = new Clipboard('.copy-button') </script>
  </body>
</html>
__EOF__

rm -f elm.js elm.min.js encodedspa*.inc

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
