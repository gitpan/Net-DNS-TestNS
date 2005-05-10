package Net::DNS::TestNS;
use XML::LibXML;
use IO::File;


use Data::Dumper;
use strict;
use warnings;
use Carp;

require Exporter;


our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.


our @EXPORT_OK = qw ( 
);

our @EXPORT = qw(
	
);

use vars qw( $AUTOLOAD $VERSION $errorcondition);
$VERSION = do{my@r=q$Revision: 1.6 $=~/\d+/g;sprintf '%d.'.'%02d'x$#r,@r};



   
use Net::DNS::Nameserver;
use Net::DNS;



use constant ANS=>0;
use constant AUT=>1;
use constant ADD=>2;
use constant RCODE=>3;
use constant HEADER=>4;
   
my $verbose=0;
	    

sub new {
    my $class = shift;
    my $self = {};
    bless $self,ref $class || $class;
    my ($configfile,$params)=@_;

    $self->{servercount}=0;
    $self->{verbose} = ${$params}{Verbose} || $verbose;


   if (! $configfile){
    $errorcondition="No config file specified" ;
    return 0;
}
if (! -f $configfile){
    $errorcondition="$configfile does not exist" ;
    return 0;
}
my $docstring;

$docstring=$self->_preprocess_input("",$configfile);

return 0 unless $docstring;

    my $parser=XML::LibXML->new();
    $parser->validation(1); 
    $parser->pedantic_parser(1); 

    my $doc=$parser->parse_string($docstring);



    my $root=$doc->getDocumentElement; 
    my $servercount=0;
    foreach my $server ($root->findnodes('server')){
	my %answerdb;
	my $ip=$server->findvalue('@ip');
	my $port=$server->findvalue('@port');
	print "---------Server $ip ($port) ----------------\n" if $self->{verbose};

	foreach my  $qname  ($server->findnodes('qname')){
	      my $query_name= $qname->findvalue('@name');
	      if ($query_name =~ /\s/){
		  $errorcondition="spaces in queryname are not allowed";
		   return 0;
		   #next;
	      }
	      $query_name.="." if $query_name !~ /\.$/;
	      
	    foreach my  $qtype  ($qname->findnodes('qtype')){
	      my $query_type= $qtype->findvalue('@type');
	       if (exists $answerdb{$query_name}->{$query_type}){
		   $errorcondition= "There is allready data for $query_name,$query_type";
		   return 0;
		   #next;
	       }
	      


	      print "<qname,qtype>=$query_name,$query_type\n" if $self->{verbose};
	      $answerdb{$query_name}->{$query_type}->{'rcode'}=
		  $qtype->findvalue('@rcode');
	      $answerdb{$query_name}->{$query_type}->{'header'}->{"aa"}= 
		  $qtype->findvalue('@aa');
	      $answerdb{$query_name}->{$query_type}->{'header'}->{"ad"}= 
		  $qtype->findvalue('@ad');
	      $answerdb{$query_name}->{$query_type}->{'header'}->{"ra"}= 
		  $qtype->findvalue('@ra');
	      my $delay= $qtype->findvalue('@delay');

  	     
	      $answerdb{$query_name}->{$query_type}->{'delay'}=0;

	      if ($delay=~/^\d+$/){
		  $answerdb{$query_name}->{$query_type}->{'delay'}=$delay ;
	      }
	      
	      foreach my $ans ($qtype->findnodes('ans')){
		  my $rr_string=$ans->findvalue(".");
  		  $rr_string =~s/\n//g;
		  next if $rr_string =~ /^\s*$/;
		  my $ans_rr= Net::DNS::RR->new( $rr_string );
		  if ($ans_rr){
		      push @{$answerdb{$query_name}->{$query_type}->{'answer'}}, $ans_rr;
		  }else{
		      $errorcondition= " Could not parse $rr_string\n";
		      return 0;
		  }
	      }
	      foreach my $ans ($qtype->findnodes('aut')){
		  my $rr_string=$ans->findvalue(".");
		  next if $rr_string =~ /^\s*$/;
		  $rr_string =~s/\n//g;
		  my $ans_rr= Net::DNS::RR->new( $rr_string );
		  if ($ans_rr){
		      push @{$answerdb{$query_name}->{$query_type}->{'authority'}}, $ans_rr;
		  }else{
		      $errorcondition= " Could not parse $rr_string\n";
		      return 0;
		  }
	      }
	      foreach my $ans ($qtype->findnodes('add')){
		  my $rr_string=$ans->findvalue(".");
		  next if $rr_string =~ /^\s*$/;
		  $rr_string =~s/\n//g;
		  my $ans_rr= Net::DNS::RR->new( $rr_string );
		  if ($ans_rr){
		      push @{$answerdb{$query_name}->{$query_type}->{'additional'}}, $ans_rr;
		  }else{
		      $errorcondition= " Could not parse $rr_string\n";
		      return 0;
		  }
	      }
	  }
			    

	    
	}

	# The XML has been parsed and all info sits in the %answer db..
	# We now construct the reply handler using that.
	my $reply_handler = sub {
	    my ($qname, $qclass, $qtype) = @_;
	    $qname.="." if $qname !~ /\.$/;
	    my ($rcode, @ans, @auth, @add);
	    if ( exists $answerdb{$qname}->{$qtype}){
		

		$rcode= $answerdb{$qname}->{$qtype}->{'rcode'}; 
		my $foo= { 
		    'aa' => 
			$answerdb{$qname}->{$qtype}->
			    {'header'}->{'aa'},
		    'ra' => 
			$answerdb{$qname}->{$qtype}->
			    {'header'}->{'ra'},
			    
		    'ad' => 
			$answerdb{$qname}->{$qtype}->
			    {'header'}->{'ad'},
				    
			};

		print "Sleeping for " . $answerdb{$qname}->{$qtype}->{'delay'} 
		. " seconds " 
		    if $self->{verbose} && $answerdb{$qname}->{$qtype}->{'delay'};

		sleep ($answerdb{$qname}->{$qtype}->{'delay'});


		return ($rcode, $answerdb{$qname}->{$qtype}->{'answer'},
			$answerdb{$qname}->{$qtype}->{'authority'},
			$answerdb{$qname}->{$qtype}->{'additional'},
			$foo);
		
	    }
	    
	    return ("SERVFAIL");
	};
	print "Setting up server for: $ip,$port\n" if $self->{verbose};
	my $ns = Net::DNS::Nameserver->new(
					   LocalPort	   => $port,
					   LocalAddr           => $ip,
					   ReplyHandler => $reply_handler,
					   Verbose	   => $self->{verbose},
					   );

	if (! $ns ){
	    $errorcondition="Could not create Nameserver object";
	    return 0;
	}

	$self->{'serverinstance'}->[$servercount]->{'server'}=$ns;
	$self->{'serverinstance'}->[$servercount]->{'_child_pid'}="_not_running";
	$servercount++;
    } #end looping over all servers.
    


    $self->{'servercount'}=$servercount;
    #
    #  Now dynamically set up the reply handler.
    # 
    # 
    return bless $self, $class;

}



sub run {
    my $self=shift;
    my $servercount=0;
    
    while ( $servercount <  $self->{'servercount'} ){
	
	if ($self->{'serverinstance'}->[$servercount]->{'_child_pid'} ne
	    "_not_running" ){
	    print "This instance allready has a server running\n";
	    return ;
	}
	
	
	my $pid;
      FORK: {
	  no strict 'subs';  # EAGAIN
	  if ($pid=fork) {# assign result of fork to $pid,
	      # see if it is non-zero.
	      # Parent process here
	      # Child pid is in $pid
	      print "Child Process: ".$pid."\n" if $self->{verbose};
	      $self->{'serverinstance'}->[$servercount]->{'_child_pid'}=$pid;
	      
	  } elsif (defined($pid)) {
	      # Child process here
	      #parent process pid is available with getppid
	      # exec will transfer control to the child process,
	      # and will finish (exit) when the tar is done.

	      #Verbose level is set during construction.. The verbose method
	      # may have been called afterward.

	      $self->{'serverinstance'}->[$servercount]->{'server'}->{"Verbose"}=$self->verbose;
	      $self->{'serverinstance'}->[$servercount]->{'server'}->main_loop;
	  } elsif ($! == EAGAIN) {
	      # EAGAIN is the supposedly recoverable fork error
	      sleep 5;
	      redo FORK;
	  }else {
	      #weird fork error
	      die "Can't fork: $!\n";
	  }
      }
	
	$servercount++;
    }
    1;
    
}
 

sub _preprocess_input {
    my $self=shift;
    my $outstring=shift;
    my $filename=shift;
    my $infile=new IO::File;
	if ($infile->open("< $filename")) {
	    while (<$infile>){
		if (/^(.*)(<!--\s*include=\"\s*(.*)\s*\"\s*-->)(.*)$/){
		    my $newfile=$3;
		    print "including $newfile\n" if $self->{verbose};
		    $outstring= $outstring. $1;
		    $outstring=$self->_preprocess_input($outstring,$newfile);
		    return 0 unless $outstring;
		    $outstring= $outstring. $4;
		}else{
		    $outstring= $outstring. $_;
		}   
	    }
	}else{
	    $errorcondition= "Could not open $filename during preporcessing";
	    return 0;
	}
    return $outstring;
}


sub verbose {
    my $self=shift;
    my $argument=shift;
    $self->{verbose}=$argument if defined($argument);
    return $self->{verbose};
}

sub stop {
    my $self=shift;
    $self->medea(@_);
}




sub medea {
    my $self=shift;

    my $servercount=0;
    
    while ( $servercount <  $self->{'servercount'} ){
	
	if ($self->{'serverinstance'}->[$servercount]->{'_child_pid'} ne 
	    '_not_running'){
	    if (  kill(15, $self->{'serverinstance'}->[$servercount]->{'_child_pid'}) != 1 ){
		die "UNABLE TO KILL CHILDREN. KILL ".$self->{'serverinstance'}->[$servercount]->{'_child_pid'}." BY HAND";
	    }

	    print "Killed ".$self->{'serverinstance'}->[$servercount]->{"_child_pid"}."\n" if $self->{verbose};
	    $self->{'serverinstance'}->[$servercount]->{"_child_pid"}="_not_running";

	} else {
	    # The child is not running...
	}
	$servercount++;
    }
}
     
sub DESTROY {
    # Time for Greek Drama
    # All children should be killed...
    # 
    my $self=shift;
    $self->medea;
}




sub AUTOLOAD {
        my ($self) = @_;

        my $name = $AUTOLOAD;
        $name =~ s/.*://;

        Carp::croak "$name: no such method" unless exists $self->{$name};
        
        no strict q/refs/;
	
        # AUTOLOADER sets and reads existing variables.
        *{$AUTOLOAD} = sub {
                my ($self, $new_val) = @_;
                
                if (defined $new_val) {
                        $self->{"$name"} = $new_val;
                }
                
                return $self->{"$name"};
        };
        
        goto &{$AUTOLOAD};      
}



my $TESTNS_DTD='
<!DOCTYPE testns [
	<!ELEMENT testns (server*)>
	<!-- Root element  has required IP and PORT attribute        -->
	<!ELEMENT server (qname?)>
	<!ATTLIST server ip  CDATA #REQUIRED>
	<!ATTLIST server port  CDATA #REQUIRED>
	<!-- A server has answers for a number of possible QNAME QTYPE questions -->


        <!-- A QNAME should be fully specified -->
	<!ELEMENT qname (qtype*)>

        <!ATTLIST qname name CDATA #REQUIRED>
	<!ELEMENT qtype (ans+,aut+,add+)>
        <!ATTLIST qtype type CDATA #REQUIRED>
        <!ATTLIST qtype rcode CDATA #REQUIRED>
        <!ATTLIST qtype aa (1|0)  #REQUIRED>
        <!ATTLIST qtype ra (1|0)  #REQUIRED>
        <!ATTLIST qtype ad (1|0)  #REQUIRED>
	<!ATTLIST qtype delay CDATA "0" >
	<!--  Each of these contain one RR. -->
	<!ELEMENT ans (#PCDATA) >
	<!ELEMENT aut (#PCDATA) >
	<!ELEMENT add (#PCDATA) >
]>
';










# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::DNS::TestNS - Perl extension for simulating simple Nameservers

=head1 SYNOPSIS

use Net::DNS::TestNS;
  

=head1 ABSTRACT

Class for setting up "simple DNS" servers.

=head1 DESCRIPTION

Class to setup a number of nameservers that respond to specific DNS
queries (QNAME,QTYPE) by prespecified answers. This class is to be
used in test suites where you want to have servers to show predefined
behavior. 

If the server will do a lookup based on QNAME,QTYPE and return the
specified data. If there is no QNAME, QTYPE match the server will
return a SERVFAIL.

A log will be written to STDERR it contains time, IP/PORT, QNAME,
QTYPE, RCODE



=head2 Configuration file

Thew class uses an XML file to read its configuration. The DTD can be
obtained through the variable $Net::DNS::TestNS::TESTNS_DTD.

The setup is split in a number of servers, each with a unique IP/port
number, each server has 1 or more QNAMEs it will respond to. Each
QNAME can have QTYPEs specified.

For each QNAME,QTYPE an answer needs to be specified, response code
and header bits can be tweaked through the qtype attributes.

The content of the packet can be specified through ans, aut and add
elements, each specifying one RR record to end up in the answer,
authority or additional section.

The optional 'delay' attribute in the QTYPE element specifies how many
seconds the server should wait until an answer is returned.


If the query does not match against data specified in the
configuration a SERVFAIL is returned.

=head2 new 


    my $server=Net::DNS::TestNS->new($configfile, {
	Verbose => 1,
    });



Read the configuration files and bind to ports.  One can use <!--
include="file" --> anywhere inside the configuration file to include
other XML configuration fragments.

The second optional argument is hash that contains customization parameters.
    Verbose  boolean     Makes the code more verbose.
    

new returns the object reference on success and 0 on failure. On
failure the class variable $Net::DNS::TestNS::errorcondition is set.



=head2 verbose

    $self->verbose(1);

Sets verbosity at run time.

=head2 run
 
Spawns off the servers and process the data.
 
=head2 medea

Cleanup function that kills all the children spawned by the
instance.  Also known by its alias 'stop'.

=head1 Configuration file example

<?xml version="1.0"?>

<!-- DTD is in-line and obligatory -->

 <!DOCTYPE testns [
	<!ELEMENT testns (server*)>
	<!-- Root element  has required IP and PORT attribute        -->
	<!ELEMENT server (qname?)>
	<!ATTLIST server ip  CDATA #REQUIRED>
	<!ATTLIST server port  CDATA #REQUIRED>
	<!-- A server has answers for a number of possible QNAME QTYPE questions -->


        <!-- A QNAME should be fully specified -->
	<!ELEMENT qname (qtype*)>
        <!ATTLIST qname name CDATA #REQUIRED>
	<!ELEMENT qtype (ans*,aut*,add*)>
        <!ATTLIST qtype type CDATA #REQUIRED>
        <!ATTLIST qtype rcode CDATA #REQUIRED>
        <!ATTLIST qtype aa (1|0)  #REQUIRED>
        <!ATTLIST qtype ra (1|0)  #REQUIRED>
        <!ATTLIST qtype ad (1|0)  #REQUIRED>
	<!ATTLIST qtype delay CDATA "0" >
	<!--  Each of these contain one RR. -->
	<!ELEMENT ans (#PCDATA) >
	<!ELEMENT aut (#PCDATA) >
	<!ELEMENT add (#PCDATA) >
		       ]>



<!-- Start of the configuration -->

<testns>

<!-- First server -->

<server ip="127.0.0.1" port="5354">
  <qname name="bla.foo">
    <!-- bla.foo ANY returns a formerr -->
    <qtype type="ANY" rcode="FORMERR"  aa="1" ra="0" ad="0" >
      </qtype>
    <!-- bla.foo TXT returns two RRs in the answer section -->
    <qtype type="TXT" rcode="NOERROR"  aa="1" ra="0" ad="1" >
       <ans>
       bla.foo.		3600	IN	TXT	"TEXT"
       </ans>
       <ans>
       bla.foo.		3600	IN	TXT	"Other text"  
       </ans>
    </qtype>

    <!-- bla.foo A Returns extra crap in the additional section -->
    <qtype type="A" rcode="NOERROR"  aa="1" ra="0" ad="1" >   
      <ans>
      bla.foo.		3600	IN	A 10.0.0.1
      </ans>
      <ans>
      bla.foo.		3600	IN	A 10.0.0.2
      </ans>
      <ans>
      bla.foo.		3600	IN	A 10.0.0.3
      </ans>
      <aut></aut>
      <add>
      bla.foo.		3600	IN	A 10.0.0.3
      </add>
    </qtype>
  </qname>
 </server>



<!-- Second server on port 5355 -->
<server ip="127.0.0.1" port="5355">

  <qname name="bla.foo">
    <!-- a NXDOMAIN with authoritative content; does not make sense does it -->
    <qtype type="TXT" rcode="NXDOMAIN"  aa="0" ra="1" ad="1" >
      <ans>
bla.foo.		3600	IN	TXT	"TEXT"
  </ans>
      <ans>
bla.foo.		3600	IN	TXT	"From port 5355"
  </ans>
      <aut></aut>
      <add></add>
    </qtype>
  </qname>


 </server>
</testns>

=head1 Known Deficiencies and TODO

The module is based on Net::DNS::Nameserver. There is no way to
distinguish if the query came over TCP or UDP; besides UDP truncation
is not available in Net::DNS::Nameserver. 


=head1 AUTHOR

Olaf Kolkman, E<lt>olaf@net-dns.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2003-2005  RIPE NCC.  Author Olaf M. Kolkman  <olaf@net-dns.net>

All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of the author not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.


THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS; IN NO EVENT SHALL
AUTHOR BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY
DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


=cut
