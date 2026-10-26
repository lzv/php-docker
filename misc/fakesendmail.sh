#!/bin/sh 
mail_directory="/tmp/mails"

numFile="$mail_directory/num"
if [ ! -f $numFile ]; then 
echo "0" > $numFile 
fi 

mkdir -p "$mail_directory/new"

num=`cat $numFile` 
num=$(($num + 1)) 
echo $num > $numFile 

name="$mail_directory/new/letter_$num.txt.eml"
while read line 
do 
echo $line >> $name
done 
chmod 777 $name
/bin/true

