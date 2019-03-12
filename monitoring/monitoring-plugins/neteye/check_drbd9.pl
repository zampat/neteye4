#!/usr/bin/perl -Tw
#
#   Nagios DRBD 9 Checks
#   Copyright (c) 2016, David M. Syzdek <david@syzdek.net>
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are
#   met:
#
#      1. Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#
#      2. Redistributions in binary form must reproduce the above copyright
#         notice, this list of conditions and the following disclaimer in the
#         documentation and/or other materials provided with the distribution.
#
#      3. Neither the name of the copyright holder nor the names of its
#         contributors may be used to endorse or promote products derived from
#         this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
#   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# +-=-=-=-=-=-+
# |           |
# |  Headers  |
# |           |
# +-=-=-=-=-=-+

use warnings;
use strict;
use Getopt::Std;

$|++;

our $PROGRAM_NAME    = 'check_drbd9.pl';
our $VERSION         = '0.3';
our $DESCRIPTION     = 'Checks status of DRBD';
our $AUTHOR          = 'David M. Syzdek <david@syzdek.net>';

%ENV                 = ();
$ENV{PATH}           = '/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin';


# +-=-=-=-=-=-=-+
# |             |
# |  Variables  |
# |             |
# +-=-=-=-=-=-=-+

our %ERRORS = 
(
   'OKAY'      => { 'code' => 0, 'state' => 'OKAY',     'array' => 'okay' },
   'WARN'      => { 'code' => 1, 'state' => 'WARN',     'array' => 'warn' },
   'CRIT'      => { 'code' => 2, 'state' => 'CRIT',     'array' => 'crit' },
   'UNKNOWN'   => { 'code' => 3, 'state' => 'UNKNOWN',  'array' => 'unknown' },
   'DEPENDENT' => { 'code' => 4, 'state' => 'DEPENDENT','array' => 'dependent' },
);
our $STATES =
{
   # replication states
   'repl' =>
   {
      'ahead'          => $ERRORS{'WARN'},
      'behind'         => $ERRORS{'CRIT'},
      'off'            => $ERRORS{'WARN'},
      'established'    => $ERRORS{'OKAY'},
      'pausedsyncs'    => $ERRORS{'CRIT'},
      'pausedsynct'    => $ERRORS{'CRIT'},
      'startingsyncs'  => $ERRORS{'WARN'},
      'startingsynct'  => $ERRORS{'WARN'},
      'syncsource'     => $ERRORS{'WARN'},
      'synctarget'     => $ERRORS{'WARN'},
      'verifys'        => $ERRORS{'WARN'},
      'verifyt'        => $ERRORS{'WARN'},
      'wfbitmaps'      => $ERRORS{'CRIT'},
      'wfbitmapt'      => $ERRORS{'CRIT'},
      'wfsyncuuid'     => $ERRORS{'WARN'},
   },

   # connection states
   'conn' =>
   {
      'brokenpipe'     => $ERRORS{'CRIT'},
      'connected'      => $ERRORS{'OKAY'},
      'connecting'     => $ERRORS{'WARN'},
      'disconnecting'  => $ERRORS{'WARN'},
      'networkfailure' => $ERRORS{'CRIT'},
      'protocolerror'  => $ERRORS{'CRIT'},
      'standalone'     => $ERRORS{'WARN'},
      'teardown'       => $ERRORS{'WARN'},
      'timeout'        => $ERRORS{'CRIT'},
      'unconnected'    => $ERRORS{'CRIT'},
      'wfconnection'   => $ERRORS{'CRIT'},
      'wfreportparams' => $ERRORS{'CRIT'},
   },

   # disk states
   'disk' =>
   {
      'attaching'      => $ERRORS{'WARN'},
      'consistent'     => $ERRORS{'OKAY'},
      'detaching'      => $ERRORS{'WARN'},
      'diskless'       => $ERRORS{'CRIT'},
      'dunknown'       => $ERRORS{'WARN'},
      'failed'         => $ERRORS{'CRIT'},
      'inconsistent'   => $ERRORS{'CRIT'},
      'negotiating'    => $ERRORS{'WARN'},
      'outdated'       => $ERRORS{'CRIT'},
      'uptodate'       => $ERRORS{'OKAY'},
   },

   # disk states
   'peer-disk' =>
   {
      'attaching'      => $ERRORS{'WARN'},
      'consistent'     => $ERRORS{'OKAY'},
      'detaching'      => $ERRORS{'WARN'},
      'diskless'       => $ERRORS{'WARN'},
      'dunknown'       => $ERRORS{'WARN'},
      'failed'         => $ERRORS{'WARN'},
      'inconsistent'   => $ERRORS{'WARN'},
      'negotiating'    => $ERRORS{'WARN'},
      'outdated'       => $ERRORS{'WARN'},
      'uptodate'       => $ERRORS{'OKAY'},
   },

   # roles
   'role' =>
   {
      'primary'        => $ERRORS{'OKAY'},
      'secondary'      => $ERRORS{'OKAY'},
      'unknown'        => $ERRORS{'WARN'},
      'unconfigured'   => $ERRORS{'CRIT'},
   },
};


