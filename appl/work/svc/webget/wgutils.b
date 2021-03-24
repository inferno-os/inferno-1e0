implement WebgetUtils;

include "sys.m";
	sys: Sys;

include "draw.m";

include "string.m";

include "bufio.m";

include "imagefile.m";	
	readgif, readjpg: RImagefile;

include "image2enc.m";
	image2enc: Image2enc;

include "message.m";

include "url.m";

include "wgutils.m";
	Iobuf: import B;

Msg, Nameval: import M;
ParsedUrl: import U;

logfd: ref Sys->FD;

# return from acceptmatch; and conv arg to readbody
BadConv, NoConv, Gif2xcompressed, Jpeg2xcompressed: con iota;

StringInt: adt
{
	name:	string;
	val:		int;
};

# Both extensions and Content-Types can be in same table.
# This array should be kept sorted
mtypes := array[] of { StringInt
	("ai", ApplPostscript),
	("application/html", TextHtml),
	("application/pdf", ApplPdf),
	("application/postscript", ApplPostscript),
	("application/rtf", ApplRtf),
	("application/x-html", TextHtml),
	("au", AudioBasic),
	("audio/au", AudioBasic),
	("audio/basic", AudioBasic),
	("bit", ImageXCompressed),
	("eps", ApplPostscript),
	("gif", ImageGif),
	("htm", TextHtml),
	("html", TextHtml),
	("image/gif", ImageGif),
	("image/ief", ImageIef),
	("image/jpeg", ImageJpeg),
	("image/tiff", ImageTiff),
	("image/x-compressed", ImageXCompressed),
	("image/x-compressed2", ImageXCompressed2),
	("jpe", ImageJpeg),
	("jpeg", ImageJpeg),
	("jpg", ImageJpeg),
	("pdf", ApplPdf),
	("ps", ApplPostscript),
	("text", TextPlain),
	("text/html", TextHtml),
	("text/plain", TextPlain),
	("text/x-html", TextHtml),
	("tif", ImageTiff),
	("tiff", ImageTiff),
	("txt", TextPlain),
	("video/mpeg", VideoMpeg),
	("video/quicktime", VideoQuicktime),
};

# following array must track media type def in wgutils.m
mnames := array[] of {
	"application/x-unknown",
	"text/plain",
	"text/html",
	"application/postscript",
	"application/rtf",
	"application/pdf",
	"image/jpeg",
	"image/gif",
	"image/ief",
	"image/tiff",
	"image/x-compressed",
	"image/x-compressed2",
	"audio/basic",
	"video/mpeg",
	"video/quicktime"
};

init(m: Message, s: String, b: Bufio, u: Url, lfd: ref Sys->FD)
{
	sys = load Sys Sys->PATH;

	M = m;
	S = s;
	B = b;
	U = u;
	logfd = lfd;
	readgif = load RImagefile RImagefile->READGIFPATH;
	readjpg = load RImagefile RImagefile->READJPGPATH;
	image2enc = load Image2enc Image2enc->PATH;
	if(readgif == nil || readjpg == nil || image2enc == nil) {
		sys->fprint(sys->fildes(2), "webget: failed to load readgif, readjpg, or imageremap: %r\n");
		return;
	}
	readgif->init(B);
	readjpg->init(B);
}

# Return msg with error provoked by bad user action
usererr(r: ref Req, msg: string) : ref Msg
{
	m := Msg.newmsg();
	m.prefixline = sys->sprint("ERROR %s %s", r.reqid, msg);
	m.bodylen = 0;
	return m;
}

okprefix(r: ref Req, mrep: ref Msg)
{
	(nil, sctype) := mrep.fieldval("content-type");
	if(sctype == "")
		sctype = "text/html";
	(nil, cloc) := mrep.fieldval("content-location");
	if(cloc == "")
		cloc = "unknown";
	mrep.prefixline = "OK " + string mrep.bodylen + " " + r.reqid + " " + sctype + " " + cloc;
}

mediatype(s: string, dflt: int) : int
{
	return slookup(mtypes, S->tolower(s), dflt);
}

