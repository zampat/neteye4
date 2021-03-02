#! /usr/bin/perl
# nagios: +epn
#
# check_alyvix3_testcase.pl - Get Monitoring Values from Alyvix3 Server API
#
# Copyright (C) 2020 Juergen Vigna
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to:  juergen.vigna@wuerth-phoenix.com
#
#

use strict;
use warnings;

use LWP::Simple;
use JSON;
use Data::Dumper;
use Getopt::Long;
use Date::Parse;
require HTTP::Request;
use LWP::UserAgent;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);

my $PROGNAME = "check_alyvix3_testcase.pl";
my $VERSION  = "1.0.0";
sub print_help ();
sub print_usage ();

my @opt_verbose  = [];
my $opt_help     = undef;
my $opt_debug    = 0;
my $opt_host     = undef;
my $opt_testcase = undef;
my $opt_testuser = undef;
my $opt_timeout  = 0;
my $opt_testing  = 0;

# Get the options
Getopt::Long::Configure('bundling');
GetOptions(
	'h'			=> \$opt_help,
	'v'			=> \@opt_verbose,
	'verbose'		=> \@opt_verbose,
	'help'			=> \$opt_help,
	'D'			=> \$opt_debug,
	'debug'			=> \$opt_debug,
	'testing'		=> \$opt_testing,
	'H=s'			=> \$opt_host,
	'host=s'		=> \$opt_host,
	'T=s'			=> \$opt_testcase,
	'testcase=s'		=> \$opt_testcase,
	'U=s'			=> \$opt_testuser,
	'testuser=s'		=> \$opt_testuser,
	't=i'			=> \$opt_timeout,
	'timeout=i'		=> \$opt_timeout,
	) || print_help();

# If somebody wants the help ...
if ($opt_help) {
	print_help();
}

if (! defined($opt_host)) {
	print "ERROR: Missing Alyvix3 Server Host Name/IP!\n";
	exit 3;
}

if (! defined($opt_testcase)) {
	print "ERROR: Missing Alyvix3 Testcase Name!\n";
	exit 3;
}

my $base_url = "https://$opt_host/v0/testcases/$opt_testcase/";
#my $json_content = get("https://$opt_host/v0/testcases/$opt_testcase/");
my $useragent = LWP::UserAgent->new;
$useragent->ssl_opts(
    SSL_verify_mode => SSL_VERIFY_NONE, 
    verify_hostname => 0
);
my $request = HTTP::Request->new('GET', $base_url);
my $response = $useragent->request($request);

if (!$response->is_success) {
	print "UNKNOWN - Could not connect to server (${base_url}) [", $response->status_line , "]\n";
	exit 3;
}

my $json_content = $response->content;
if ($opt_debug) {
	print "JSCN:$json_content\n";
}

if (!defined($json_content)) {
	print "UNKNOWN - cannot access Alyvix Server API\n";
	exit 3;
}

if ($opt_debug) {
	printf "%s\n", $json_content;
}

my $hash_content = JSON::decode_json($json_content);
if (!defined($hash_content)) {
	printf "UNKNOWN - cannot decode JSON string\n";
	exit 3;
}

my $m = $hash_content->{measures};
my @measures = @$m;
my $size = @measures;
my $n = 0;
my $testuser = "ALL";
my $teststate;
my $testduration;
my $testcode = undef;
my $testtime;
my $perfout = "";
my $perfname;
my $perfvalue = 0;
my $perfvalout;
my $perfstate;
my $perfwarn;
my $perfcrit;
my $statestr = "OK";
my $nprob = 0;
my $ntot = 0;
my $oldcode = "";
my $oldstr = "OLD";
my $now = time();
my $probstr = "";
my $verbstr = "";
if (defined($opt_testuser)) {
	$testuser = $opt_testuser;
}
my $tmpfile = "/var/tmp/alyvix3_last_testcase_code-$opt_testcase-$testuser.txt";

if (-e $tmpfile) {
	open(my $fh_in, '<', $tmpfile)
		or die "Can't open \"$tmpfile\": $!\n";
	while (<$fh_in>) {
		chomp;
		$oldcode = "$_";
	}
	close($fh_in);
}