# +-=-=-=-=-=-=-=+
# |              |
# |  Prototypes  |
# |              |
# +-=-=-=-=-=-=-=+

sub HELP_MESSAGE();
sub HELP_STATES($);
sub VERSION_MESSAGE();
sub chk_drbd_analyze($);
sub chk_drbd_config($);
sub chk_drbd_debug($@);
sub chk_drbd_detail($);
sub chk_drbd_detail_terse($);
sub chk_drbd_set_nagios($$$);
sub chk_drbd_nagios_code($);
sub chk_drbd_walk($);

sub main(@);                     # main statement


# +-=-=-=-=-=-=-+
# |             |
# |  Functions  |
# |             |
# +-=-=-=-=-=-=-+

sub HELP_MESSAGE()
{
   printf STDERR ("Usage: %s [OPTIONS]\n", $PROGRAM_NAME);
   printf STDERR ("OPTIONS:\n");
   printf STDERR ("  -0              return 'UNKNOWN' instead of 'OKAY' if no resources are found\n");
   printf STDERR ("  -c state        change specified state to 'CRIT' (example: SyncSource)\n");
   printf STDERR ("  -d pattern      same as '-i', added for compatibility with legacy check\n");
   printf STDERR ("  -h              display this message\n");
   printf STDERR ("  -i pattern      include resource name or resource minor (default: all)\n");
   printf STDERR ("  -l              list all OKAY resources after CRIT and WARN resources\n");
   printf STDERR ("  -o state        change specified state to 'OKAY' (example: StandAlone)\n");
   printf STDERR ("  -q              quiet output\n");
   printf STDERR ("  -t              display terse details\n");
   printf STDERR ("  -V              display program version\n");
   printf STDERR ("  -v              display OKAY resources\n");
   printf STDERR ("  -w state        change specified state to 'WARN' (example: SyncTarget)\n");
   printf STDERR ("  -x pattern      exclude resource name or resource minor\n");
   printf STDERR ("\n");
   printf STDERR ("ROLE STATES:\n");
   HELP_STATES('role');
   printf STDERR ("\n");
   printf STDERR ("LOCAL DISK STATES:\n");
   HELP_STATES('disk');
   printf STDERR ("\n");
   printf STDERR ("CONNECTION STATES:\n");
   HELP_STATES('conn');
   printf STDERR ("\n");
   printf STDERR ("PEER DISK STATES:\n");
   HELP_STATES('peer-disk');
   printf STDERR ("\n");
   printf STDERR ("REPLICATION STATES:\n");
   HELP_STATES('repl');
   printf STDERR ("\n");
   return(0);
};


sub HELP_STATES($)
{
   my $type = shift;

   my $count;
   my $left;
   my $center;
   my $right;
   my $state;
   my @states;

   if (!(defined($STATES->{$type})))
   {
      return(0);
   };

   @states = sort( keys( %{$STATES->{$type}} ) );

   for($count = 0; ($count < @states); $count += 3)
   {
      $state = $STATES->{$type}->{$states[$count]};
      $left  = $states[$count] . ' (' . $state->{'state'} . ')';

      $center = '';
      if (($count+1) < @states)
      {
         $state = $STATES->{$type}->{$states[$count+1]};
         $center = $states[$count+1] . ' (' . $state->{'state'} . ')';
      };

      $right = '';
      if (($count+2) < @states)
      {
         $state = $STATES->{$type}->{$states[$count+2]};
         $right = $states[$count+2] . ' (' . $state->{'state'} . ')';
      };

      printf STDERR ("   %-25s %-25s %s\n", $left, $center, $right);
   };

   return(0);
};


