#!/bin/bash

SUFFIX=""
DEVELOPMENT=0
SHORT=0

getopts 's' OPTION
if [[ $OPTION == "s" ]]
then
    SHORT=1
fi

BRANCH=$(git branch | grep '\*')
read -r IGNORE1 BRANCH <<< $BRANCH
if [[ $BRANCH != "master" ]]
then
    if [[ $SHORT == 1 ]]
    then
        SUFFIX+=""
    else
        SUFFIX+="-$BRANCH"
    fi
fi

git status | egrep 'new file:|modified:|deleted:|renamed:' > /dev/null
if [[ $? == 0 ]]
then
    if [[ $SHORT == 1 ]]
    then
        SUFFIX+="?"
    else
        SUFFIX+="+changes"
    fi
fi

NTH=0
while read -r IGNORE1 DATE
do
    DATE=$(date -d$DATE -u +%Y%m%d)
    if [[ $LASTDATE == "" ]]
    then
        LASTDATE=$DATE
    fi
    if [[ $DATE != $LASTDATE ]]
    then
        break
    fi
    VERSION=v$LASTDATE.$NTH$SUFFIX
    let NTH++
done < <( git log --date=iso-strict | grep ^Date: )
echo $VERSION
