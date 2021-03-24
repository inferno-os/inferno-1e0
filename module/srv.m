#
# Non Inferno interfaces available from host operating systems
#
Srv: module
{
	PATH:	con	"$Srv";

	reads:	fn(str: string, off, nbytes: int): (array of byte, string);
	#
	# IP network database lookups
	#
	#	iph2a:	host name to ip addrs
	#	ipn2p:	service name to port
	#
	iph2a:	fn(host: string): list of string;
	ipn2p:	fn(net, service: string): string;
};