while($n < $size) {
	if (defined($opt_testuser)) {
		$testuser = $measures[$n]->{domain_username};
		if ($testuser ne $opt_testuser) {
			$n++;
			next;
		}
	}
	if (!defined($testcode)) {
		$testcode     = $measures[$n]->{test_case_execution_code};
		if ($opt_debug) { print "First TESTCODE: $testcode\n"; }
		$teststate    = $measures[$n]->{test_case_state};
		$testduration = $measures[$n]->{test_case_duration_ms};
		$testtime     = substr($measures[$n]->{timestamp_epoch}, 0, 10);
	} elsif ($testcode ne $measures[$n]->{test_case_execution_code}) {
		if ($opt_debug) { print "TESTCODE: $testcode" . " : " . $measures[$n]->{test_case_execution_code} . "\n"; }
		my $newtesttime = substr($measures[$n]->{timestamp_epoch}, 0, 10);
		if ($opt_debug) { print "Changed TESTCODE: $testtime < $newtesttime\n"; }
		if ($testtime > $newtesttime) {
			$n++;
			next;
		}
		# Reset all newer data available
		$perfout = "";
		$probstr = "";
		$verbstr = "";
		$ntot    = 0;
		$nprob   = 0;
		$testcode     = $measures[$n]->{test_case_execution_code};
		if ($opt_debug) { print "New TESTCODE: $testcode\n"; }
		$teststate    = $measures[$n]->{test_case_state};
		$testduration = $measures[$n]->{test_case_duration_ms};
		$testtime     = substr($measures[$n]->{timestamp_epoch}, 0, 10);
	}
	
	$perfname  = $measures[$n]->{transaction_name};
	$perfvalue = $measures[$n]->{transaction_performance_ms};
	$perfstate = $measures[$n]->{transaction_state};
	$perfwarn  = $measures[$n]->{transaction_warning_ms};
	if (!defined($perfwarn) || $perfwarn !~ /[0-9]*/) {
		$perfwarn = "";
	}
	$perfcrit  = $measures[$n]->{transaction_critical_ms};
	if (!defined($perfcrit) || $perfcrit !~ /[0-9]*/) {
		$perfcrit = "";
	}
	if (defined($perfvalue) && $perfwarn && $perfcrit) {
		$perfout .= " ${perfname}=${perfvalue}ms;${perfwarn};${perfcrit};0;";
	}
	if ($opt_debug) { print "PERFSTATE:${perfname}->${perfstate}:\n"; }
	if ($perfwarn && $perfcrit && ($perfstate != 0) && defined($perfvalue)) {
		$ntot++;
		if ($perfstate == 1) {
			$nprob++;
			$probstr .= ",$perfname:WARNING";
		} elsif ($perfstate == 2) {
			$nprob++;
			$probstr .= ",$perfname:CRITICAL";
		} else {
			$nprob++;
			$probstr .= ",$perfname:UNKNOWN";
		}
	} elsif ($perfwarn && $perfcrit) {
		$ntot++;
	}
	if ($#opt_verbose) {
		my $pv;
		if (defined($perfvalue)) {
			$pv = $perfvalue;
		} else {
			$pv = "[n/a]";
		}
		if ($perfwarn && $perfcrit) {
			$perfvalout = "${pv}ms/$perfwarn/$perfcrit";
		} else {
			$perfvalout = "${pv}ms";
		}
		if (($#opt_verbose > 1) || ($perfwarn && $perfcrit)) {
			if ($perfstate == 0) {
				$verbstr .= "OK - $perfname ($perfvalout)\n";
			} elsif ($perfstate == 1) {
				$verbstr .= "WARNING - $perfname ($perfvalout)\n";
			} elsif ($perfstate == 2) {
				$verbstr .= "CRITICAL - $perfname ($perfvalout)\n";
			} else {
				$verbstr .= "UNKNOWN - $perfname ($perfvalout)";
			}
		}
	}
	$n++;
}

if (!defined($testcode)) {
	print "UNKNOWN - Could not find any performace data for the testcase $opt_testcase!\n";
	exit 3;
}

if ($teststate == 1) {
	$statestr = "WARNING";
} elsif ($teststate == 2) {
	$statestr = "CRITICAL";
} elsif ($teststate > 2) {
	$statestr = "UNKNOWN";
}

if ($opt_timeout > 0) {
	my $timediff = $now - $testtime;
	if ($timediff > $opt_timeout) {
		if ($opt_debug) {
			print "TIMEOUT $timediff > $opt_timeout\n";
		}
		$statestr = "UNKNOWN";
		$teststate = 3;
		$oldcode = $testcode;
		$oldstr = "TIMEOUT";
	}
}

if ($opt_debug) {
	print "$testcode -> $oldcode\n";
}
if ($opt_testing) {
	print "${statestr} - $nprob/$ntot problem(s)${probstr} (<a href='https://${opt_host}/v0/testcases/${opt_testcase}/reports/?runcode=${testcode}' target='_blank'>Log</a>) | duration=${testduration}ms;;;0;${perfout}\n";
	if ($#opt_verbose) {
		print "$verbstr";
	}
} elsif ($testcode ne $oldcode) {
	open(my $fh_out, '>', $tmpfile)
		or die "Can't create \"$tmpfile\": $!\n";
	print($fh_out "${testcode}\n");
	close($fh_out);
	print "${statestr} - $nprob problem(s)${probstr} (<a href='https://${opt_host}/v0/testcases/${opt_testcase}/reports/?runcode=${testcode}' target='_blank'>Log</a>) | duration=${testduration}ms;;;0;${perfout}\n";
	if ($#opt_verbose) {
		print "$verbstr";
	}
} else {
	print "${statestr} - $nprob problem(s)${probstr} [$oldstr] (<a href='https://${opt_host}/v0/testcases/${opt_testcase}/reports/?runcode=${testcode}' target='_blank'>Log</a>)\n";
	if ($#opt_verbose) {
		print "$verbstr";
	}
}
exit $teststate;

# --------------------------------------------------- helper -----------------------------------------
#

sub print_help() {
	printf "%s, Version %s\n",$PROGNAME, $VERSION;
	print "Copyright (c) 2020 Juergen Vigna\n";
	print "This program is licensed under the terms of the\n";
	print "GNU General Public License\n(check source code for details)\n";
	print "\n";
	printf "Get monitoring results for a Testcase from Alyvix3 Server\n";
	print "\n";
	print_usage();
	print "\n";
	print " -V (--version)   Programm version\n";
	print " -h (--help)      usage help\n";
	print " -v (--verbose)   verbose output\n";
	print " -D (--debug)     debug output\n";
	print " -H (--host)      Alyvix3 Server hostname/ip\n";
	print " -T (--testcase)  Alyvix3 Testcase name\n";
	print " -U (--testuser)  Alyvix3 Testcase user (default: ALL_USERS)\n";
	print " -t (--timeout)   Alyvix3 Testcase values older then timeout gives UNKNOWN (default: $opt_timeout)";
	print "\n";
	exit 0;
}

sub print_usage() {
	print "Usage: \n";
	print "  $PROGNAME [-H|--dbhost <hostname/ip>] [-d|--dbname <databasename>] [-u|--dbuser <username>] [-p|--dbpass <password>] [-T|--testonly] [-U|--apiuser <user>] [-S|--apipass <password>]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
}