sub VERSION_MESSAGE()
{
   printf ("%s (%s)\n\n", $PROGRAM_NAME, $VERSION);
   return 0;
};


sub chk_drbd_analyze($)
{
   my $cnf = shift;

   my $res;
   my $dsk;
   my $con;
   my $dev;
   my $key;
   my $code;
   my $err;

   RESOURCE: for $res (@{$cnf->{'all'}})
   {
      $res->{'nagios'} = $ERRORS{'OKAY'};

      # weeds out unconfigured resources
      $code = chk_drbd_set_nagios($res, 'role', $res->{'role'});
      if ($code  == $ERRORS{'CRIT'}->{'code'})
      {
         chk_drbd_debug($cnf, "Resource role: %s\n", $res->{'role'});
         $err = $res->{'nagios'};
         $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
         next RESOURCE;
      };

      # loops through local disks
      for $key (keys(%{$res->{'devs'}}))
      {
         $code = chk_drbd_set_nagios($res, 'disk', $res->{'devs'}->{$key}->{'disk'});
         if ($code  == $ERRORS{'CRIT'}->{'code'})
         {
            chk_drbd_debug($cnf, "Disk disk: %s\n", $res->{'devs'}->{$key}->{'disk'});
            $err = $res->{'nagios'};
            $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
            next RESOURCE;
         };
      };

      # loops through connections
      CONNECTION: for $key (keys(%{$res->{'nodes'}}))
      {
         $con = $res->{'nodes'}->{$key};

         # connection's cstate
         $code = chk_drbd_set_nagios($res, 'conn', $con->{'connection'});
         if ($code  == $ERRORS{'CRIT'}->{'code'})
         {
            chk_drbd_debug($cnf, "Connection connection: %s\n", $con->{'connection'});
            $err = $res->{'nagios'};
            $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
            next RESOURCE;
         };
         if ($con->{'connection'} !~ /^Connected$/i)
         {
            next CONNECTION;
         };

         # loops through peer-disks
         for $key (keys(%{$con->{'devs'}}))
         {
            $dev = $con->{'devs'}->{$key};

            # peer-disk status
            $code = chk_drbd_set_nagios($res, 'peer-disk', $dev->{'peer-disk'});
            if ($code  == $ERRORS{'CRIT'}->{'code'})
            {
               chk_drbd_debug($cnf, "Connection peer-disk: %s\n", $dev->{'peer-disk'});
               $err = $res->{'nagios'};
               $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
               next RESOURCE;
            };

            # peer-disk replication state
            $code = chk_drbd_set_nagios($res, 'repl', $dev->{'replication'});
            if ($code  == $ERRORS{'CRIT'}->{'code'})
            {
               chk_drbd_debug($cnf, "Connection replication: %s\n", $dev->{'replication'});
               $err = $res->{'nagios'};
               $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
               next RESOURCE;
            };
         };
      };

      $err = $res->{'nagios'};
      $cnf->{$err->{'array'}}->[@{$cnf->{$err->{'array'}}}] = $res;
   };

   $cnf->{'count_crit'} = @{$cnf->{'crit'}};
   $cnf->{'count_warn'} = @{$cnf->{'warn'}};
   $cnf->{'count_okay'} = @{$cnf->{'okay'}};
   $cnf->{'count_all'}  = @{$cnf->{'crit'}};
   $cnf->{'count_all'} += @{$cnf->{'warn'}};
   $cnf->{'count_all'} += @{$cnf->{'okay'}};

   return(0);
};


