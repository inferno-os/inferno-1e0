implement Logind;

include "sys.m";
sys: Sys;

include "draw.m";

include "keyring.m";
kr: Keyring;
IPint: import kr;

include "security.m";
random: Random;
pass: Password;
ssl: SSL;

Logind: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

stderr, stdin: ref Sys->FD;

# size of random number for dh exponent
DHrandlen:		con 512;

# size in bits of modulus for public keys
PKmodlen:		con 512;

# size in bits of modulus for diffie hellman
DHmodlen:		con 512;


init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	kr = load Keyring Keyring->PATH;

	stdin = sys->fildes(0);
	stderr = sys->open("/dev/cons", Sys->OWRITE);
	random = load Random Random->PATH;
	if(random == nil)
		fatal("can't load random", 1);
	pass = load Password Password->PATH;
	if(pass == nil)
		fatal("can't load pass", 1);
	ssl = load SSL SSL->PATH;
	if(ssl == nil)
		fatal("can't load ssl", 1);

	# push ssl, leave in clear mode for now
	if(sys->bind("#D", "/n/ssl", Sys->MREPL) < 0)
		fatal("cannot bind #D", 1);

	(err, c) := ssl->connect(stdin);
	if(c == nil)
		fatal("pushing ssl: " + err, 0);

	err = dologin(c);
	if(err != nil){
		kr->puterror(c.dfd, err);
		fatal(err, 0);
	}
}

dologin(c: ref Sys->Connection): string
{
	ivec: array of byte;

	info := signerkey("/keydb/signerkey");
	if(info == nil)
		return "can't read key";

	# get user name and ack
	(s, err) := kr->getstring(c.dfd);
	if(err != nil)
		return "remote:"+err;
	name := s;
	kr->putstring(c.dfd, name);

	# get initialization vector
	(ivec, err) = kr->getbytearray(c.dfd);
	if(err != nil)
		return "remote:"+err;

	# lookup password
	pw := pass->get(s);
	if(pw == nil)
		return "no password for "+s;

	# generate our random diffie hellman part
	bits := info.p.bits();
	r0 := kr->IPint.random(bits/4, bits);

	# generate alpha0 = alpha**r0 mod p
	alphar0 := info.alpha.expmod(r0, info.p);

	# start encrypting
	pwbuf := array[8] of byte;
	for(i := 0; i < 8; i++)
		pwbuf[i] = pw.pw[i] ^ pw.pw[8+i];
	for(i = 0; i < 4; i++)
		pwbuf[i] ^= pw.pw[16+i];
	for(i = 0; i < 8; i++)
		pwbuf[i] ^= ivec[i];
	ssl->secret(c, pwbuf, pwbuf);
	sys->fprint(c.cfd, "alg rc4");

	# send P(alpha**r0 mod p)
	kr->putstring(c.dfd, alphar0.iptob64());

	# stop encrypting
	sys->fprint(c.cfd, "alg clear");

	# send alpha, p
	kr->putstring(c.dfd, info.alpha.iptob64());
	kr->putstring(c.dfd, info.p.iptob64());

	# get alpha**r1 mod p
	(s, err) = kr->getstring(c.dfd);
	if(err != nil)
		return "remote:"+err;
	alphar1 := kr->IPint.b64toip(s);

	# compute alpha**(r0*r1) mod p
	alphar0r1 := alphar1.expmod(r0, info.p);

	# turn on digesting
	secret := alphar0r1.iptobytes();
	ssl->secret(c, secret, secret);
	sys->fprint(c.cfd, "alg sha");

	# send our public key
	kr->putstring(c.dfd, kr->pktostr(kr->sktopk(info.mysk)));

	# get his public key
	(s, err) = kr->getstring(c.dfd);
	if(err != nil)
		return "remote:"+err;
	hisPKbuf := array of byte s;
	hisPK := kr->strtopk(s);
	if(hisPK.owner != name)
		return "pk name doesn't match user name";

	# sign and return
	state := kr->sha(hisPKbuf, len hisPKbuf, nil, nil);
	cert := kr->sign(info.mysk, 0, state, "sha");
	kr->putstring(c.dfd, kr->certtostr(cert));

	return nil;
}

fatal(msg: string, prsyserr: int)
{
	if(prsyserr)
		sys->fprint(stderr, "logind: %s: %r\n", msg);
	else
		sys->fprint(stderr, "logind: %s\n", msg);
	exit;
}

signerkey(filename: string): ref Keyring->Authinfo
{
	if(len filename >= Sys->NAMELEN) {
		filename = filename[0:Sys->NAMELEN-2];
		sys->fprint( stderr, 
		             "signerkey: warning: filename length > %d, truncated to %s\n", 
					 Sys->NAMELEN-1, filename);
	}

	info := kr->readauthinfo(filename);
	if(info != nil)
		return info;

	# generate a local key
	info = ref Keyring->Authinfo;
	info.mysk = kr->genSK("elgamal", "*", PKmodlen);
	info.mypk = kr->sktopk(info.mysk);
	info.spk = kr->sktopk(info.mysk);
	myPKbuf := array of byte kr->pktostr(info.mypk);
	state := kr->sha(myPKbuf, len myPKbuf, nil, nil);
	info.cert = kr->sign(info.mysk, 0, state, "sha");
	(info.alpha, info.p) = kr->dhparams(DHmodlen);

	if(kr->writeauthinfo(filename, info) < 0){
		sys->fprint(stderr, "signer: can't write signerkey file: %r\n");
		return nil;
	}

	return info;
}
