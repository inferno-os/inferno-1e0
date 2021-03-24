implement Readdir;

include "sys.m";
sys: Sys;
Dir: import sys;

include "readdir.m";

init(path: string, sortkey: int): (array of ref Dir, int)
{
	sys = load Sys Sys->PATH;

	fd := sys->open(path, sys->OREAD);
	if(fd == nil)
		return (nil, -1);
	
	d := array[200] of Dir;
	n := 0;
	for(;;){
		if(len d - n == 0){
			# expand d
			nd := array[2 * len d] of Dir;
			nd[0:] = d;
			d = nd;
		}
		nr := sys->dirread(fd, d[n:]);
		if(nr < 0)
			return (nil, -1);
		if(nr == 0)
			break;
		n += nr;
	}

	# shell sort on name
	a := array[n] of ref Dir;
	for(i := 0; i < n; i++)
		a[i] = ref d[i];

	if(sortkey == NONE)
		return (a, n);
	return sortdir(a, sortkey);	
}

sortdir(a: array of ref Dir, key: int): (array of ref Dir, int)
{
	m: int;

	n := len a;
	for(m = n; m > 1; ) {
		if(m < 5)
			m = 1;
		else
			m = (5*m-1)/11;
		for(i := n-m-1; i >= 0; i--) {
			tmp := a[i];
			for(j := i+m; j <= n-1 && greater(tmp, a[j], key); j += m)
				a[j-m] = a[j];
			a[j-m] = tmp;
		}
	}

	return (a, n);
}

greater(x, y: ref Dir, sortkey: int): int
{
	case (sortkey) {
	NAME => return(x.name > y.name);
	ATIME => return(x.atime < y.atime);
	MTIME => return(x.mtime < y.mtime);
	SIZE => return(x.length > y.length);
	NAME|DESCENDING => return(x.name < y.name);
	ATIME|DESCENDING => return(x.atime > y.atime);
	MTIME|DESCENDING => return(x.mtime > y.mtime);
	SIZE|DESCENDING => return(x.length < y.length);
	}
	return 0;
}
