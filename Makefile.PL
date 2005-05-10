use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'NAME'		=> 'Net::DNS::TestNS',
	      'VERSION_FROM'	=> 'TestNS.pm', # finds $VERSION
	      'PREREQ_PM'		=> {
		Net::DNS => 0.40,
		IO::File => 1.09,
		XML::LibXML => 1.53,
	      }, # e.g., Module::Name => 1.1
	      ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
	       (ABSTRACT_FROM => 'TestNS.pm', # retrieve abstract from module
		AUTHOR     => 'Olaf Kolkman <olaf@ripe.net>') : ()),
	      'LIBS'		=> [''], # e.g., '-lm'
	      'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
	      'INC'		=> '-I.', # e.g., '-I. -I/usr/include/other'
	      
	      
	      'PM' => { 
		  'TestNS.pm'    => '$(INST_LIBDIR)/TestNS.pm',
	      }
	      
	      );



