#
#  security routines implemented in limbo
#
Virgil: module
{
	PATH:	con "/dis/lib/virgil.dis";

	virgil:	fn(args: list of string): string;
};

Random: module
{
	PATH:	con "/dis/lib/random.dis";

	randomint: fn(): int;
	randombuf: fn(buf: array of byte, n: int): int;
};

SSL: module
{
	# Caller is expected to bind the security device to /n/ssl.

	PATH:	con "/dis/lib/ssl.dis";

	connect: fn(fd: ref Sys->FD): (string, ref Sys->Connection);
	secret: fn(c: ref Sys->Connection, secretin, secretout: array of byte): string;
};

#
#  the login protocol gets a key signed assuming a mutual secret between
#  the two client and signer.
#
Login: module
{
	PATH:	con "/dis/lib/login.dis";

	login: fn(id, password, dest: string): (string, ref Keyring->Authinfo);
	getauthinfo: fn(ctxt: ref Draw->Context, key, file: string): ref Keyring->Authinfo;
};

#
#  read and write password entries in the password file
#
Password: module
{
	PATH:	con "/dis/lib/password.dis";

	PW: adt {
		id:	string;		# user id
		pw:	array of byte;	# password
		expire:	int;		# expiration time (epoch seconds)
		other:	string;		# about the account	
	};

	get: fn(id: string): ref PW;
	put: fn(pass: ref PW): int;

	PWlen: con 4;
};
