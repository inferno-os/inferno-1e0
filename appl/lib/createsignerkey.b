implement Createsignerkey;

include "sys.m";
sys: Sys;

include "draw.m";

include "keyring.m";
kr: Keyring;

include "security.m";
random: Random;

# size in bits of modulus for public keys
PKmodlen:		con 512;

# size in bits of modulus for diffie hellman
DHmodlen:		con 512;

stderr: ref Sys->FD;

Createsignerkey: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;

	stderr = sys->open("/dev/cons", Sys->OWRITE);

	argv = tl argv;

	if(argv == nil)
		usage();
	owner := hd argv;
	argv = tl argv;

	bits := PKmodlen;
	if(argv != nil){
		bits = int hd argv;
		argv = tl argv;
	}

	if(bits < 32){
		sys->fprint(stderr, "createsignerkey: modulus must be at least 32 bits\n");
		exit;
	}

	filename := "/keydb/signerkey";
	if(argv != nil) {
		filename = hd argv;
		if(len filename >= Sys->NAMELEN){
			filename = filename[0:Sys->NAMELEN-2];
			sys->fprint( stderr, 
			             "createsignerkey: warning: filename length > %d, truncated to %s\n", 
						 Sys->NAMELEN-1, filename);
		}
	}

	# generate a local key
	info := ref Keyring->Authinfo;
	info.mysk = kr->genSK("elgamal", owner, bits);
	info.mypk = kr->sktopk(info.mysk);
	info.spk = kr->sktopk(info.mysk);
	myPKbuf := array of byte kr->pktostr(info.mypk);
	state := kr->sha(myPKbuf, len myPKbuf, nil, nil);
	info.cert = kr->sign(info.mysk, 0, state, "sha");
	(info.alpha, info.p) = kr->dhparams(DHmodlen);

	if(kr->writeauthinfo(filename, info) < 0)
		sys->fprint(stderr, "createsignerkey: can't write signerkey file: %r\n");
}

usage()
{
	sys->fprint(stderr, "usage: createsignerkey name-of-owner [size-in-bits [file]]\n");
	exit;
}