sub chk_drbd_config($)
{
   my $cnf = shift;

   my $opt;
   my $list;
   my $state;
   my $key;

   $cnf->{'include'}                 = 'all';
   $cnf->{'exclude'}                 = '^$';
   $cnf->{'crit'}                    = [];
   $cnf->{'warn'}                    = [];
   $cnf->{'okay'}                    = [];
   $cnf->{'unknown'}                 = [];
   $cnf->{'all'}                     = [];
   $cnf->{'list'}                    = [];

   $Getopt::Std::STANDARD_HELP_VERSION=1;

   $opt = {};
   if (!(getopts("0d:c:hi:lo:qtvVw:x:", $opt)))
   {
      HELP_MESSAGE();
      return(3);
   };
   if (($cnf->{'h'}))
   {
      HELP_MESSAGE();
      return(3);
   };

   $cnf->{'include'}  = defined($opt->{'d'}) ? $opt->{'d'} : $cnf->{'include'};
   $cnf->{'include'}  = defined($opt->{'i'}) ? $opt->{'i'} : $cnf->{'include'};
   $cnf->{'exclude'}  = defined($opt->{'x'}) ? $opt->{'x'} : $cnf->{'exclude'};
   $cnf->{'terse'}    = defined($opt->{'t'}) ? $opt->{'t'} : 0;
   $cnf->{'quiet'}    = defined($opt->{'q'}) ? $opt->{'q'} : 0;
   $cnf->{'verbose'}  = defined($opt->{'v'}) ? $opt->{'v'} : 0;
   $cnf->{'list_all'} = defined($opt->{'l'}) ? $opt->{'l'} : 0;
   $cnf->{'zero'}     = defined($opt->{'0'}) ? $opt->{'0'} : 0;

   # override errors for okay
   $list = defined($opt->{'o'}) ? $opt->{'o'} : '';
   for $state (split(/[,\s]/, $list))
   {
      $state = lc($state);
      for $key (keys(%{$STATES}))
      {
         if ((defined($STATES->{$key}->{$state})))
         {
            $STATES->{$key}->{$state} = $ERRORS{'OKAY'};
         };
      };
   };

   # override errors for warn
   $list = defined($opt->{'w'}) ? $opt->{'w'} : '';
   for $state (split(/[,\s]/, $list))
   {  
      $state = lc($state);
      for $key (keys(%{$STATES}))
      {  
         if ((defined($STATES->{$key}->{$state})))
         {  
            $STATES->{$key}->{$state} = $ERRORS{'WARN'};
         }; 
      }; 
   };

   # override errors for crit
   $list = defined($opt->{'c'}) ? $opt->{'c'} : '';
   for $state (split(/[,\s]/, $list))
   {  
      $state = lc($state);
      for $key (keys(%{$STATES}))
      {  
         if ((defined($STATES->{$key}->{$state})))
         {  
            $STATES->{$key}->{$state} = $ERRORS{'CRIT'};
         }; 
      }; 
   };

   return(0);
};


sub chk_drbd_debug($@)
{
   my $cnf  = shift;
   my @args = @_;
   if ((defined($cnf->{'debug'})))
   {
      printf(@args);
   };
   return(0);
}


sub chk_drbd_detail($)
{
   my $res = shift;

   my $key;
   my $dev;
   my $node;
   my $sync;

   chk_drbd_detail_terse($res);

   # loop through devices
   for $key (sort(keys(%{$res->{'devs'}})))
   {
      $dev = $res->{'devs'}->{$key};
      printf("vol:%s disk:%s minor:%s size:%iMB\n",
         $key,
         $dev->{'disk'},
         $dev->{'minor'},
         int($dev->{'size'}/1024) );
   };

   # loop through nodes
   for $key (sort(keys(%{$res->{'nodes'}})))
   {
      $node = $res->{'nodes'}->{$key};
      printf("%s role:%s conn:%s\n", $key, $node->{'role'}, $node->{'connection'});

      # loop through peer-devices
      for $key (sort(keys(%{$node->{'devs'}})))
      {
         $dev = $node->{'devs'}->{$key};
         $sync = $dev->{'out-of-sync'} * 10000;
         $sync = $sync / $res->{'devs'}->{$key}->{'size'};
         $sync = 100 - int($sync) / 100;
         printf(".. vol:%s peer:%s repl:%s sync:%.2f%%\n",
            $key,
            $dev->{'peer-disk'},
            $dev->{'replication'},
            $sync );
      };
   };

   printf("-\n");

   return(0);
}


sub chk_drbd_detail_terse($)
{
   my $res = shift;
   printf("%s role:%s (%s)\n", $res->{'name'}, $res->{'role'}, $res->{'nagios'}->{'state'});
   return(0);
}


