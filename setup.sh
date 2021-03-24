#! /bin/sh
CMD=`basename $0`
if [ $# -ne 1 ]
then
	echo
	echo "$CMD unwinds the Inferno tar file in the <inferno_root> directory"
	echo
	echo "Usage: $CMD <inferno_root>"
	echo
	echo "    Where <inferno_root> is the inferno root directory"
	echo
	echo "        eg. \"$CMD /usr/inferno\""
	echo
	exit 1
fi
TDIR=$1
TNAME=`basename $1`
if [ ! "$TNAME" = "inferno" ]
then
	TDIR=$1/inferno
fi
TDIR0=`dirname $TDIR`

#look for the tar file
TAR=`dirname $0`/inferno.tar
if [ ! -f $TAR ]
then
	echo "ERROR: can't find tar file $TAR, exit 2"
	exit 2
fi

#will this overwrite anything?
if [ -d $TDIR/dis ]
then
	echo "Files exist in $TDIR ! Do you want to overwrite them?"
	echo "enter y or n"
	read ans
	if [ ! "$ans" = "y" ]
	then
		echo inferno not installed exit 3
		exit 3
	fi
fi

if [ ! -d $TDIR ]
then
	mkdir $TDIR
	if [ "$?" -ne "0" ]
	then
		echo "ERROR: can't make $TDIR, exit 4"
		exit 4
	fi
fi

if [ ! -w $TDIR ]
then
	echo "ERROR: $TDIR not writeable, exit 5"
	exit 5
fi

cd $TDIR0
echo "Unwinding the tar file, this will take a while!"
tar xopf $BASE/$TAR
if [ "$?" -ne "0" ]
then
	echo "ERROR: tar failed, exit 6"
	exit 6
fi

