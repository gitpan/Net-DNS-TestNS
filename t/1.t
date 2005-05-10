# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################



use Test::More tests => 23;
BEGIN { use_ok('NCC::DNS::TestNS') };



ok ($server=NCC::DNS::TestNS->new("t/testconf.xml",{
	Verbose => 1,
  }	),
	"Server object created");





ok (my $res=Net::DNS::Resolver->new(nameservers => ['127.0.0.1'],
				    port => 5354,
				    recurse => 0
				    ),

"Resolver object created");

ok ($server->verbose, "Verbose is being set");
$server->verbose(0);
ok  (!$server->verbose, "Verbose is toggled off");
$server->verbose(1);
ok  ($server->verbose, "Verbose is toggled on");
$server->verbose(0); # Otherwise the test script will be confused

$server->run;
my $packet=$res->send("bla.foo","ANY");
ok ($packet->header->aa, "aa bit set on the answer");
ok (! $packet->header->ad, "ad bit not set on the answer");

ok (! $packet->header->ra, "ra bit not set on the answer");
ok ($packet->header->rcode eq "FORMERR", "FORMERR");
ok ($packet->answer == 0, "Empty answer section");
ok ($packet->authority == 0, "Empty  authority section");
ok ($packet->additional == 0, "Empty additional section");


undef $packet;
$packet=$res->send("bla.foo","TXT");
my $check=[
	 Net::DNS::RR->new('bla.foo. 3600	IN	TXT	"TEXT"'),
Net::DNS::RR->new('bla.foo.		3600	IN	TXT	"Other text" ')
	   ];

use Data::Dumper;


is ($check->[0]->string,($packet->answer)[0]->string,"First Answer RR equals");
is ($check->[1]->string,($packet->answer)[1]->string,"Second Answer RR equals");


#NXDOMAIN but two answers...
$res->port(5355);
$packet=$res->send("bla.foo","TXT");

ok (!$packet->header->aa, "aa bit not set on the answer");
ok ( $packet->header->ad, "ad bit set on the answer");
ok ( $packet->header->ra, "ra bit set on the answer");



$check=[
	 Net::DNS::RR->new('bla.foo. 3600	IN	TXT	"TEXT"'),
Net::DNS::RR->new('bla.foo.		3600	IN	TXT	"From port 5355" ')
	   ];


is ($packet->header->rcode,"NXDOMAIN", "RCODE set to NXDOMAIN");
is ($check->[0]->string,($packet->answer)[0]->string,"First Answer RR equals");
is ($check->[1]->string,($packet->answer)[1]->string,"Second Answer RR equals");



$server->medea;

is ( NCC::DNS::TestNS->new("t/testconf3.xml",{
	Verbose => 1,
 }	), 0,"Broken config file failed object creation");
		
is ( $NCC::DNS::TestNS::errorcondition, "Could not open t/broken during preporcessing", "Errorcondition set appropriatly");	





#$id$