sub chk_drbd_set_nagios($$$)
{
   my $res   = shift;
   my $type  = shift;
   my $state = shift;
  
   my $err;

   if (!(defined($state)))
   {
      $res->{'nagios'} = $ERRORS{'CRIT'};
      return($res->{'nagios'}->{'code'});
   };

   $type  = lc($type);
   $state = lc($state);

   if (defined($STATES->{$type}->{$state}))
   {
      $err = $STATES->{$type}->{$state};
      if ($err->{'code'} > $res->{'nagios'}->{'code'})
      {
         $res->{'nagios'} = $err;
      };
      return($res->{'nagios'}->{'code'});
   };

   for $type (keys(%{$STATES}))
   {
      if (defined($STATES->{$type}->{$state}))
      {
         $err = $STATES->{$type}->{$state};
         if ($err->{'code'} > $res->{'nagios'}->{'code'})
         {
            $res->{'nagios'} = $err;
         };
         return($res->{'nagios'}->{'code'});
      };
   };

   $res->{'nagios'} = $ERRORS{'CRIT'};

   return($res->{'nagios'}->{'code'});
};


sub chk_drbd_nagios_code($)
{
   my $cnf = shift;
   my $count;

   if ($cnf->{'count_crit'} != 0)
   {
      return(2);
   };

   if ($cnf->{'count_warn'} != 0)
   {
      return(1);
   };

   if (($cnf->{'count_okay'} != 0) || ($cnf->{'zero'} == 0))
   {
      return(0);
   };

   return(3);
}


sub chk_drbd_walk($)
{
   my $cnf = shift;

   my $name;
   my $resource;
   my $resources;
   my $sh_resources;
   my $line;
   my $rec;
   my @lines;
   my %data;


   $resources = {};


   # parse /proc/drbd
   if (!(open(FD, '</proc/drbd')))
   {
      printf("DRBD UNKNOWN: kernel module is not loaded\n");
      return(3);
   };
   chomp(@lines = <FD>);
   close(FD);
   ($cnf->{'version'})    =  grep(/^version: /i,  @lines);
   if ((defined($cnf->{'version'})))
   {
      $cnf->{'version'}      =~ s/^version: //gi;
   };
   ($cnf->{'git-hash'})   = grep(/^GIT-hash: /i, @lines);
   if ((defined($cnf->{'git-hash'})))
   {
      $cnf->{'git-hash'}     =~ s/^GIT-hash: //gi;
   };
   ($cnf->{'transports'}) = grep(/^Transports /i, @lines);
   if ((defined($cnf->{'transports'})))
   {
      $cnf->{'transports'}   =~ s/^Transports //gi;
   };


   # builds resources
   $sh_resources = `/usr/sbin/drbdadm sh-resources 2> /dev/null`;
   if ($? != 0)
   {
      printf("DRBD UNKNOWN: error running drbdadm\n");
      return(3);
   };
   if ($sh_resources =~ /^$/)
   {
      return(0);
   };
   if ($sh_resources =~ /^([-_.\w\s]+)$/)
   {
      $sh_resources = $1;
      chomp($sh_resources);
      for $name (split(/\s/, $sh_resources))
      {
         # create new resource
         $resource            = {};
         $resource->{'name'}  = $name;
         $resource->{'role'}  = 'unconfigured';
         $resources->{$name}  = $resource;
      };
   } else {
      printf("DRBD UNKNOWN: invalid DRBD resource names found\n");
      return(3);
   };


   # read events
   @lines = `/usr/sbin/drbdsetup events2 --now --statistics all 2> /dev/null`;
   if ($? != 0)
   {
      printf("DRBD UNKNOWN: error running drbdsetup\n");
      return(3);
   };
   chomp(@lines);


   # parse resource lines
   for $line (grep(/^exists[\s]+resource/i, @lines))
   {
      %data               = split(/[ :]/, $line);
      $rec                = $resources->{$data{'name'}};
      $rec->{'nodes'}     = {};
      $rec->{'devs'}      = {};
      @{$rec}{keys %data} = values(%data);
   };


   # parse device lines
   for $line (grep(/^exists[\s]+device/i, @lines))
   {
      $rec = {};
      %{$rec} = split(/[ :]/, $line);
      $resource = $resources->{$rec->{'name'}};
      $resource->{'devs'}->{$rec->{'volume'}} = $rec;
   };


   # parse connection lines
   for $line (grep(/^exists[\s]+connection/i, @lines))
   {
      $rec = {};
      %{$rec} = split(/[ :]/, $line);
      $rec->{'devs'} = {};
      $resource = $resources->{$rec->{'name'}};
      $resource->{'nodes'}->{$rec->{'conn-name'}} = $rec;
   };


   # parse peer-device lines
   for $line (grep(/^exists[\s]+peer-device/i, @lines))
   {
      $rec = {};
      %{$rec} = split(/[ :]/, $line);
      $resource = $resources->{$rec->{'name'}}->{'nodes'}->{$rec->{'conn-name'}};
      $resource->{'devs'}->{$rec->{'volume'}} = $rec;
   };


   # pulls select resources to monitor
   for $name (keys(%{$resources}))
   {
      if ($name =~ $cnf->{'exclude'})
      {
         continue;
      };
      if ($name =~ $cnf->{'include'})
      {
         $cnf->{'all'}->[@{$cnf->{'all'}}] = $resources->{$name};
      }
      elsif (($cnf->{'include'} eq 'configured') && ($resources->{$name}->{'role'} ne 'unconfigured'))
      {
         $cnf->{'all'}->[@{$cnf->{'all'}}] = $resources->{$name};
      }
      elsif ($cnf->{'include'} =~ /^all$/i)
      {
         $cnf->{'all'}->[@{$cnf->{'all'}}] = $resources->{$name};
      };
   };


   return(0);
}