acceptmatch(ctype: int, accept: string) : int
{
	conv := BadConv;
	(nil,l) := sys->tokenize(accept, ",");
	while(l != nil) {
		a := S->drop(hd l, " \t");
		mt := mediatype(a, -1);
		match := (ctype == mt) || (a == "*/*")
			|| ((ctype == ImageXCompressed || ctype == ImageXCompressed2)
			   && (mt == ImageJpeg || mt == ImageGif));
		if(match) {
			if(ctype == ImageGif)
				conv = Gif2xcompressed;
			else if(ctype == ImageJpeg)
				conv = Jpeg2xcompressed;
			else
				conv = NoConv;
			break;
		}
		l = tl l;
	}
	return conv;
}

# Get the body of the message whose header is in mrep,
# if io != nil.
# First check that the content type is acceptable.
# Image types will get converted into Inferno compressed format.
# If there is an error, return error string, else "".
# If no error, mrep will contain content-encoding, content-location,
# and content-type fields (guessed if they weren't orignally there).
 
getdata(io: ref Iobuf, m: ref Msg, accept: string, url: ref ParsedUrl) : string
{
	(efnd, etype) := m.fieldval("content-encoding");
	if(efnd)
		return "content is encoded: " + etype;
	ctype := UnknownType;
	(tfnd, sctype) := m.fieldval("content-type");
	if(tfnd)
		ctype = mediatype(sctype, UnknownType);
	else {
		# try to guess type from extension
		sctype = "(unknown)";
		(nil, name) := S->splitr(url.path, "/");
		if(name != "") {
			(f, ext) := S->splitr(name, ".");
			if(f != "" && ext != "") {
				ctype = mediatype(ext, UnknownType);
				if(ctype != UnknownType) {
					sctype = mnames[ctype];
					m.update("content-type", sctype);
				}
			}
		}
	}
	transform := acceptmatch(ctype, accept);
	if(transform == BadConv)
		return "media type " + sctype + " not acceptable";
	(clfnd, cloc) := m.fieldval("content-location");
	if(!clfnd) {
		cloc = url.tostring();
		m.update("content-location", cloc);
	}
	if(transform != NoConv) {
		rawimg: ref RImagefile->Rawimage;
		err: string;
		if(transform == Gif2xcompressed)
			(rawimg, err) = readgif->read(io);
		else if(transform == Jpeg2xcompressed)
			(rawimg, err) = readjpg->read(io);
		# if gif file has multiple images, we are supposed to animate,
		# but the first one should be there
		if(err != "" && err != "ReadGIF: can't handle multiple images in file")
			return "error converting image file: " + err;
		(data, mask, e) := image2enc->image2enc(rawimg, 1);
		if(e != "")
			return "error remapping and encoding image file: " + e;
		if(mask == nil)
			sctype = "image/x-compressed";
		else {
			sctype = "image/x-compressed2";
			newdata := array[len data + len mask] of byte;
			newdata[0:] = data[0:];
			newdata[len data:] = mask[0:];
			data = newdata;
		}
		m.body = data;
		m.bodylen = len data;
		m.update("content-type", sctype);
		m.update("content-length", string m.bodylen);
	}
	else {
		# io will be nil if m came from cache
		if(io != nil) {
			e := m.readbody(io);
			if(e != "")
				return "reading body: " + e;
		}
	}
	return "";
}

# Change an accept spec from webget client into one we can send
# to http server.  This means image/x-compressed must be
# changed into image formats we can handle: i.e., gif or jpeg
fixaccept(a: string) : string
{
	(nil,l) := sys->tokenize(a, ",");
	ans := "";
	sep := "";
	while(l != nil) {
		s := S->drop(hd l, " \t");
		if(s == "image/x-compressed")
			ans += sep + "image/gif,image/jpeg";
		else
			ans += sep + s;
		sep = ",";
		l = tl l;
	}
	if(ans == "")
		ans = "*/*";
	return ans;
}

slookup(t: array of StringInt, s: string, dflt: int): int
{
	min := 0;
	max := len t-1;
	while(min <= max){
		try := (min+max)/2;
		if(t[try].name == s)
			return t[try].val;
		if(t[try].name < s)
			min = try+1;
		else
			max = try-1;
	}
	return dflt;
}

log(c: ref Fid, msg: string)
{
	if(logfd != nil) {
		# don't use print in case msg is longer than buf
		s := "";
		if(c != nil)
			s += (string c.fid) + ": ";
		s += msg + "\n";
		b := array of byte s;
		sys->write(logfd, b, len b);
	}
}
