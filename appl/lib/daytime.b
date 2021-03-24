implement Daytime;
#
# These routines convert time as follows:
#
# The epoch is 0000 Jan 1 1970 GMT.
# The argument time is in microseconds since then.
# The local(t) entry returns a pointer to an array
# containing
#
#	seconds (0-59)
#	minutes (0-59)
#	hours (0-23)
#	day of month (1-31)
#	month (0-11)
#	year-1970
#	weekday (0-6, Sun is 0)
#	day of the year
#	daylight savings flag
#
# The routine gets the daylight savings time from the file /locale/timezone.
#
# string(tvec)
# where tvec is produced by local
# returns a string that has the time in the form
#
#	Thu Jan 01 00:00:00 GMT 1970n0
#	012345678901234567890123456789
#	0	  1	    2
#
# time() just  reads the time from /dev/time
# and then calls localtime, then asctime.
#
# The sign bit of second times will turn on 68 years from the epoch ->2038
#
include	"sys.m";
include "daytime.m";

sys: Sys;

dmsize := array[] of {
	31, 28, 31, 30, 31, 30,
	31, 31, 30, 31, 30, 31
};
ldmsize := array[] of {
	31, 29, 31, 30, 31, 30,
	31, 31, 30, 31, 30, 31
};

TZSIZE:		con 150;

Timezone: adt
{
	stname: string;
	dlname: string;
	stdiff:	int;
	dldiff: int;
	dlpairs: array of int;
};

timezone: Timezone;

now(): int
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	fd := sys->open("/dev/time", sys->OREAD);
	if(fd == nil)
		return 0;
	buf := array[128] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0)
		return 0;

	t := (big string buf[0:n]) / big 1000000;
	return int t;
}

time(): string
{
	t := now();
	tm := local(int t);
	return text(tm);
}

local(tim: int): ref Tm
{
	ct: ref Tm;

	if(timezone.stname == nil)
		readtimezone();

	t := tim + timezone.stdiff;
	dlflag := 0;
	for(i := 0; timezone.dlpairs[i] != 0; i += 2) {
		if(t >= timezone.dlpairs[i] && t < timezone.dlpairs[i+1]) {
			t = tim + timezone.dldiff;
			dlflag++;
			break;
		}
	}
	ct = gmt(t);
	if(dlflag) {
		ct.zone = timezone.dlname;
		ct.tzoff = timezone.dldiff;
	}
	else {
		ct.zone = timezone.stname;
		ct.tzoff = timezone.stdiff;
	}
	return ct;
}

gmt(tim: int): ref Tm
{
	xtime := ref Tm;

	# break initial number into days
	hms := tim % 86400;
	day := tim / 86400;
	if(hms < 0) {
		hms += 86400;
		day -= 1;
	}

	# generate hours:minutes:seconds
	xtime.sec = hms % 60;
	d1 := hms / 60;
	xtime.min = d1 % 60;
	d1 /= 60;
	xtime.hour = d1;

	# day is the day number.
	# generate day of the week.
	# The addend is 4 mod 7 (1/1/1970 was Thursday)
	xtime.wday = (day + 7340036) % 7;

	# year number
	if(day >= 0)
		for(d1 = 70; day >= dysize(d1); d1++)
			day -= dysize(d1);
	else
		for (d1 = 70; day < 0; d1--)
			day += dysize(d1-1);
	xtime.year = d1;
	d0 := day;
	xtime.yday = d0;

	# generate month
	if(dysize(d1) == 366)
		dmsz := ldmsize;
	else
		dmsz = dmsize;
	for(d1 = 0; d0 >= dmsz[d1]; d1++)
		d0 -= dmsz[d1];
	xtime.mday = d0 + 1;
	xtime.mon = d1;
	xtime.zone = "GMT";
	return xtime;
}

weekday := array[] of {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};

month := array[] of {
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

text(t: ref Tm): string
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	year := t.year;
	if(year > 100)
		year = 2000+t.year;
	else
		year = 1900+t.year;

	return sys->sprint("%s %s %.2d %.2d:%.2d:%.2d %s %d",
		weekday[t.wday],
		month[t.mon],
		t.mday,
		t.hour,
		t.min,
		t.sec,
		t.zone,
		year);
}

filet(now: int, file: int): string
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	t := local(file);
	if(now - file < 6*30*24*3600)
		return sys->sprint("%s %.2d %.2d:%.2d",
			month[t.mon], t.mday, t.hour, t.min);

	year := t.year;
	if(year > 100)
		year = 2000+t.year;
	else
		year = 1900+t.year;

	return sys->sprint("%s %.2d  %d", month[t.mon], t.mday, year);
}

dysize(y: int): int
{
	if((y%4) == 0)
		return 366;
	return 365;
}

readtimezone()
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	timezone.dlpairs = array[TZSIZE] of int;
	timezone.stdiff = 0;
	timezone.stname = "GMT";
	timezone.dlpairs[0] = 0;

	i := sys->open("/locale/timezone", sys->OREAD);
	if(i == nil)
		return;
	buf := array[2048] of byte;
	cnt := sys->read(i, buf, len buf);
	if(cnt <= 0)
		return;

	(n, val) := sys->tokenize(string buf[0:cnt], "\t \n");
	if(n < 5)
		return;

	stname := hd val;
	val = tl val;
	timezone.stdiff = int hd val;
	val = tl val;
	timezone.dlname = hd val;
	val = tl val;
	timezone.dldiff = int hd val;
	val = tl val;

	for(j := 0; j < TZSIZE-1; j++) {
		timezone.dlpairs[j] = int hd val;
		val = tl val;
		if(val == nil) {
			timezone.stname = stname;
			timezone.dlpairs[j+1] = 0;
			return;
		}
	}
	timezone.dlpairs[0] = 0;
}

SEC2MIN:	con 60;
SEC2HOUR:	con 60*SEC2MIN;
SEC2DAY:	con 24*SEC2HOUR;

tm2epoch(tm: ref Tm): int
{
	secs := 0;

	#
	#  seconds per year
	#
	yr := tm.year + 1900;
	for(i := 1970; i < yr; i++)
		secs += dysize(i) * SEC2DAY;

	#
	#  seconds per month
	#
	if(dysize(tm.year) == 366)
		dmsz := ldmsize;
	else
		dmsz = dmsize;
	for(i = 0; i < tm.mon; i++)
		secs += dmsz[i] * SEC2DAY;

	#
	# secs in last month
	#
	secs += (tm.mday-1) * SEC2DAY;

	#
	# hours, minutes, seconds
	#
	secs += tm.hour * SEC2HOUR;
	secs += tm.min * SEC2MIN;
	secs += tm.sec;

	#
	#  time zone offset includes daylight savings time
	#
	return secs - tm.tzoff;
}
