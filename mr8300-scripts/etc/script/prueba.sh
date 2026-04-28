#!/bin/sh

# enter a size, 3, 10 (50 or 100 would also work, if you have the space)
TESTSIZE=10

TESTFILE=$TESTSIZE"mb.bin"
START=$(date +%s)
runtime=$(time wget -P /tmp/ ftp://ftp.xs4all.nl/pub/test/$TESTFILE)
SIZE=$(ls -la /tmp/$TESTFILE | awk '{ print $5}')
rm /tmp/$TESTFILE
END=$(date +%s)
DIFF=$(( $END - $START ))
AVE=$(( ( $SIZE / $DIFF) / 1024 ))

echo "Downloaded $TESTSIZE MB in $DIFF seconds "
echo -n "Average Speed: "
echo "$AVE Mbps"

exit 0
