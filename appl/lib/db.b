implement DB;

BLKSIZ:		con 8192;

include "sys.m";
include "db.m";

sys:	Sys;
print, sprint, fprint, read, write: import sys;
DB_Handle: import DB;

conn:	ref Sys->Connection;
readbuf:	array of byte;
rbuf:		array of byte;

open(addr, username, password, dbname: string) : (ref DB_Handle, list of string)
{
    sys = load Sys "$Sys";

    (ok, c) := sys->dial(addr, nil);
    if(ok < 0)
	return (nil, (sprint("DB init can't dial %s: %r", addr) :: nil) );

    dbh: DB_Handle;
    dbh.conn = ref c;
    readbuf = array[BLKSIZ] of byte;
    rbuf = array[BLKSIZ] of byte;

    logon := array of byte (username + "/" + password + "/" + dbname + "/\n");
    logon[len logon - 1] = byte 0;
    write(dbh.conn.dfd, logon, len logon);

    n := read(dbh.conn.dfd, rbuf, BLKSIZ);
    (count, strlist) := sys->tokenize(string rbuf[0:n], "#\n");
	
    if (count < 1) 
	return (nil, ("Message format error from daemon" :: nil));
    else {
	retcode := int hd strlist;
	if (retcode == 0) {
	    return (ref dbh, nil);
	}
	else {
	    return (nil, tl strlist);
	}
    }
}


DB_Handle.SQL(handle: self ref DB_Handle, command: string): (int, list of string)
{
    outbuf := array of byte ( "W#" + command + "\n");
    outbuf[len outbuf -1] = byte 0;
    sys->write(handle.conn.dfd, outbuf, len outbuf);

    nbyte := sys->read(handle.conn.dfd, readbuf, 1024);

    (count, strlist) := sys->tokenize(string readbuf[0:nbyte], "#\n");
	
    if (count < 1) 
	return (-1, ("Message format error from daemon" :: nil));
    else {
	retcode := int hd strlist;
	if (retcode == 0) {
	    return (0, nil);
	}
	else {
	    return (-1, tl strlist);
	}
    }
}

DB_Handle.columns(handle: self ref DB_Handle) : int
{
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte "C#\n";
    outbuf[2] = byte 0;
    sys->write(handle.conn.dfd, outbuf, 3);
	
    nbyte := sys->read(handle.conn.dfd, buf, BLKSIZ);
    value := int (string buf[0:nbyte]);
    return value;
}

DB_Handle.nextRow(handle: self ref DB_Handle) : int
{
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte "N#\n";
    outbuf[2] = byte 0;
    sys->write(handle.conn.dfd, outbuf, 3);
	
    nbyte := sys->read(handle.conn.dfd, buf, BLKSIZ);
    value := int (string buf[0:nbyte]);
    return value;
}

DB_Handle.read(handle: self ref DB_Handle, columnI: int) : (int, array of byte)
{
    nbytes:	int;
    length:=	int 0;
    sgn :=	int 0;
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte sys->sprint("R#%d\n", columnI);
    outbuf[len outbuf -1] = byte 0;
    sys->write(handle.conn.dfd, outbuf, len outbuf);

    while (1) {
	nbytes = sys->read(handle.conn.dfd, buf, 1);
	if (buf[0] == byte '#')
	    break;
	else if ( buf[0] == byte '-' ) {    # sloppy: only first char can be -
	    sgn = 1;
	}
	else {
	    length = length * 10 + int buf[0] - '0';
	}
    }
    ret := length;
    length++;
    if ( sgn == 1 ) {
	ret = -ret;
    }

    #	try to allocate a big enough buffer
    buf = array[length] of byte;
    if ( buf == nil ) {
	buf = array[BLKSIZ] of byte;
    }
    #
    #	It is unfortunate but I don't know of a good way to get stuff
    #	read into the middle of a buffer.
    #
    bufpos := 0;
    for ( nbytes = 0; length > 0; length -= nbytes ) {
	newbuf := array[BLKSIZ] of byte;
	nbytes = sys->read(handle.conn.dfd, newbuf, len newbuf);
	if ( bufpos >= len buf ) {
	    continue;
	}
	if ( nbytes > len buf - bufpos ) {
	    nbytes = len buf - bufpos;
	}
	buf[bufpos:] = newbuf[0:nbytes];
	bufpos += nbytes;
    }
    if ( bufpos >= len buf ) {
	return (ret, buf);
    }
    else {
	return (ret, buf[0:bufpos]);
    }
}

DB_Handle.columnTitle(handle: self ref DB_Handle, columnI: int) : string
{
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte sys->sprint("T#%d\n", columnI);
    outbuf[len outbuf -1] = byte 0;
    sys->write(handle.conn.dfd, outbuf, len outbuf);
	
    nbyte := sys->read(handle.conn.dfd, buf, 1024);
    if ( nbyte < 0 ) {
	return "";
    }
    return (string buf[0:nbyte]);
}


DB_Handle.close(handle: self ref DB_Handle) : (int, list of string)
{
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte "X#\n";
    outbuf[2] = byte 0;
    sys->write(handle.conn.dfd, outbuf, 3);
	
    nbyte := sys->read(handle.conn.dfd, buf, 1024);
    #  Just ignore response for now, but has same deal as SQL
    handle.conn = nil;
    return(0, nil);
}


DB_Handle.errmsg(handle: self ref DB_Handle) : string
{
    buf := array[BLKSIZ] of byte;

    outbuf := array of byte "M#\n";
    outbuf[2] = byte 0;
    sys->write(handle.conn.dfd, outbuf, 3);

    nbyte := sys->read(handle.conn.dfd, buf, 1024);
    return (string buf[0:nbyte]);
}