# +-=-=-=-=-=-=-=-=-+
# |                 |
# |  Main  Section  |
# |                 |
# +-=-=-=-=-=-=-=-=-+
sub main(@)
{
   # grabs passed args
   my @argv = @_;

   my $cnf;
   my $rc;
   my $res;
   my @resources;


   $cnf = {};


   # parses CLI arguments
   if ((chk_drbd_config($cnf)))
   {
      return(3);
   };


   # collects DRBD information
   if (($rc = chk_drbd_walk($cnf)) != 0)
   {
      return($rc);
   };


   chk_drbd_analyze($cnf);


   # print summary
   if ($cnf->{'count_all'} == $cnf->{'count_okay'})
   {
      printf("DRBD OKAY: %s\n", $cnf->{'version'});
   } else {
      printf("DRBD: ");
      if ($cnf->{'count_crit'} != 0)
      {
         printf("%s crit, ", $cnf->{'count_crit'});
      };
      if ($cnf->{'count_warn'} != 0)
      {
         printf("%s warn, ", $cnf->{'count_warn'});
      };
      printf("%s okay|\n", $cnf->{'count_okay'});
   };
   if ($cnf->{'quiet'} != 0)
   {
      return(chk_drbd_nagios_code($cnf));
   };
   printf("-\n");


   # print versions
   if ((defined($cnf->{'version'})))
   {
      printf("version:    %s\n", $cnf->{'version'});
   };
   if ((defined($cnf->{'transports'})))
   {
      printf("transports: %s\n", $cnf->{'transports'});
   };
   printf("resources:  %s\n", $cnf->{'count_all'});
   printf("-\n");


   # generates list of resources
   @resources = (sort({$a->{'name'} cmp $b->{'name'}} @{$cnf->{'crit'}}));
   @resources = (@resources, sort({$a->{'name'} cmp $b->{'name'}} @{$cnf->{'warn'}}));
   if ($cnf->{'verbose'} != 0)
   {
      @resources = (@resources, sort({$a->{'name'} cmp $b->{'name'}} @{$cnf->{'okay'}}));
   };


   # loops through each resource
   foreach $res (@resources)
   {
      if ($cnf->{'terse'} == 1)
      {
         chk_drbd_detail_terse($res);
      } else {
         chk_drbd_detail($res);
      };
   };


   # prints OKAY resources
   if (($cnf->{'terse'} == 0) && ($cnf->{'verbose'} == 0) && ($cnf->{'list_all'} == 1))
   {
      for $res (sort({$a->{'name'} cmp $b->{'name'}} @{$cnf->{'okay'}}))
      {
         chk_drbd_detail_terse($res);
      };
   };


   printf("|\n");


   # ends function
   return(chk_drbd_nagios_code($cnf));
};
exit(main(@ARGV));


# end of script
