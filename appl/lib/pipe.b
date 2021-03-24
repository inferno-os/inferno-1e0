implement Pipe;

include "sys.m";
	sys: Sys;

include "pipe.m";

pipenum := 0;

fds(): (ref Sys->FD, ref Sys->FD)
{
	(r, w) := files();
	if(r == "")
		return (nil, nil);
	return (sys->open(r, Sys->OREAD), sys->open(w, Sys->OWRITE));
}

files(): (string, string)
{
	if(sys == nil)
		sys = load Sys Sys->PATH;

	writes := string pipenum++;
	reads := string pipenum++;

	writeio := sys->file2chan("/chan", writes, sys->MBEFORE);
	if(writeio == nil)
		return ("", "");

	readio := sys->file2chan("/chan", reads, sys->MBEFORE);
	if(readio == nil)
		return ("", "");

	spawn pipesrv(readio, writeio);

	return ("/chan/" + writes, "/chan/" + reads);
}

pipesrv(writeio, readio: ref sys->FileIO)
{
	wc: chan of (int, string);
	d: array of byte;

	n := 0;
	reader := 1;
	writer := 1;
	while(reader || writer){
		if(writer && n==0){
			(nil, d, nil, wc) = <-writeio.write;
			if(wc == nil){
				writer = 0;
				n = -1;
			}else{
				n = len d;
				wc <- = (n, nil);
			}
		}

		if(reader){
			(nil, i, nil, rc) := <-readio.read;
			if(rc == nil){
				reader = 0;
				continue;
			}
			if(n >= 0){
				if(i >= n){
					rc <-= (d, nil);
					n = 0;
				}else{
					rc <-= (d[0:i], nil);
					d = d[i:n];
					n -= i;
				}
				continue;
			}
			if(writer == 0){
				rc <- = (nil, nil);
				reader = 0;
			}
		}
	}
}
