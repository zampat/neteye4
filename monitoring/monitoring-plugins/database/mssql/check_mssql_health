#! /usr/bin/perl -w
# nagios: -epn

package Monitoring::GLPlugin::Commandline::Extraopts;
use strict;
use File::Basename;
use strict;

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    file => $params{file},
    commandline => $params{commandline},
    config => {},
    section => 'default_no_section',
  };
  bless $self, $class;
  $self->prepare_file_and_section();
  $self->init();
  return $self;
}

sub prepare_file_and_section {
  my $self = shift;
  if (! defined $self->{file}) {
    # ./check_stuff --extra-opts
    $self->{section} = basename($0);
    $self->{file} = $self->get_default_file();
  } elsif ($self->{file} =~ /^[^@]+$/) {
    # ./check_stuff --extra-opts=special_opts
    $self->{section} = $self->{file};
    $self->{file} = $self->get_default_file();
  } elsif ($self->{file} =~ /^@(.*)/) {
    # ./check_stuff --extra-opts=@/etc/myconfig.ini
    $self->{section} = basename($0);
    $self->{file} = $1;
  } elsif ($self->{file} =~ /^(.*?)@(.*)/) {
    # ./check_stuff --extra-opts=special_opts@/etc/myconfig.ini
    $self->{section} = $1;
    $self->{file} = $2;
  }
}

sub get_default_file {
  my $self = shift;
  foreach my $default (qw(/etc/nagios/plugins.ini
      /usr/local/nagios/etc/plugins.ini
      /usr/local/etc/nagios/plugins.ini
      /etc/opt/nagios/plugins.ini
      /etc/nagios-plugins.ini
      /usr/local/etc/nagios-plugins.ini
      /etc/opt/nagios-plugins.ini)) {
    if (-f $default) {
      return $default;
    }
  }
  return undef;
}

sub init {
  my $self = shift;
  if (! defined $self->{file}) {
    $self->{errors} = sprintf 'no extra-opts file specified and no default file found';
  } elsif (! -f $self->{file}) {
    $self->{errors} = sprintf 'could not open %s', $self->{file};
  } else {
    my $data = do { local (@ARGV, $/) = $self->{file}; <> };
    my $in_section = 'default_no_section';
    foreach my $line (split(/\n/, $data)) {
      if ($line =~ /\[(.*)\]/) {
        $in_section = $1;
      } elsif ($line =~ /(.*?)\s*=\s*(.*)/) {
        $self->{config}->{$in_section}->{$1} = $2;
      }
    }
  }
}

sub is_valid {
  my $self = shift;
  return ! exists $self->{errors};
}

sub overwrite {
  my $self = shift;
  if (scalar(keys %{$self->{config}->{default_no_section}}) > 0) {
    foreach (keys %{$self->{config}->{default_no_section}}) {
      $self->{commandline}->{$_} = $self->{config}->{default_no_section}->{$_};
    }
  }
  if (exists $self->{config}->{$self->{section}}) {
    foreach (keys %{$self->{config}->{$self->{section}}}) {
      $self->{commandline}->{$_} = $self->{config}->{$self->{section}}->{$_};
    }
  }
}

sub errors {
  my $self = shift;
  return $self->{errors} || "";
}



package Monitoring::GLPlugin::Commandline::Getopt;
use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case bundling);

# Standard defaults
my %DEFAULT = (
  timeout => 15,
  verbose => 0,
  license =>
"This monitoring plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).",
);
# Standard arguments
my @ARGS = ({
    spec => 'usage|?',
    help => "-?, --usage\n   Print usage information",
  }, {
    spec => 'help|h',
    help => "-h, --help\n   Print detailed help screen",
  }, {
    spec => 'version|V',
    help => "-V, --version\n   Print version information",
  }, {
    #spec => 'extra-opts:s@',
    #help => "--extra-opts=[<section>[@<config_file>]]\n   Section and/or config_file from which to load extra options (may repeat)",
  }, {
    spec => 'timeout|t=i',
    help => sprintf("-t, --timeout=INTEGER\n   Seconds before plugin times out (default: %s)", $DEFAULT{timeout}),
    default => $DEFAULT{timeout},
  }, {
    spec => 'verbose|v+',
    help => "-v, --verbose\n   Show details for command-line debugging (can repeat up to 3 times)",
    default => $DEFAULT{verbose},
  },
);
# Standard arguments we traditionally display last in the help output
my %DEFER_ARGS = map { $_ => 1 } qw(timeout verbose);

sub _init {
  my ($self, %params) = @_;
  # Check params
  my %attr = (
    usage => 1,
    version => 0,
    url => 0,
    plugin => { default => $Monitoring::GLPlugin::pluginname },
    blurb => 0,
    extra => 0,
    'extra-opts' => 0,
    license => { default => $DEFAULT{license} },
    timeout => { default => $DEFAULT{timeout} },
  );

  # Add attr to private _attr hash (except timeout)
  $self->{timeout} = delete $attr{timeout};
  $self->{_attr} = { %attr };
  foreach (keys %{$self->{_attr}}) {
    if (exists $params{$_}) {
      $self->{_attr}->{$_} = $params{$_};
    } else {
      $self->{_attr}->{$_} = $self->{_attr}->{$_}->{default}
          if ref ($self->{_attr}->{$_}) eq 'HASH' &&
              exists $self->{_attr}->{$_}->{default};
    }
  }
  # Chomp _attr values
  chomp foreach values %{$self->{_attr}};

  # Setup initial args list
  $self->{_args} = [ grep { exists $_->{spec} } @ARGS ];

  $self
}

sub new {
  my ($class, @params) = @_;
  require Monitoring::GLPlugin::Commandline::Extraopts
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Commandline::Extraopts::;
  my $self = bless {}, $class;
  $self->_init(@params);
}

sub decode_rfc3986 {
  my ($self, $password) = @_;
  if ($password && $password =~ /^rfc3986:\/\/(.*)/) {
    $password = $1;
    $password =~ s/%([A-Za-z0-9]{2})/chr(hex($1))/seg;
  }
  return $password;
}

sub add_arg {
  my ($self, %arg) = @_;
  push (@{$self->{_args}}, \%arg);
}

sub mod_arg {
  my ($self, $argname, %arg) = @_;
  foreach my $old_arg (@{$self->{_args}}) {
    next unless $old_arg->{spec} =~ /(\w+).*/ && $argname eq $1;
    foreach my $key (keys %arg) {
      $old_arg->{$key} = $arg{$key};
    }
  }
}

sub getopts {
  my ($self) = @_;
  my %commandline = ();
  $self->{opts}->{all_my_opts} = {};
  my @params = map { $_->{spec} } @{$self->{_args}};
  if (! GetOptions(\%commandline, @params)) {
    $self->print_help();
    exit 3;
  } else {
    no strict 'refs';
    no warnings 'redefine';
    if (exists $commandline{'extra-opts'}) {
      # read the extra file and overwrite other parameters
      my $extras = Monitoring::GLPlugin::Commandline::Extraopts->new(
          file => $commandline{'extra-opts'},
          commandline => \%commandline
      );
      if (! $extras->is_valid()) {
        printf "UNKNOWN - extra-opts are not valid: %s\n", $extras->errors();
        exit 3;
      } else {
        $extras->overwrite();
      }
    }
    do { $self->print_help(); exit 0; } if $commandline{help};
    do { $self->print_version(); exit 0 } if $commandline{version};
    do { $self->print_usage(); exit 3 } if $commandline{usage};
    foreach (map { $_->{spec} =~ /^([\w\-]+)/; $1; } @{$self->{_args}}) {
      my $field = $_;
      *{"$field"} = sub {
        return $self->{opts}->{$field};
      };
    }
    *{"all_my_opts"} = sub {
      return $self->{opts}->{all_my_opts};
    };
    foreach (map { $_->{spec} =~ /^([\w\-]+)/; $1; }
        grep { exists $_->{required} && $_->{required} } @{$self->{_args}}) {
      do { $self->print_usage(); exit 3 } if ! exists $commandline{$_};
    }
    foreach (grep { exists $_->{default} } @{$self->{_args}}) {
      $_->{spec} =~ /^([\w\-]+)/;
      my $spec = $1;
      $self->{opts}->{$spec} = $_->{default};
    }
    foreach (keys %commandline) {
      $self->{opts}->{$_} = $commandline{$_};
      $self->{opts}->{all_my_opts}->{$_} = $commandline{$_};
    }
    foreach (grep { exists $_->{env} } @{$self->{_args}}) {
      $_->{spec} =~ /^([\w\-]+)/;
      my $spec = $1;
      if (exists $ENV{'NAGIOS__HOST'.$_->{env}}) {
        $self->{opts}->{$spec} = $ENV{'NAGIOS__HOST'.$_->{env}};
      }
      if (exists $ENV{'NAGIOS__SERVICE'.$_->{env}}) {
        $self->{opts}->{$spec} = $ENV{'NAGIOS__SERVICE'.$_->{env}};
      }
    }
    foreach (grep { exists $_->{aliasfor} } @{$self->{_args}}) {
      my $field = $_->{aliasfor};
      $_->{spec} =~ /^([\w\-]+)/;
      my $aliasfield = $1;
      next if $self->{opts}->{$field};
      *{"$field"} = sub {
        return $self->{opts}->{$aliasfield};
      };
    }
    foreach (grep { exists $_->{decode} } @{$self->{_args}}) {
      my $decoding = $_->{decode};
      $_->{spec} =~ /^([\w\-]+)/;
      my $spec = $1;
      if (exists $self->{opts}->{$spec}) {
        if ($decoding eq "rfc3986") {
	  $self->{opts}->{$spec} =
	      $self->decode_rfc3986($self->{opts}->{$spec});
	}
      }
    }
  }
}

sub create_opt {
  my ($self, $key) = @_;
  no strict 'refs';
  *{"$key"} = sub {
      return $self->{opts}->{$key};
  };
}

sub override_opt {
  my ($self, $key, $value) = @_;
  $self->{opts}->{$key} = $value;
}

sub get {
  my ($self, $opt) = @_;
  return $self->{opts}->{$opt};
}

sub print_help {
  my ($self) = @_;
  $self->print_version();
  printf "\n%s\n", $self->{_attr}->{license};
  printf "\n%s\n\n", $self->{_attr}->{blurb};
  $self->print_usage();
  foreach (grep {
      ! (exists $_->{hidden} && $_->{hidden}) 
  } @{$self->{_args}}) {
    printf " %s\n", $_->{help};
  }
}

sub print_usage {
  my ($self) = @_;
  printf $self->{_attr}->{usage}, $self->{_attr}->{plugin};
  print "\n";
}

sub print_version {
  my ($self) = @_;
  printf "%s %s", $self->{_attr}->{plugin}, $self->{_attr}->{version};
  printf " [%s]", $self->{_attr}->{url} if $self->{_attr}->{url};
  print "\n";
}

sub print_license {
  my ($self) = @_;
  printf "%s\n", $self->{_attr}->{license};
  print "\n";
}



package Monitoring::GLPlugin::Commandline;
use strict;
use IO::File;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3, DEPENDENT => 4 };
our %ERRORS = (
    'OK'        => OK,
    'WARNING'   => WARNING,
    'CRITICAL'  => CRITICAL,
    'UNKNOWN'   => UNKNOWN,
    'DEPENDENT' => DEPENDENT,
);

our %STATUS_TEXT = reverse %ERRORS;
our $AUTOLOAD;


sub new {
  my ($class, %params) = @_;
  require Monitoring::GLPlugin::Commandline::Getopt
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Commandline::Getopt::;
  my $self = {
       perfdata => [],
       messages => {
         ok => [],
         warning => [],
         critical => [],
         unknown => [],
       },
       args => [],
       opts => Monitoring::GLPlugin::Commandline::Getopt->new(%params),
       modes => [],
       statefilesdir => undef,
  };
  foreach (qw(shortname usage version url plugin blurb extra
      license timeout)) {
    $self->{$_} = $params{$_};
  }
  bless $self, $class;
  $self->{plugin} ||= $Monitoring::GLPlugin::pluginname;
  $self->{name} = $self->{plugin};
  $Monitoring::GLPlugin::plugin = $self;
}

sub AUTOLOAD {
  my ($self, @params) = @_;
  return if ($AUTOLOAD =~ /DESTROY/);
  $self->debug("AUTOLOAD %s\n", $AUTOLOAD)
        if $self->{opts}->verbose >= 2;
  if ($AUTOLOAD =~ /^.*::(add_arg|override_opt|create_opt)$/) {
    $self->{opts}->$1(@params);
  }
}

sub DESTROY {
  my ($self) = @_;
  # ohne dieses DESTROY rennt nagios_exit in obiges AUTOLOAD rein
  # und fliegt aufs Maul, weil {opts} bereits nicht mehr existiert.
  # Unerklaerliches Verhalten.
}

sub debug {
  my ($self, $format, @message) = @_;
  if ($self->opts->verbose && $self->opts->verbose > 10) {
    printf("%s: ", scalar localtime);
    printf($format, @message);
    printf "\n";
  }
  if ($Monitoring::GLPlugin::tracefile) {
    my $logfh = IO::File->new();
    $logfh->autoflush(1);
    if ($logfh->open($Monitoring::GLPlugin::tracefile, "a")) {
      $logfh->printf("%s: ", scalar localtime);
      $logfh->printf($format, @message);
      $logfh->printf("\n");
      $logfh->close();
    }
  }
}

sub opts {
  my ($self) = @_;
  return $self->{opts};
}

sub getopts {
  my ($self) = @_;
  $self->opts->getopts();
}

sub add_message {
  my ($self, $code, @messages) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  push @{$self->{messages}->{$code}}, @messages;
}

sub selected_perfdata {
  my ($self, $label) = @_;
  if ($self->opts->can("selectedperfdata") && $self->opts->selectedperfdata) {
    my $pattern = $self->opts->selectedperfdata;
    return ($label =~ /$pattern/i) ? 1 : 0;
  } else {
    return 1;
  }
}

sub add_perfdata {
  my ($self, %args) = @_;
#printf "add_perfdata %s\n", Data::Dumper::Dumper(\%args);
#printf "add_perfdata %s\n", Data::Dumper::Dumper($self->{thresholds});
#
# wenn warning, critical, dann wird von oben ein expliziter wert mitgegeben
# wenn thresholds
#  wenn label in 
#    warningx $self->{thresholds}->{$label}->{warning} existiert
#  dann nimm $self->{thresholds}->{$label}->{warning}
#  ansonsten thresholds->default->warning
#

  my $label = $args{label};
  my $value = $args{value};
  my $uom = $args{uom} || "";
  my $format = '%d';

  if ($self->opts->can("morphperfdata") && $self->opts->morphperfdata) {
    # 'Intel [R] Interface (\d+) usage'='nic$1'
    foreach my $key (keys %{$self->opts->morphperfdata}) {
      if ($label =~ /$key/) {
        my $replacement = '"'.$self->opts->morphperfdata->{$key}.'"';
        my $oldlabel = $label;
        $label =~ s/$key/$replacement/ee;
        if (exists $self->{thresholds}->{$oldlabel}) {
          %{$self->{thresholds}->{$label}} = %{$self->{thresholds}->{$oldlabel}};
        }
      }
    }
  }
  if ($value =~ /\./) {
    if (defined $args{places}) {
      $value = sprintf '%.'.$args{places}.'f', $value;
    } else {
      $value = sprintf "%.2f", $value;
    }
  } else {
    $value = sprintf "%d", $value;
  }
  my $warn = "";
  my $crit = "";
  my $min = defined $args{min} ? $args{min} : "";
  my $max = defined $args{max} ? $args{max} : "";
  if ($args{thresholds} || (! exists $args{warning} && ! exists $args{critical})) {
    if (exists $self->{thresholds}->{$label}->{warning}) {
      $warn = $self->{thresholds}->{$label}->{warning};
    } elsif (exists $self->{thresholds}->{default}->{warning}) {
      $warn = $self->{thresholds}->{default}->{warning};
    }
    if (exists $self->{thresholds}->{$label}->{critical}) {
      $crit = $self->{thresholds}->{$label}->{critical};
    } elsif (exists $self->{thresholds}->{default}->{critical}) {
      $crit = $self->{thresholds}->{default}->{critical};
    }
  } else {
    if ($args{warning}) {
      $warn = $args{warning};
    }
    if ($args{critical}) {
      $crit = $args{critical};
    }
  }
  if ($uom eq "%") {
    $min = 0;
    $max = 100;
  }
  if (defined $args{places}) {
    # cut off excessive decimals which may be the result of a division
    # length = places*2, no trailing zeroes
    if ($warn ne "") {
      $warn = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $warn));
    }
    if ($crit ne "") {
      $crit = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $crit));
    }
    if ($min ne "") {
      $min = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $min));
    }
    if ($max ne "") {
      $max = join("", map {
          s/\.0+$//; $_
      } map {
          s/(\.[1-9]+)0+$/$1/; $_
      } map {
          /[\+\-\d\.]+/ ? sprintf '%.'.2*$args{places}.'f', $_ : $_;
      } split(/([\+\-\d\.]+)/, $max));
    }
  }
  push @{$self->{perfdata}}, sprintf("'%s'=%s%s;%s;%s;%s;%s",
      $label, $value, $uom, $warn, $crit, $min, $max)
      if $self->selected_perfdata($label);
}

sub add_pandora {
  my ($self, %args) = @_;
  my $label = $args{label};
  my $value = $args{value};

  if ($args{help}) {
    push @{$self->{pandora}}, sprintf("# HELP %s %s", $label, $args{help});
  }
  if ($args{type}) {
    push @{$self->{pandora}}, sprintf("# TYPE %s %s", $label, $args{type});
  }
  if ($args{labels}) {
    push @{$self->{pandora}}, sprintf("%s{%s} %s", $label,
        join(",", map {
            sprintf '%s="%s"', $_, $args{labels}->{$_};
        } keys %{$args{labels}}),
        $value);
  } else {
    push @{$self->{pandora}}, sprintf("%s %s", $label, $value);
  }
}

sub add_html {
  my ($self, $line) = @_;
  push @{$self->{html}}, $line;
}

sub suppress_messages {
  my ($self) = @_;
  $self->{suppress_messages} = 1;
}

sub clear_messages {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  $self->{messages}->{$code} = [];
}

sub reduce_messages_short {
  my ($self, $message) = @_;
  $message ||= "no problems";
  if ($self->opts->report && $self->opts->report eq "short") {
    $self->clear_messages(OK);
    $self->add_message(OK, $message) if ! $self->check_messages();
  }
}

sub reduce_messages {
  my ($self, $message) = @_;
  $message ||= "no problems";
  $self->clear_messages(OK);
  $self->add_message(OK, $message) if ! $self->check_messages();
}

sub check_messages {
  my ($self, %args) = @_;

  # Add object messages to any passed in as args
  for my $code (qw(critical warning unknown ok)) {
    my $messages = $self->{messages}->{$code} || [];
    if ($args{$code}) {
      unless (ref $args{$code} eq 'ARRAY') {
        if ($code eq 'ok') {
          $args{$code} = [ $args{$code} ];
        }
      }
      push @{$args{$code}}, @$messages;
    } else {
      $args{$code} = $messages;
    }
  }
  my %arg = %args;
  $arg{join} = ' ' unless defined $arg{join};

  # Decide $code
  my $code = OK;
  $code ||= CRITICAL  if @{$arg{critical}};
  $code ||= WARNING   if @{$arg{warning}};
  $code ||= UNKNOWN   if @{$arg{unknown}};
  return $code unless wantarray;

  # Compose message
  my $message = '';
  if ($arg{join_all}) {
      $message = join( $arg{join_all},
          map { @$_ ? join( $arg{'join'}, @$_) : () }
              $arg{critical},
              $arg{warning},
              $arg{unknown},
              $arg{ok} ? (ref $arg{ok} ? $arg{ok} : [ $arg{ok} ]) : []
      );
  }

  else {
      $message ||= join( $arg{'join'}, @{$arg{critical}} )
          if $code == CRITICAL;
      $message ||= join( $arg{'join'}, @{$arg{warning}} )
          if $code == WARNING;
      $message ||= join( $arg{'join'}, @{$arg{unknown}} )
          if $code == UNKNOWN;
      $message ||= ref $arg{ok} ? join( $arg{'join'}, @{$arg{ok}} ) : $arg{ok}
          if $arg{ok};
  }

  return ($code, $message);
}

sub status_code {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = uc $code;
  $code = $ERRORS{$code} if defined $code && exists $ERRORS{$code};
  $code = UNKNOWN unless defined $code && exists $STATUS_TEXT{$code};
  return "$STATUS_TEXT{$code}";
}

sub perfdata_string {
  my ($self) = @_;
  if (scalar (@{$self->{perfdata}})) {
    return join(" ", @{$self->{perfdata}});
  } else {
    return "";
  }
}

sub metrics_string {
  my ($self) = @_;
  if (scalar (@{$self->{metrics}})) {
    return join("\n", @{$self->{metrics}});
  } else {
    return "";
  }
}

sub html_string {
  my ($self) = @_;
  if (scalar (@{$self->{html}})) {
    return join(" ", @{$self->{html}});
  } else {
    return "";
  }
}

sub nagios_exit {
  my ($self, $code, $message, $arg) = @_;
  $code = $ERRORS{$code} if defined $code && exists $ERRORS{$code};
  $code = UNKNOWN unless defined $code && exists $STATUS_TEXT{$code};
  $message = '' unless defined $message;
  if (ref $message && ref $message eq 'ARRAY') {
      $message = join(' ', map { chomp; $_ } @$message);
  } else {
      chomp $message;
  }
  if ($self->opts->negate) {
    my $original_code = $code;
    foreach my $from (keys %{$self->opts->negate}) {
      if ((uc $from) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/ &&
          (uc $self->opts->negate->{$from}) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/) {
        if ($original_code == $ERRORS{uc $from}) {
          $code = $ERRORS{uc $self->opts->negate->{$from}};
        }
      }
    }
  }
  my $output = "$STATUS_TEXT{$code}";
  $output .= " - $message" if defined $message && $message ne '';
  if ($self->opts->can("morphmessage") && $self->opts->morphmessage) {
    # 'Intel [R] Interface (\d+) usage'='nic$1'
    # '^OK.*'="alles klar"   '^CRITICAL.*'="alles hi"
    foreach my $key (keys %{$self->opts->morphmessage}) {
      if ($output =~ /$key/) {
        my $replacement = '"'.$self->opts->morphmessage->{$key}.'"';
        $output =~ s/$key/$replacement/ee;
      }
    }
  }
  if ($self->opts->negate) {
    # negate again: --negate "UNKNOWN - no peers"=ok
    my $original_code = $code;
    foreach my $from (keys %{$self->opts->negate}) {
      if ((uc $from) !~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/ &&
          (uc $self->opts->negate->{$from}) =~ /^(OK|WARNING|CRITICAL|UNKNOWN)$/) {
        if ($output =~ /$from/) {
          $code = $ERRORS{uc $self->opts->negate->{$from}};
          $output =~ s/^.*? -/$STATUS_TEXT{$code} -/;
        }
      }
    }
  }
  $output =~ s/\|/!/g if $output;
  if (scalar (@{$self->{perfdata}})) {
    $output .= " | ".$self->perfdata_string();
  }
  $output .= "\n";
  if ($self->opts->can("isvalidtime") && ! $self->opts->isvalidtime) {
    $code = OK;
    $output = "OK - outside valid timerange. check results are not relevant now. original message was: ".
        $output;
  }
  if (! exists $self->{suppress_messages}) {
    print $output;
  }
  exit $code;
}

sub set_thresholds {
  my ($self, %params) = @_;
  if (exists $params{metric}) {
    my $metric = $params{metric};
    # erst die hartcodierten defaultschwellwerte
    $self->{thresholds}->{$metric}->{warning} = $params{warning};
    $self->{thresholds}->{$metric}->{critical} = $params{critical};
    # dann die defaultschwellwerte von der kommandozeile
    if (defined $self->opts->warning) {
      $self->{thresholds}->{$metric}->{warning} = $self->opts->warning;
    }
    if (defined $self->opts->critical) {
      $self->{thresholds}->{$metric}->{critical} = $self->opts->critical;
    }
    # dann die ganz spezifischen schwellwerte von der kommandozeile
    if ($self->opts->warningx) { # muss nicht auf defined geprueft werden, weils ein hash ist
      # Erst schauen, ob einer * beinhaltet. Von denen wird vom Laengsten
      # bis zum Kuerzesten probiert, ob die matchen. Der laengste Match
      # gewinnt.
      my @keys = keys %{$self->opts->warningx};
      my @stringkeys = ();
      my @regexkeys = ();
      foreach my $key (sort { length($b) > length($a) } @keys) {
        if ($key =~ /\*/) {
          push(@regexkeys, $key);
        } else {
          push(@stringkeys, $key);
        }
      }
      foreach my $key (@regexkeys) {
        next if $metric !~ /$key/;
        $self->{thresholds}->{$metric}->{warning} = $self->opts->warningx->{$key};
        last;
      }
      # Anschliessend nochmal schauen, ob es einen nicht-Regex-Volltreffer gibt
      foreach my $key (@stringkeys) {
        next if $key ne $metric;
        $self->{thresholds}->{$metric}->{warning} = $self->opts->warningx->{$key};
        last;
      }
    }
    if ($self->opts->criticalx) {
      my @keys = keys %{$self->opts->criticalx};
      my @stringkeys = ();
      my @regexkeys = ();
      foreach my $key (sort { length($b) > length($a) } @keys) {
        if ($key =~ /\*/) {
          push(@regexkeys, $key);
        } else {
          push(@stringkeys, $key);
        }
      }
      foreach my $key (@regexkeys) {
        next if $metric !~ /$key/;
        $self->{thresholds}->{$metric}->{critical} = $self->opts->criticalx->{$key};
        last;
      }
      # Anschliessend nochmal schauen, ob es einen nicht-Regex-Volltreffer gibt
      foreach my $key (@stringkeys) {
        next if $key ne $metric;
        $self->{thresholds}->{$metric}->{critical} = $self->opts->criticalx->{$key};
        last;
      }
    }
  } else {
    $self->{thresholds}->{default}->{warning} =
        defined $self->opts->warning ? $self->opts->warning : defined $params{warning} ? $params{warning} : 0;
    $self->{thresholds}->{default}->{critical} =
        defined $self->opts->critical ? $self->opts->critical : defined $params{critical} ? $params{critical} : 0;
  }
}

sub force_thresholds {
  my ($self, %params) = @_;
  if (exists $params{metric}) {
    my $metric = $params{metric};
    $self->{thresholds}->{$metric}->{warning} = $params{warning} || 0;
    $self->{thresholds}->{$metric}->{critical} = $params{critical} || 0;
  } else {
    $self->{thresholds}->{default}->{warning} = $params{warning} || 0;
    $self->{thresholds}->{default}->{critical} = $params{critical} || 0;
  }
}

sub get_thresholds {
  my ($self, @params) = @_;
  if (scalar(@params) > 1) {
    my %params = @params;
    my $metric = $params{metric};
    return ($self->{thresholds}->{$metric}->{warning},
        $self->{thresholds}->{$metric}->{critical});
  } else {
    return ($self->{thresholds}->{default}->{warning},
        $self->{thresholds}->{default}->{critical});
  }
}

sub check_thresholds {
  my ($self, @params) = @_;
  my $level = $ERRORS{OK};
  my $warningrange;
  my $criticalrange;
  my $value;
  if (scalar(@params) > 1) {
    my %params = @params;
    $value = $params{value};
    my $metric = $params{metric};
    if ($metric ne 'default') {
      $warningrange = exists $self->{thresholds}->{$metric}->{warning} ?
          $self->{thresholds}->{$metric}->{warning} :
          $self->{thresholds}->{default}->{warning};
      $criticalrange = exists $self->{thresholds}->{$metric}->{critical} ?
          $self->{thresholds}->{$metric}->{critical} :
          $self->{thresholds}->{default}->{critical};
    } else {
      $warningrange = (defined $params{warning}) ?
          $params{warning} : $self->{thresholds}->{default}->{warning};
      $criticalrange = (defined $params{critical}) ?
          $params{critical} : $self->{thresholds}->{default}->{critical};
    }
  } else {
    $value = $params[0];
    $warningrange = $self->{thresholds}->{default}->{warning};
    $criticalrange = $self->{thresholds}->{default}->{critical};
  }
  if (! defined $warningrange) {
    # there was no set_thresholds for defaults, no --warning, no --warningx
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = 10, warn if > 10 or < 0
    $level = $ERRORS{WARNING}
        if ($value > $1 || $value < 0);
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+):$/) {
    # warning = 10:, warn if < 10
    $level = $ERRORS{WARNING}
        if ($value < $1);
  } elsif ($warningrange =~ /^~:([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = ~:10, warn if > 10
    $level = $ERRORS{WARNING}
        if ($value > $1);
  } elsif ($warningrange =~ /^([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = 10:20, warn if < 10 or > 20
    $level = $ERRORS{WARNING}
        if ($value < $1 || $value > $2);
  } elsif ($warningrange =~ /^@([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # warning = @10:20, warn if >= 10 and <= 20
    $level = $ERRORS{WARNING}
        if ($value >= $1 && $value <= $2);
  }
  if (! defined $criticalrange) {
    # there was no set_thresholds for defaults, no --critical, no --criticalx
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = 10, crit if > 10 or < 0
    $level = $ERRORS{CRITICAL}
        if ($value > $1 || $value < 0);
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+):$/) {
    # critical = 10:, crit if < 10
    $level = $ERRORS{CRITICAL}
        if ($value < $1);
  } elsif ($criticalrange =~ /^~:([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = ~:10, crit if > 10
    $level = $ERRORS{CRITICAL}
        if ($value > $1);
  } elsif ($criticalrange =~ /^([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = 10:20, crit if < 10 or > 20
    $level = $ERRORS{CRITICAL}
        if ($value < $1 || $value > $2);
  } elsif ($criticalrange =~ /^@([-+]?[0-9]*\.?[0-9]+):([-+]?[0-9]*\.?[0-9]+)$/) {
    # critical = @10:20, crit if >= 10 and <= 20
    $level = $ERRORS{CRITICAL}
        if ($value >= $1 && $value <= $2);
  }
  return $level;
}

sub strequal {
  my($self, $str1, $str2) = @_;
  return 1 if ! defined $str1 && ! defined $str2;
  return 0 if ! defined $str1 && defined $str2;
  return 0 if defined $str1 && ! defined $str2;
  return 1 if $str1 eq $str2;
  return 0;
}



package Monitoring::GLPlugin;

=head1 Monitoring::GLPlugin

Monitoring::GLPlugin - infrastructure functions to build a monitoring plugin

=cut

use strict;
use IO::File;
use File::Basename;
use Digest::MD5 qw(md5_hex);
use Errno;
use Data::Dumper;
$Data::Dumper::Indent = 1;
eval {
  # avoid "used only once" because older Data::Dumper don't have this
  # use OMD please because OMD has everything!
  no warnings 'all';
  $Data::Dumper::Sparseseen = 1;
};
our $AUTOLOAD;
*VERSION = \'3.0.2.2';

use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

{
  our $mode = undef;
  our $plugin = undef;
  our $pluginname = basename($ENV{'NAGIOS_PLUGIN'} || $0);
  our $blacklist = undef;
  our $info = [];
  our $extendedinfo = [];
  our $summary = [];
  our $variables = {};
  our $survive_sudo_env = ["LD_LIBRARY_PATH", "SHLIB_PATH"];
}

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  require Monitoring::GLPlugin::Commandline
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Commandline::;
  require Monitoring::GLPlugin::Item
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::Item::;
  require Monitoring::GLPlugin::TableItem
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::TableItem::;
  $Monitoring::GLPlugin::plugin = Monitoring::GLPlugin::Commandline->new(%params);
  return $self;
}

sub rebless {
  my ($self, $class) = @_;
  bless $self, $class;
  $self->debug('using '.$class);
  # gilt nur fuer "echte" Fabrikate mit "Classes::" vorndran
  $self->{classified_as} = ref($self) if $class !~ /^Monitoring::GLPlugin/;
}

sub init {
  my ($self) = @_;
  if ($self->opts->can("blacklist") && $self->opts->blacklist &&
      -f $self->opts->blacklist) {
    $self->opts->blacklist = do {
        local (@ARGV, $/) = $self->opts->blacklist; <> };
  }
}

sub dumper {
  my ($self, $object) = @_;
  my $run = $object->{runtime};
  delete $object->{runtime};
  printf STDERR "%s\n", Data::Dumper::Dumper($object);
  $object->{runtime} = $run;
}

sub no_such_mode {
  my ($self) = @_;
  printf "Mode %s is not implemented for this type of device\n",
      $self->opts->mode;
  exit 3;
}

#########################################################
# framework-related. setup, options
#
sub add_default_args {
  my ($self) = @_;
  $self->add_arg(
      spec => 'mode=s',
      help => "--mode
   A keyword which tells the plugin what to do",
      required => 1,
  );
  $self->add_arg(
      spec => 'regexp',
      help => "--regexp
   Parameter name/name2/name3 will be interpreted as (perl) regular expression",
      required => 0,);
  $self->add_arg(
      spec => 'warning=s',
      help => "--warning
   The warning threshold",
      required => 0,);
  $self->add_arg(
      spec => 'critical=s',
      help => "--critical
   The critical threshold",
      required => 0,);
  $self->add_arg(
      spec => 'warningx=s%',
      help => '--warningx
   The extended warning thresholds
   e.g. --warningx db_msdb_free_pct=6: to override the threshold for a
   specific item ',
      required => 0,
  );
  $self->add_arg(
      spec => 'criticalx=s%',
      help => '--criticalx
   The extended critical thresholds',
      required => 0,
  );
  $self->add_arg(
      spec => 'units=s',
      help => "--units
   One of %, B, KB, MB, GB, Bit, KBi, MBi, GBi. (used for e.g. mode interface-usage)",
      required => 0,
  );
  $self->add_arg(
      spec => 'name=s',
      help => "--name
   The name of a specific component to check",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'name2=s',
      help => "--name2
   The secondary name of a component",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'name3=s',
      help => "--name3
   The tertiary name of a component",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'extra-opts=s',
      help => "--extra-opts
   read command line arguments from an external file",
      required => 0,
  );
  $self->add_arg(
      spec => 'blacklist|b=s',
      help => '--blacklist
   Blacklist some (missing/failed) components',
      required => 0,
      default => '',
  );
  $self->add_arg(
      spec => 'mitigation=s',
      help => "--mitigation
   The parameter allows you to change a critical error to a warning.
   It works only for specific checks. Which ones? Try it out or look in the code.
   --mitigation warning ranks an error as warning which by default would be critical.",
      required => 0,
  );
  $self->add_arg(
      spec => 'lookback=s',
      help => "--lookback
   The amount of time you want to look back when calculating average rates.
   Use it for mode interface-errors or interface-usage. Without --lookback
   the time between two runs of check_nwc_health is the base for calculations.
   If you want your checkresult to be based for example on the past hour,
   use --lookback 3600. ",
      required => 0,
  );
  $self->add_arg(
      spec => 'environment|e=s%',
      help => "--environment
   Add a variable to the plugin's environment",
      required => 0,
  );
  $self->add_arg(
      spec => 'negate=s%',
      help => "--negate
   Emulate the negate plugin. --negate warning=critical --negate unknown=critical",
      required => 0,
  );
  $self->add_arg(
      spec => 'morphmessage=s%',
      help => '--morphmessage
   Modify the final output message',
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'morphperfdata=s%',
      help => "--morphperfdata
   The parameter allows you to change performance data labels.
   It's a perl regexp and a substitution.
   Example: --morphperfdata '(.*)ISATAP(.*)'='\$1patasi\$2'",
      required => 0,
      decode => "rfc3986",
  );
  $self->add_arg(
      spec => 'selectedperfdata=s',
      help => "--selectedperfdata
   The parameter allows you to limit the list of performance data. It's a perl regexp.
   Only matching perfdata show up in the output",
      required => 0,
  );
  $self->add_arg(
      spec => 'report=s',
      help => "--report
   Can be used to shorten the output",
      required => 0,
      default => 'long',
  );
  $self->add_arg(
      spec => 'multiline',
      help => '--multiline
   Multiline output',
      required => 0,
  );
  $self->add_arg(
      spec => 'with-mymodules-dyn-dir=s',
      help => "--with-mymodules-dyn-dir
   Add-on modules for the my-modes will be searched in this directory",
      required => 0,
  );
  $self->add_arg(
      spec => 'statefilesdir=s',
      help => '--statefilesdir
   An alternate directory where the plugin can save files',
      required => 0,
      env => 'STATEFILESDIR',
  );
  $self->add_arg(
      spec => 'isvalidtime=i',
      help => '--isvalidtime
   Signals the plugin to return OK if now is not a valid check time',
      required => 0,
      default => 1,
  );
  $self->add_arg(
      spec => 'reset',
      help => "--reset
   remove the state file",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'runas=s',
      help => "--runas
   run as a different user",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'shell',
      help => "--shell
   forget what you see",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'drecksptkdb=s',
      help => "--drecksptkdb
   This parameter must be used instead of --name, because Devel::ptkdb is stealing the latter from the command line",
      aliasfor => "name",
      required => 0,
      hidden => 1,
  );
  $self->add_arg(
      spec => 'tracefile=s',
      help => "--tracefile
   Write debugging-info to this file (if it exists)",
      required => 0,
      hidden => 1,
  );
}

sub add_default_modes {
  my ($self) = @_;
  $self->add_mode(
      internal => 'encode',
      spec => 'encode',
      alias => undef,
      help => 'encode stdin',
      hidden => 1,
  );
  $self->add_mode(
      internal => 'decode',
      spec => 'decode',
      alias => undef,
      help => 'decode stdin or --name',
      hidden => 1,
  );
}

sub add_modes {
  my ($self, $modes) = @_;
  my $modestring = "";
  my @modes = @{$modes};
  my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
  my $format = "       %-".
      (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).
      "s\t(%s)\n";
  foreach (@modes) {
    $modestring .= sprintf $format, $_->[1], $_->[3];
  }
  $modestring .= sprintf "\n";
  $Monitoring::GLPlugin::plugin->{modestring} = $modestring;
}

sub add_arg {
  my ($self, %args) = @_;
  if ($args{help} =~ /^--mode/) {
    $args{help} .= "\n".$Monitoring::GLPlugin::plugin->{modestring};
  }
  $Monitoring::GLPlugin::plugin->{opts}->add_arg(%args);
}

sub mod_arg {
  my ($self, @arg) = @_;
  $Monitoring::GLPlugin::plugin->{opts}->mod_arg(@arg);
}

sub add_mode {
  my ($self, %args) = @_;
  push(@{$Monitoring::GLPlugin::plugin->{modes}}, \%args);
  my $longest = length ((reverse sort {length $a <=> length $b} map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}})[0]);
  my $format = "       %-".
      (length ((reverse sort {length $a <=> length $b} map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}})[0])).
      "s\t(%s)\n";
  $Monitoring::GLPlugin::plugin->{modestring} = "";
  foreach (@{$Monitoring::GLPlugin::plugin->{modes}}) {
    $Monitoring::GLPlugin::plugin->{modestring} .= sprintf $format, $_->{spec}, $_->{help};
  }
  $Monitoring::GLPlugin::plugin->{modestring} .= "\n";
}

sub validate_args {
  my ($self) = @_;
  if ($self->opts->mode =~ /^my-([^\-.]+)/) {
    my $param = $self->opts->mode;
    $param =~ s/\-/::/g;
    $self->add_mode(
        internal => $param,
        spec => $self->opts->mode,
        alias => undef,
        help => 'my extension',
    );
  } elsif ($self->opts->mode eq 'encode') {
    my $input = <>;
    chomp $input;
    $input =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
    printf "%s\n", $input;
    exit 0;
  } elsif ($self->opts->mode eq 'decode') {
    if (! -t STDIN) {
      my $input = <>;
      chomp $input;
      $input =~ s/%([A-Za-z0-9]{2})/chr(hex($1))/seg;
      printf "%s\n", $input;
      exit OK;
    } else {
      if ($self->opts->name) {
        my $input = $self->opts->name;
        $input =~ s/%([A-Za-z0-9]{2})/chr(hex($1))/seg;
        printf "%s\n", $input;
        exit OK;
      } else {
        printf "i can't find your encoded statement. use --name or pipe it in my stdin\n";
        exit UNKNOWN;
      }
    }
  } elsif ((! grep { $self->opts->mode eq $_ } map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}}) &&
      (! grep { $self->opts->mode eq $_ } map { defined $_->{alias} ? @{$_->{alias}} : () } @{$Monitoring::GLPlugin::plugin->{modes}})) {
    printf "UNKNOWN - mode %s\n", $self->opts->mode;
    $self->opts->print_help();
    exit 3;
  }
  if ($self->opts->name && $self->opts->name =~ /(%22)|(%27)/) {
    my $name = $self->opts->name;
    $name =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $self->override_opt('name', $name);
  }
  $Monitoring::GLPlugin::mode = (
      map { $_->{internal} }
      grep {
         ($self->opts->mode eq $_->{spec}) ||
         ( defined $_->{alias} && grep { $self->opts->mode eq $_ } @{$_->{alias}})
      } @{$Monitoring::GLPlugin::plugin->{modes}}
  )[0];
  if ($self->opts->multiline) {
    $ENV{NRPE_MULTILINESUPPORT} = 1;
  } else {
    $ENV{NRPE_MULTILINESUPPORT} = 0;
  }
  if ($self->opts->can("statefilesdir") && ! $self->opts->statefilesdir) {
    if ($^O =~ /MSWin/) {
      if (defined $ENV{TEMP}) {
        $self->override_opt('statefilesdir', $ENV{TEMP}."/".$Monitoring::GLPlugin::plugin->{name});
      } elsif (defined $ENV{TMP}) {
        $self->override_opt('statefilesdir', $ENV{TMP}."/".$Monitoring::GLPlugin::plugin->{name});
      } elsif (defined $ENV{windir}) {
        $self->override_opt('statefilesdir', File::Spec->catfile($ENV{windir}, 'Temp')."/".$Monitoring::GLPlugin::plugin->{name});
      } else {
        $self->override_opt('statefilesdir', "C:/".$Monitoring::GLPlugin::plugin->{name});
      }
    } elsif (exists $ENV{OMD_ROOT}) {
      $self->override_opt('statefilesdir', $ENV{OMD_ROOT}."/var/tmp/".$Monitoring::GLPlugin::plugin->{name});
    } else {
      $self->override_opt('statefilesdir', "/var/tmp/".$Monitoring::GLPlugin::plugin->{name});
    }
  }
  $Monitoring::GLPlugin::plugin->{statefilesdir} = $self->opts->statefilesdir
      if $self->opts->can("statefilesdir");
  if ($self->opts->can("warningx") && $self->opts->warningx) {
    foreach my $key (keys %{$self->opts->warningx}) {
      $self->set_thresholds(metric => $key,
          warning => $self->opts->warningx->{$key});
    }
  }
  if ($self->opts->can("criticalx") && $self->opts->criticalx) {
    foreach my $key (keys %{$self->opts->criticalx}) {
      $self->set_thresholds(metric => $key,
          critical => $self->opts->criticalx->{$key});
    }
  }
  $self->set_timeout_alarm() if ! $SIG{'ALRM'};
}

sub set_timeout_alarm {
  my ($self, $timeout, $handler) = @_;
  $timeout ||= $self->opts->timeout;
  $handler ||= sub {
    $self->nagios_exit(UNKNOWN,
        sprintf("%s timed out after %d seconds\n",
            $Monitoring::GLPlugin::plugin->{name}, $self->opts->timeout)
    );
  };
  use POSIX ':signal_h';
  if ($^O =~ /MSWin/) {
    local $SIG{'ALRM'} = $handler;
  } else {
    my $mask = POSIX::SigSet->new( SIGALRM );
    my $action = POSIX::SigAction->new(
        $handler, $mask
    );   
    my $oldaction = POSIX::SigAction->new();
    sigaction(SIGALRM ,$action ,$oldaction );
  }    
  alarm(int($timeout)); # 1 second before the global unknown timeout
}

#########################################################
# global helpers
#
sub set_variable {
  my ($self, $key, $value) = @_;
  $Monitoring::GLPlugin::variables->{$key} = $value;
}

sub get_variable {
  my ($self, $key, $fallback) = @_;
  return exists $Monitoring::GLPlugin::variables->{$key} ?
      $Monitoring::GLPlugin::variables->{$key} : $fallback;
}

sub debug {
  my ($self, $format, @message) = @_;
  if ($self->get_variable("verbose") &&
      $self->get_variable("verbose") > $self->get_variable("verbosity", 10)) {
    printf("%s: ", scalar localtime);
    printf($format, @message);
    printf "\n";
  }
  if ($Monitoring::GLPlugin::tracefile) {
    my $logfh = IO::File->new();
    $logfh->autoflush(1);
    if ($logfh->open($Monitoring::GLPlugin::tracefile, "a")) {
      $logfh->printf("%s: ", scalar localtime);
      $logfh->printf($format, @message);
      $logfh->printf("\n");
      $logfh->close();
    }
  }
}

sub filter_namex {
  my ($self, $opt, $name) = @_;
  if ($opt) {
    if ($self->opts->regexp) {
      if ($name =~ /$opt/i) {
        return 1;
      }
    } else {
      if (lc $opt eq lc $name) {
        return 1;
      }
    }
  } else {
    return 1;
  }
  return 0;
}

sub filter_name {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name, $name);
}

sub filter_name2 {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name2, $name);
}

sub filter_name3 {
  my ($self, $name) = @_;
  return $self->filter_namex($self->opts->name3, $name);
}

sub version_is_minimum {
  my ($self, $version) = @_;
  my $installed_version;
  my $newer = 1;
  if ($self->get_variable("version")) {
    $installed_version = $self->get_variable("version");
  } elsif (exists $self->{version}) {
    $installed_version = $self->{version};
  } else {
    return 0;
  }
  my @v1 = map { $_ eq "x" ? 0 : $_ } split(/\./, $version);
  my @v2 = split(/\./, $installed_version);
  if (scalar(@v1) > scalar(@v2)) {
    push(@v2, (0) x (scalar(@v1) - scalar(@v2)));
  } elsif (scalar(@v2) > scalar(@v1)) {
    push(@v1, (0) x (scalar(@v2) - scalar(@v1)));
  }
  foreach my $pos (0..$#v1) {
    if ($v2[$pos] > $v1[$pos]) {
      $newer = 1;
      last;
    } elsif ($v2[$pos] < $v1[$pos]) {
      $newer = 0;
      last;
    }
  }
  return $newer;
}

sub accentfree {
  my ($self, $text) = @_;
  # thanks mycoyne who posted this accent-remove-algorithm
  # http://www.experts-exchange.com/Programming/Languages/Scripting/Perl/Q_23275533.html#a21234612
  my @transformed;
  my %replace = (
    '9a' => 's', '9c' => 'oe', '9e' => 'z', '9f' => 'Y', 'c0' => 'A', 'c1' => 'A',
    'c2' => 'A', 'c3' => 'A', 'c4' => 'A', 'c5' => 'A', 'c6' => 'AE', 'c7' => 'C',
    'c8' => 'E', 'c9' => 'E', 'ca' => 'E', 'cb' => 'E', 'cc' => 'I', 'cd' => 'I',
    'ce' => 'I', 'cf' => 'I', 'd0' => 'D', 'd1' => 'N', 'd2' => 'O', 'd3' => 'O',
    'd4' => 'O', 'd5' => 'O', 'd6' => 'O', 'd8' => 'O', 'd9' => 'U', 'da' => 'U',
    'db' => 'U', 'dc' => 'U', 'dd' => 'Y', 'e0' => 'a', 'e1' => 'a', 'e2' => 'a',
    'e3' => 'a', 'e4' => 'a', 'e5' => 'a', 'e6' => 'ae', 'e7' => 'c', 'e8' => 'e',
    'e9' => 'e', 'ea' => 'e', 'eb' => 'e', 'ec' => 'i', 'ed' => 'i', 'ee' => 'i',
    'ef' => 'i', 'f0' => 'o', 'f1' => 'n', 'f2' => 'o', 'f3' => 'o', 'f4' => 'o',
    'f5' => 'o', 'f6' => 'o', 'f8' => 'o', 'f9' => 'u', 'fa' => 'u', 'fb' => 'u',
    'fc' => 'u', 'fd' => 'y', 'ff' => 'y',
  );
  my @letters = split //, $text;;
  for (my $i = 0; $i <= $#letters; $i++) {
    my $hex = sprintf "%x", ord($letters[$i]);
    $letters[$i] = $replace{$hex} if (exists $replace{$hex});
  }
  push @transformed, @letters;
  return join '', @transformed;
}

sub dump {
  my ($self, $indent) = @_;
  $indent = $indent ? " " x $indent : "";
  my $class = ref($self);
  $class =~ s/^.*:://;
  if (exists $self->{flat_indices}) {
    printf "%s[%s_%s]\n", $indent, uc $class, $self->{flat_indices};
  } else {
    printf "%s[%s]\n", $indent, uc $class;
  }
  foreach (grep !/^(info|trace|warning|critical|blacklisted|extendedinfo|flat_indices|indices)$/, sort keys %{$self}) {
    printf "%s%s: %s\n", $indent, $_, $self->{$_} if defined $self->{$_} && ref($self->{$_}) ne "ARRAY";
  }
  if ($self->{info}) {
    printf "%sinfo: %s\n", $indent, $self->{info};
  }
  foreach (grep !/^(info|trace|warning|critical|blacklisted|extendedinfo|flat_indices|indices)$/, sort keys %{$self}) {
    if (defined $self->{$_} && ref($self->{$_}) eq "ARRAY") {
      my $have_flat_indices = 1;
      foreach my $obj (@{$self->{$_}}) {
        $have_flat_indices = 0 if (ref($obj) ne "HASH" || ! exists $obj->{flat_indices});
      }
      if ($have_flat_indices) {
        foreach my $obj (sort {
            join('', map { sprintf("%30d",$_) } split( /\./, $a->{flat_indices})) cmp
            join('', map { sprintf("%30d",$_) } split( /\./, $b->{flat_indices}))
        } @{$self->{$_}}) {
          $obj->dump();
        }
      } else {
        foreach my $obj (@{$self->{$_}}) {
          $obj->dump() if UNIVERSAL::can($obj, "isa") && $obj->can("dump");
        }
      }
    } elsif (defined $self->{$_} && ref($self->{$_}) =~ /^Classes::/) {
      $self->{$_}->dump(2) if UNIVERSAL::can($self->{$_}, "isa") && $self->{$_}->can("dump");
    }
  }
  printf "\n";
}

sub table_ascii {
  my ($self, $table, $titles) = @_;
  my $text = "";
  my $column_length = {};
  my $column = 0;
  foreach (@{$titles}) {
    $column_length->{$column++} = length($_);
  }
  foreach my $tr (@{$table}) {
    @{$tr} = map { ref($_) eq "ARRAY" ? $_->[0] : $_; } @{$tr};
    $column = 0;
    foreach my $td (@{$tr}) {
      if (length($td) > $column_length->{$column}) {
        $column_length->{$column} = length($td);
      }
      $column++;
    }
  }
  $column = 0;
  foreach (@{$titles}) {
    $column_length->{$column} = "%".($column_length->{$column} + 3)."s";
    $column++;
  }
  $column = 0;
  foreach (@{$titles}) {
    $text .= sprintf $column_length->{$column++}, $_;
  }
  $text .= "\n";
  foreach my $tr (@{$table}) {
    $column = 0;
    foreach my $td (@{$tr}) {
      $text .= sprintf $column_length->{$column++}, $td;
    }
    $text .= "\n";
  }
  return $text;
}

sub table_html {
  my ($self, $table, $titles) = @_;
  my $text = "";
  $text .= "<table style=\"border-collapse:collapse; border: 1px solid black;\">";
  $text .= "<tr>";
  foreach (@{$titles}) {
    $text .= sprintf "<th style=\"text-align: left; padding-left: 4px; padding-right: 6px;\">%s</th>", $_;
  }
  $text .= "</tr>";
  foreach my $tr (@{$table}) {
    $text .= "<tr>";
    foreach my $td (@{$tr}) {
      my $class = "statusOK";
      if (ref($td) eq "ARRAY") {
        $class = {
          0 => "statusOK",
          1 => "statusWARNING",
          2 => "statusCRITICAL",
          3 => "statusUNKNOWN",
        }->{$td->[1]};
        $td = $td->[0];
      }
      $text .= sprintf "<td style=\"text-align: left; padding-left: 4px; padding-right: 6px;\" class=\"%s\">%s</td>", $class, $td;
    }
    $text .= "</tr>";
  }
  $text .= "</table>";
  return $text;
}

sub load_my_extension {
  my ($self) = @_;
  if ($self->opts->mode =~ /^my-([^-.]+)/) {
    my $class = $1;
    my $loaderror = undef;
    substr($class, 0, 1) = uc substr($class, 0, 1);
    if (! $self->opts->get("with-mymodules-dyn-dir")) {
      $self->override_opt("with-mymodules-dyn-dir", "");
    }
    my $plugin_name = $Monitoring::GLPlugin::pluginname;
    $plugin_name =~ /check_(.*?)_health/;
    my $deprecated_class = "DBD::".(uc $1)."::Server";
    $plugin_name = "Check".uc(substr($1, 0, 1)).substr($1, 1)."Health";
    foreach my $libpath (split(":", $self->opts->get("with-mymodules-dyn-dir"))) {
      foreach my $extmod (glob $libpath."/".$plugin_name."*.pm") {
        my $stderrvar;
        *SAVEERR = *STDERR;
        open OUT ,'>',\$stderrvar;
        *STDERR = *OUT;
        eval {
          $self->debug(sprintf "loading module %s", $extmod);
          require $extmod;
        };
        *STDERR = *SAVEERR;
        if ($@) {
          $loaderror = $extmod;
          $self->debug(sprintf "failed loading module %s: %s", $extmod, $@);
        }
      }
    }
    my $original_class = ref($self);
    my $original_init = $self->can("init");
    $self->compatibility_class() if $self->can('compatibility_class');
    bless $self, "My$class";
    $self->compatibility_methods() if $self->can('compatibility_methods') &&
        $self->isa($deprecated_class);
    if ($self->isa("Monitoring::GLPlugin")) {
      my $new_init = $self->can("init");
      if ($new_init == $original_init) {
          $self->add_unknown(
              sprintf "Class %s needs an init() method", ref($self));
      } else {
        # now go back to check_*_health.pl where init() will be called
      }
    } else {
      bless $self, $original_class;
      $self->add_unknown(
          sprintf "Class %s is not a subclass of Monitoring::GLPlugin%s",
              "My$class",
              $loaderror ? sprintf " (syntax error in %s?)", $loaderror : "" );
      my ($code, $message) = $self->check_messages(join => ', ', join_all => ', ');
      $self->nagios_exit($code, $message);
    }
  }
}

sub number_of_bits {
  my ($self, $unit) = @_;
  # https://en.wikipedia.org/wiki/Data_rate_units
  my $bits = {
    'bit' => 1,			# Bit per second
    'B' => 8,			# Byte per second, 8 bits per second
    'kbit' => 1000,		# Kilobit per second, 1,000 bits per second
    'kb' => 1000,		# Kilobit per second, 1,000 bits per second
    'Kibit' => 1024,		# Kibibit per second, 1,024 bits per second
    'kB' => 8000,		# Kilobyte per second, 8,000 bits per second
    'KiB' => 8192,		# Kibibyte per second, 1,024 bytes per second
    'Mbit' => 1000000,		# Megabit per second, 1,000,000 bits per second
    'Mb' => 1000000,		# Megabit per second, 1,000,000 bits per second
    'Mibit' => 1048576,		# Mebibit per second, 1,024 kibibits per second
    'MB' => 8000000,		# Megabyte per second, 1,000 kilobytes per second
    'MiB' => 8388608,		# Mebibyte per second, 1,024 kibibytes per second
    'Gbit' => 1000000000,	# Gigabit per second, 1,000 megabits per second
    'Gb' => 1000000000,		# Gigabit per second, 1,000 megabits per second
    'Gibit' => 1073741824,	# Gibibit per second, 1,024 mebibits per second
    'GB' => 8000000000,		# Gigabyte per second, 1,000 megabytes per second
    'GiB' => 8589934592,	# Gibibyte per second, 8192 mebibits per second
    'Tbit' => 1000000000000,	# Terabit per second, 1,000 gigabits per second
    'Tb' => 1000000000000,	# Terabit per second, 1,000 gigabits per second
    'Tibit' => 1099511627776,	# Tebibit per second, 1,024 gibibits per second
    'TB' => 8000000000000,	# Terabyte per second, 1,000 gigabytes per second
    # eigene kreationen
    'Bits' => 1,
    'Bit' => 1,			# Bit per second
    'KB' => 1024,		# Kilobyte (like disk kilobyte)
    'KBi' => 1024,		# -"-
    'MBi' => 1024 * 1024,	# Megabyte (like disk megabyte)
    'GBi' => 1024 * 1024 * 1024, # Gigybate (like disk gigybyte)
  };
  if (exists $bits->{$unit}) {
    return $bits->{$unit};
  } else {
    return 0;
  }
}


#########################################################
# runtime methods
#
sub mode : lvalue {
  my ($self) = @_;
  $Monitoring::GLPlugin::mode;
}

sub statefilesdir {
  my ($self) = @_;
  return $Monitoring::GLPlugin::plugin->{statefilesdir};
}

sub opts { # die beiden _nicht_ in AUTOLOAD schieben, das kracht!
  my ($self) = @_;
  return $Monitoring::GLPlugin::plugin->opts();
}

sub getopts {
  my ($self, $envparams) = @_;
  $envparams ||= [];
  my $needs_restart = 0;
  my @restart_opts = ();
  $Monitoring::GLPlugin::plugin->getopts();
  # es kann sein, dass beim aufraeumen zum schluss als erstes objekt
  # das $Monitoring::GLPlugin::plugin geloescht wird. in anderen destruktoren
  # (insb. fuer dbi disconnect) steht dann $self->opts->verbose
  # nicht mehr zur verfuegung bzw. $Monitoring::GLPlugin::plugin->opts ist undef.
  $self->set_variable("verbose", $self->opts->verbose);
  $Monitoring::GLPlugin::tracefile = $self->opts->tracefile ?
      $self->opts->tracefile :
      $self->system_tmpdir()."/".$Monitoring::GLPlugin::pluginname.".trace";
  if (! -f $Monitoring::GLPlugin::tracefile) {
    $Monitoring::GLPlugin::tracefile = undef;
  }
  #
  # die gueltigkeit von modes wird bereits hier geprueft und nicht danach
  # in validate_args. (zwischen getopts und validate_args wird
  # normalerweise classify aufgerufen, welches bereits eine verbindung
  # zum endgeraet herstellt. bei falschem mode waere das eine verschwendung
  # bzw. durch den exit3 ein evt. unsauberes beenden der verbindung.
  if ((! grep { $self->opts->mode eq $_ } map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->{modes}}) &&
      (! grep { $self->opts->mode eq $_ } map { defined $_->{alias} ? @{$_->{alias}} : () } @{$Monitoring::GLPlugin::plugin->{modes}})) {
    if ($self->opts->mode !~ /^my-/) {
      printf "UNKNOWN - mode %s\n", $self->opts->mode;
      $self->opts->print_help();
      exit 3;
    }
  }
  if ($self->opts->environment) {
    # wenn die gewuenschten Environmentvariablen sich von den derzeit
    # gesetzten unterscheiden, dann restart. Denn $ENV aendert
    # _nicht_ das Environment des laufenden Prozesses. 
    # $ENV{ZEUGS} = 1 bedeutet lediglich, dass $ENV{ZEUGS} bei weiterer
    # Verwendung 1 ist, bedeutet aber _nicht_, dass diese Variable 
    # im Environment des laufenden Prozesses existiert.
    foreach (keys %{$self->opts->environment}) {
      if ((! $ENV{$_}) || ($ENV{$_} ne $self->opts->environment->{$_})) {
        $needs_restart = 1;
        $ENV{$_} = $self->opts->environment->{$_};
        $self->debug(sprintf "new %s=%s forces restart\n", $_, $ENV{$_});
      }
    }
  }
  if ($self->opts->runas) {
    # exec sudo $0 ... und dann ohne --runas
    $needs_restart = 1;
    # wenn wir environmentvariablen haben, die laut survive_sudo_env als
    # wichtig erachtet werden, dann muessen wir die ueber einen moeglichen
    # sudo-aufruf rueberretten, also in zusaetzliche --environment umwandenln.
    # sudo putzt das Environment naemlich aus.
    foreach my $survive_env (@{$Monitoring::GLPlugin::survive_sudo_env}) {
      if ($ENV{$survive_env} && ! scalar(grep { /^$survive_env=/ }
          keys %{$self->opts->environment})) {
        $self->opts->environment->{$survive_env} = $ENV{$survive_env};
        printf STDERR "add important --environment %s=%s\n",
            $survive_env, $ENV{$survive_env} if $self->opts->verbose >= 2;
        push(@restart_opts, '--environment');
        push(@restart_opts, sprintf '%s=%s',
            $survive_env, $ENV{$survive_env});
      }
    }
  }
  if ($needs_restart) {
    foreach my $option (keys %{$self->opts->all_my_opts}) {
      # der fliegt raus, sonst gehts gleich wieder in needs_restart rein
      next if $option eq "runas";
      foreach my $spec (map { $_->{spec} } @{$Monitoring::GLPlugin::plugin->opts->{_args}}) {
        if ($spec =~ /^(\w+)[\|\w+]*=(.*)/) {
          if ($1 eq $option && $2 =~ /s%/) {
            foreach (keys %{$self->opts->$option()}) {
              push(@restart_opts, sprintf "--%s", $option);
              push(@restart_opts, sprintf "%s=%s", $_, $self->opts->$option()->{$_});
            }
          } elsif ($1 eq $option) {
            push(@restart_opts, sprintf "--%s", $option);
            push(@restart_opts, sprintf "%s", $self->opts->$option());
          }
        } elsif ($spec eq $option) {
          push(@restart_opts, sprintf "--%s", $option);
        }
      }
    }
    if ($self->opts->runas && ($> == 0)) {
      # Ja, es gibt so Narrische, die gehen mit check_by_ssh als root
      # auf Datenbankmaschinen drauf und lassen dann dort check_oracle_health
      # laufen. Damit OPS$-Anmeldung dann funktioniert, wird mit --runas
      # auf eine andere Kennung umgeschwenkt. Diese Kennung gleich fuer
      # ssh zu verwenden geht aus Sicherheitsgruenden nicht. Narrische halt.
      exec "su", "-c", sprintf("%s %s", $0, join(" ", @restart_opts)), "-", $self->opts->runas;
    } elsif ($self->opts->runas) {
      exec "sudo", "-S", "-u", $self->opts->runas, $0, @restart_opts;
    } else {
      exec $0, @restart_opts;
      # dadurch werden SHLIB oder LD_LIBRARY_PATH sauber gesetzt, damit beim
      # erneuten Start libclntsh.so etc. gefunden werden.
    }
    exit;
  }
  if ($self->opts->shell) {
    # So komme ich bei den Narrischen zu einer root-Shell.
    system("/bin/sh");
  }
}


sub add_ok {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(OK, $message);
}

sub add_warning {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(WARNING, $message);
}

sub add_critical {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(CRITICAL, $message);
}

sub add_unknown {
  my ($self, $message) = @_;
  $message ||= $self->{info};
  $self->add_message(UNKNOWN, $message);
}

sub add_ok_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_ok($message);
  }
}

sub add_warning_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_warning($message);
  }
}

sub add_critical_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_critical($message);
  }
}

sub add_unknown_mitigation {
  my ($self, $message) = @_;
  if (defined $self->opts->mitigation()) {
    $self->add_message($self->opts->mitigation(), $message);
  } else {
    $self->add_unknown($message);
  }
}

sub add_message {
  my ($self, $level, $message) = @_;
  $message ||= $self->{info};
  $Monitoring::GLPlugin::plugin->add_message($level, $message)
      unless $self->is_blacklisted();
  if (exists $self->{failed}) {
    if ($level == UNKNOWN && $self->{failed} == OK) {
      $self->{failed} = $level;
    } elsif ($level > $self->{failed}) {
      $self->{failed} = $level;
    }
  }
}

sub clear_ok {
  my ($self) = @_;
  $self->clear_messages(OK);
}

sub clear_warning {
  my ($self) = @_;
  $self->clear_messages(WARNING);
}

sub clear_critical {
  my ($self) = @_;
  $self->clear_messages(CRITICAL);
}

sub clear_unknown {
  my ($self) = @_;
  $self->clear_messages(UNKNOWN);
}

sub clear_all { # deprecated, use clear_messages
  my ($self) = @_;
  $self->clear_ok();
  $self->clear_warning();
  $self->clear_critical();
  $self->clear_unknown();
}

sub set_level {
  my ($self, $code) = @_;
  $code = (qw(ok warning critical unknown))[$code] if $code =~ /^\d+$/;
  $code = lc $code;
  if (! exists $self->{tmp_level}) {
    $self->{tmp_level} = {
      ok => 0,
      warning => 0,
      critical => 0,
      unknown => 0,
    };
  }
  $self->{tmp_level}->{$code}++;
}

sub get_level {
  my ($self) = @_;
  return OK if ! exists $self->{tmp_level};
  my $code = OK;
  $code ||= CRITICAL if $self->{tmp_level}->{critical};
  $code ||= WARNING  if $self->{tmp_level}->{warning};
  $code ||= UNKNOWN  if $self->{tmp_level}->{unknown};
  return $code;
}

#########################################################
# blacklisting
#
sub blacklist {
  my ($self) = @_;
  $self->{blacklisted} = 1;
}

sub add_blacklist {
  my ($self, $list) = @_;
  $Monitoring::GLPlugin::blacklist = join('/',
      (split('/', $self->opts->blacklist), $list));
}

sub is_blacklisted {
  my ($self) = @_;
  if (! $self->opts->can("blacklist")) {
    return 0;
  }
  if (! exists $self->{blacklisted}) {
    $self->{blacklisted} = 0;
  }
  if (exists $self->{blacklisted} && $self->{blacklisted}) {
    return $self->{blacklisted};
  }
  # FAN:459,203/TEMP:102229/ENVSUBSYSTEM
  # FAN_459,FAN_203,TEMP_102229,ENVSUBSYSTEM
  if ($self->opts->blacklist =~ /_/) {
    foreach my $bl_item (split(/,/, $self->opts->blacklist)) {
      if ($bl_item eq $self->internal_name()) {
        $self->{blacklisted} = 1;
      }
    }
  } else {
    foreach my $bl_items (split(/\//, $self->opts->blacklist)) {
      if ($bl_items =~ /^(\w+):([\:\d\-\.,]+)$/) {
        my $bl_type = $1;
        my $bl_names = $2;
        foreach my $bl_name (split(/,/, $bl_names)) {
          if ($bl_type."_".$bl_name eq $self->internal_name()) {
            $self->{blacklisted} = 1;
          }
        }
      } elsif ($bl_items =~ /^(\w+)$/) {
        if ($bl_items eq $self->internal_name()) {
          $self->{blacklisted} = 1;
        }
      }
    }
  }
  return $self->{blacklisted};
}

#########################################################
# additional info
#
sub add_info {
  my ($self, $info) = @_;
  $info = $self->is_blacklisted() ? $info.' (blacklisted)' : $info;
  $self->{info} = $info;
  push(@{$Monitoring::GLPlugin::info}, $info);
}

sub annotate_info {
  my ($self, $annotation) = @_;
  my $lastinfo = pop(@{$Monitoring::GLPlugin::info});
  $lastinfo .= sprintf ' (%s)', $annotation;
  $self->{info} = $lastinfo;
  push(@{$Monitoring::GLPlugin::info}, $lastinfo);
}

sub add_extendedinfo {  # deprecated
  my ($self, $info) = @_;
  $self->{extendedinfo} = $info;
  return if ! $self->opts->extendedinfo;
  push(@{$Monitoring::GLPlugin::extendedinfo}, $info);
}

sub get_info {
  my ($self, $separator) = @_;
  $separator ||= ' ';
  return join($separator , @{$Monitoring::GLPlugin::info});
}

sub get_last_info {
  my ($self) = @_;
  return pop(@{$Monitoring::GLPlugin::info});
}

sub get_extendedinfo {
  my ($self, $separator) = @_;
  $separator ||= ' ';
  return join($separator, @{$Monitoring::GLPlugin::extendedinfo});
}

sub add_summary {  # deprecated
  my ($self, $summary) = @_;
  push(@{$Monitoring::GLPlugin::summary}, $summary);
}

sub get_summary {
  my ($self) = @_;
  return join(', ', @{$Monitoring::GLPlugin::summary});
}

#########################################################
# persistency
#
sub valdiff {
  my ($self, $pparams, @keys) = @_;
  my %params = %{$pparams};
  my $now = time;
  my $newest_history_set = {};
  $params{freeze} = 0 if ! $params{freeze};
  my $mode = "normal";
  if ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 0) {
    $mode = "lookback_freeze_chill";
  } elsif ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 1) {
    $mode = "lookback_freeze_shockfrost";
  } elsif ($self->opts->lookback && $self->opts->lookback == 99999 && $params{freeze} == 2) {
    $mode = "lookback_freeze_defrost";
  } elsif ($self->opts->lookback) {
    $mode = "lookback";
  }
  # lookback=99999, freeze=0(default)
  #  nimm den letzten lauf und schreib ihn nach {cold}
  #  vergleich dann
  #    wenn es frozen gibt, vergleich frozen und den letzten lauf
  #    sonst den letzten lauf und den aktuellen lauf
  # lookback=99999, freeze=1
  #  wird dann aufgerufen,wenn nach dem freeze=0 ein problem festgestellt wurde
  #     (also als 2.valdiff hinterher)
  #  schreib cold nach frozen
  # lookback=99999, freeze=2
  #  wird dann aufgerufen,wenn nach dem freeze=0 wieder alles ok ist
  #     (also als 2.valdiff hinterher)
  #  loescht frozen
  #
  my $last_values = $self->load_state(%params) || eval {
    my $empty_events = {};
    foreach (@keys) {
      if (ref($self->{$_}) eq "ARRAY") {
        $empty_events->{$_} = [];
      } else {
        $empty_events->{$_} = 0;
      }
    }
    $empty_events->{timestamp} = 0;
    if ($mode eq "lookback") {
      $empty_events->{lookback_history} = {};
    } elsif ($mode eq "lookback_freeze_chill") {
      $empty_events->{cold} = {};
      $empty_events->{frozen} = {};
    }
    $empty_events;
  };
  $self->{'delta_timestamp'} = $now - $last_values->{timestamp};
  foreach (@keys) {
    if ($mode eq "lookback_freeze_chill") {
      # die werte vom letzten lauf wegsichern.
      # vielleicht gibts gleich einen freeze=1, dann muessen die eingefroren werden
      if (exists $last_values->{$_}) {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{cold}->{$_} = [];
          foreach my $value (@{$last_values->{$_}}) {
            push(@{$last_values->{cold}->{$_}}, $value);
          }
        } else {
          $last_values->{cold}->{$_} = $last_values->{$_};
        }
      } else {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{cold}->{$_} = [];
        } else {
          $last_values->{cold}->{$_} = 0;
        }
      }
      # es wird so getan, als sei der frozen wert vom letzten lauf
      if (exists $last_values->{frozen}->{$_}) {
        if (ref($self->{$_}) eq "ARRAY") {
          $last_values->{$_} = [];
          foreach my $value (@{$last_values->{frozen}->{$_}}) {
            push(@{$last_values->{$_}}, $value);
          }
        } else {
          $last_values->{$_} = $last_values->{frozen}->{$_};
        }
      }
    } elsif ($mode eq "lookback") {
      # find a last_value in the history which fits lookback best
      # and overwrite $last_values->{$_} with historic data
      if (exists $last_values->{lookback_history}->{$_}) {
        foreach my $date (sort {$a <=> $b} keys %{$last_values->{lookback_history}->{$_}}) {
            $newest_history_set->{$_} = $last_values->{lookback_history}->{$_}->{$date};
            $newest_history_set->{timestamp} = $date;
        }
        foreach my $date (sort {$a <=> $b} keys %{$last_values->{lookback_history}->{$_}}) {
          if ($date >= ($now - $self->opts->lookback)) {
            $last_values->{$_} = $last_values->{lookback_history}->{$_}->{$date};
            $last_values->{timestamp} = $date;
            $self->{'delta_timestamp'} = $now - $last_values->{timestamp};
            if (ref($last_values->{$_}) eq "ARRAY") {
              $self->debug(sprintf "oldest value of %s within lookback is size %s (age %d)",
                  $_, scalar(@{$last_values->{$_}}), $now - $date);
            } else {
              $self->debug(sprintf "oldest value of %s within lookback is %s (age %d)",
                  $_, $last_values->{$_}, $now - $date);
            }
            last;
          } else {
            $self->debug(sprintf "deprecate %s of age %d", $_, time - $date);
            delete $last_values->{lookback_history}->{$_}->{$date};
          }
        }
      }
    }
    if ($mode eq "normal" || $mode eq "lookback" || $mode eq "lookback_freeze_chill") {
      if (exists $self->{$_} && defined $self->{$_} && $self->{$_} =~ /^\d+\.*\d*$/) {
        # $VAR1 = { 'sysStatTmSleepCycles' => '',
        # no idea why this happens, but we can repair it.
        $last_values->{$_} = $self->{$_} if ! (exists $last_values->{$_} && defined $last_values->{$_} && $last_values->{$_} ne "");
        if ($self->{$_} >= $last_values->{$_}) {
          $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
        } elsif ($self->{$_} eq $last_values->{$_}) {
          # dawischt! in einem fall wurde 131071.999023438 >= 131071.999023438 da oben nicht erkannt
          # subtrahieren ging auch daneben, weil ein winziger negativer wert rauskam.
          $self->{'delta_'.$_} = 0;
        } else {
          if ($mode =~ /lookback_freeze/) {
            # hier koennen delta-werte auch negativ sein, wenn z.b. peers verschwinden
            $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
          } elsif (exists $params{lastarray}) {
            $self->{'delta_'.$_} = $self->{$_} - $last_values->{$_};
          } else {
            # vermutlich db restart und zaehler alle auf null
            $self->{'delta_'.$_} = $self->{$_};
          }
        }
        $self->debug(sprintf "delta_%s %f", $_, $self->{'delta_'.$_});
        $self->{$_.'_per_sec'} = $self->{'delta_timestamp'} ?
            $self->{'delta_'.$_} / $self->{'delta_timestamp'} : 0;
      } elsif (ref($self->{$_}) eq "ARRAY") {
        if ((! exists $last_values->{$_} || ! defined $last_values->{$_}) && exists $params{lastarray}) {
          # innerhalb der lookback-zeit wurde nichts in der lookback_history
          # gefunden. allenfalls irgendwas aelteres. normalerweise
          # wuerde jetzt das array als [] initialisiert.
          # d.h. es wuerde ein delta geben, @found s.u.
          # wenn man das nicht will, sondern einfach aktuelles array mit
          # dem array des letzten laufs vergleichen will, setzt man lastarray
          $last_values->{$_} = %{$newest_history_set} ?
              $newest_history_set->{$_} : []
        } elsif ((! exists $last_values->{$_} || ! defined $last_values->{$_}) && ! exists $params{lastarray}) {
          $last_values->{$_} = [] if ! exists $last_values->{$_};
        } elsif (exists $last_values->{$_} && ! defined $last_values->{$_}) {
          # $_ kann es auch ausserhalb des lookback_history-keys als normalen
          # key geben. der zeigt normalerweise auf den entspr. letzten
          # lookback_history eintrag. wurde der wegen ueberalterung abgeschnitten
          # ist der hier auch undef.
          $last_values->{$_} = %{$newest_history_set} ?
              $newest_history_set->{$_} : []
        }
        my %saved = map { $_ => 1 } @{$last_values->{$_}};
        my %current = map { $_ => 1 } @{$self->{$_}};
        my @found = grep(!defined $saved{$_}, @{$self->{$_}});
        my @lost = grep(!defined $current{$_}, @{$last_values->{$_}});
        $self->{'delta_found_'.$_} = \@found;
        $self->{'delta_lost_'.$_} = \@lost;
      } else {
        # nicht ganz sauber, aber das artet aus, wenn man jedem uninitialized hinterherstochert.
        # wem das nicht passt, der kann gerne ein paar tage debugging beauftragen.
        # das kostet aber mehr als drei kugeln eis.
        $last_values->{$_} = 0 if ! (exists $last_values->{$_} && defined $last_values->{$_} && $last_values->{$_} ne "");
        $self->{$_} = 0 if ! (exists $self->{$_} && defined $self->{$_} && $self->{$_} ne "");
        $self->{'delta_'.$_} = 0;
      }
    }
  }
  $params{save} = eval {
    my $empty_events = {};
    foreach (@keys) {
      $empty_events->{$_} = $self->{$_};
      if ($mode =~ /lookback_freeze/) {
        if (exists $last_values->{frozen}->{$_}) {
          if (ref($last_values->{frozen}->{$_}) eq "ARRAY") {
            @{$empty_events->{cold}->{$_}} = @{$last_values->{frozen}->{$_}};
          } else {
            $empty_events->{cold}->{$_} = $last_values->{frozen}->{$_};
          }
        } else {
          if (ref($last_values->{cold}->{$_}) eq "ARRAY") {
            @{$empty_events->{cold}->{$_}} = @{$last_values->{cold}->{$_}};
          } else {
            $empty_events->{cold}->{$_} = $last_values->{cold}->{$_};
          }
        }
        $empty_events->{cold}->{timestamp} = $last_values->{cold}->{timestamp};
      }
      if ($mode eq "lookback_freeze_shockfrost") {
        if (ref($empty_events->{cold}->{$_}) eq "ARRAY") {
          @{$empty_events->{frozen}->{$_}} = @{$empty_events->{cold}->{$_}};
        } else {
          $empty_events->{frozen}->{$_} = $empty_events->{cold}->{$_};
        }
        $empty_events->{frozen}->{timestamp} = $now;
      }
    }
    $empty_events->{timestamp} = $now;
    if ($mode eq "lookback") {
      $empty_events->{lookback_history} = $last_values->{lookback_history};
      foreach (@keys) {
        if (ref($self->{$_}) eq "ARRAY") {
          @{$empty_events->{lookback_history}->{$_}->{$now}} = @{$self->{$_}};
        } else {
          $empty_events->{lookback_history}->{$_}->{$now} = $self->{$_};
        }
      }
    }
    if ($mode eq "lookback_freeze_defrost") {
      delete $empty_events->{freeze};
    }
    $empty_events;
  };
  $self->save_state(%params);
}

sub create_statefilesdir {
  my ($self) = @_;
  if (! -d $self->statefilesdir()) {
    eval {
      use File::Path;
      mkpath $self->statefilesdir();
    };
    if ($@ || ! -w $self->statefilesdir()) {
      $self->add_message(UNKNOWN,
        sprintf "cannot create status dir %s! check your filesystem (permissions/usage/integrity) and disk devices", $self->statefilesdir());
    }
  } elsif (! -w $self->statefilesdir()) {
    $self->add_message(UNKNOWN,
        sprintf "cannot write status dir %s! check your filesystem (permissions/usage/integrity) and disk devices", $self->statefilesdir());
  }
}

sub create_statefile {
  my ($self, %params) = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s%s", $self->statefilesdir(),
      $self->clean_path($self->mode), $self->clean_path(lc $extension);
}

sub clean_path {
  my ($self, $path) = @_;
  if ($^O =~ /MSWin/) {
    $path =~ s/:/_/g;
  }
  return $path;
}

sub schimpf {
  my ($self) = @_;
  printf "statefilesdir %s is not writable.\nYou didn't run this plugin as root, didn't you?\n", $self->statefilesdir();
}

# $self->protect_value('1.1-flat_index', 'cpu_busy', 'percent');
sub protect_value {
  my ($self, $ident, $key, $validfunc) = @_;
  if (ref($validfunc) ne "CODE" && $validfunc eq "percent") {
    $validfunc = sub {
      my $value = shift;
      return 0 if ! defined $value;
      return 0 if $value !~ /^[-+]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$/;
      return ($value < 0 || $value > 100) ? 0 : 1;
    };
  } elsif (ref($validfunc) ne "CODE" && $validfunc eq "positive") {
    $validfunc = sub {
      my $value = shift;
      return 0 if ! defined $value;
      return 0 if $value !~ /^[-+]?([0-9]+(\.[0-9]+)?|\.[0-9]+)$/;
      return ($value < 0) ? 0 : 1;
    };
  }
  if (&$validfunc($self->{$key})) {
    $self->save_state(name => 'protect_'.$ident.'_'.$key, save => {
        $key => $self->{$key},
        exception => 0,
    });
  } else {
    # if the device gives us an clearly wrong value, simply use the last value.
    my $laststate = $self->load_state(name => 'protect_'.$ident.'_'.$key);
    $self->debug(sprintf "self->{%s} is %s and invalid for the %dth time",
        $key, $self->{$key}, $laststate->{exception} + 1);
    if ($laststate->{exception} <= 5) {
      # but only 5 times.
      # if the error persists, somebody has to check the device.
      $self->{$key} = $laststate->{$key};
    }
    $self->save_state(name => 'protect_'.$ident.'_'.$key, save => {
        $key => $laststate->{$key},
        exception => ++$laststate->{exception},
    });
  }
}

sub save_state {
  my ($self, %params) = @_;
  $self->create_statefilesdir();
  my $statefile = $self->create_statefile(%params);
  my $tmpfile = $self->statefilesdir().'/check__health_tmp_'.$$;
  if ((ref($params{save}) eq "HASH") && exists $params{save}->{timestamp}) {
    $params{save}->{localtime} = scalar localtime $params{save}->{timestamp};
  }
  my $seekfh = IO::File->new();
  if ($seekfh->open($tmpfile, "w")) {
    $seekfh->printf("%s", Data::Dumper::Dumper($params{save}));
    $seekfh->flush();
    $seekfh->close();
    $self->debug(sprintf "saved %s to %s",
        Data::Dumper::Dumper($params{save}), $statefile);
  }
  if (! rename $tmpfile, $statefile) {
    $self->add_message(UNKNOWN,
        sprintf "cannot write status file %s! check your filesystem (permissions/usage/integrity) and disk devices", $statefile);
  }
}

sub load_state {
  my ($self, %params) = @_;
  my $statefile = $self->create_statefile(%params);
  if ( -f $statefile) {
    our $VAR1;
    eval {
      delete $INC{$statefile} if exists $INC{$statefile}; # else unit tests fail
      require $statefile;
    };
    if($@) {
      printf "FATAL: Could not load state!\n";
    }
    $self->debug(sprintf "load %s from %s", Data::Dumper::Dumper($VAR1), $statefile);
    return $VAR1;
  } else {
    return undef;
  }
}

#########################################################
# daemon mode
#
sub check_pidfile {
  my ($self) = @_;
  my $fh = IO::File->new();
  if ($fh->open($self->{pidfile}, "r")) {
    my $pid = $fh->getline();
    $fh->close();
    if (! $pid) {
      $self->debug("Found pidfile %s with no valid pid. Exiting.",
          $self->{pidfile});
      return 0;
    } else {
      $self->debug("Found pidfile %s with pid %d", $self->{pidfile}, $pid);
      kill 0, $pid;
      if ($! == Errno::ESRCH) {
        $self->debug("This pidfile is stale. Writing a new one");
        $self->write_pidfile();
        return 1;
      } else {
        $self->debug("This pidfile is held by a running process. Exiting");
        return 0;
      }
    }
  } else {
    $self->debug("Found no pidfile. Writing a new one");
    $self->write_pidfile();
    return 1;
  }
}

sub write_pidfile {
  my ($self) = @_;
  if (! -d dirname($self->{pidfile})) {
    eval "require File::Path;";
    if (defined(&File::Path::mkpath)) {
      import File::Path;
      eval { mkpath(dirname($self->{pidfile})); };
    } else {
      my @dirs = ();
      map {
          push @dirs, $_;
          mkdir(join('/', @dirs))
              if join('/', @dirs) && ! -d join('/', @dirs);
      } split(/\//, dirname($self->{pidfile}));
    }
  }
  my $fh = IO::File->new();
  $fh->autoflush(1);
  if ($fh->open($self->{pidfile}, "w")) {
    $fh->printf("%s", $$);
    $fh->close();
  } else {
    $self->debug("Could not write pidfile %s", $self->{pidfile});
    die "pid file could not be written";
  }
}

sub system_vartmpdir {
  my ($self) = @_;
  if ($^O =~ /MSWin/) {
    return $self->system_tmpdir();
  } else {
    return "/var/tmp/".$Monitoring::GLPlugin::pluginname;
  }
}

sub system_tmpdir {
  my ($self) = @_;
  if ($^O =~ /MSWin/) {
    return $ENV{TEMP} if defined $ENV{TEMP};
    return $ENV{TMP} if defined $ENV{TMP};
    return File::Spec->catfile($ENV{windir}, 'Temp')
        if defined $ENV{windir};
    return 'C:\Temp';
  } else {
    return "/tmp";
  }
}

sub convert_scientific_numbers {
  my ($self, $n) = @_;
  # mostly used to convert numbers in scientific notation
  if ($n =~ /^\s*\d+\s*$/) {
    return $n;
  } elsif ($n =~ /^\s*([-+]?)(\d*[\.,]*\d*)[eE]{1}([-+]?)(\d+)\s*$/) {
    my ($vor, $num, $sign, $exp) = ($1, $2, $3, $4);
    $n =~ s/E/e/g;
    $n =~ s/,/\./g;
    $num =~ s/,/\./g;
    my $sig = $sign eq '-' ? "." . ($exp - 1 + length $num) : '';
    my $dec = sprintf "%${sig}f", $n;
    $dec =~ s/\.[0]+$//g;
    return $dec;
  } elsif ($n =~ /^\s*([-+]?)(\d+)[\.,]*(\d*)\s*$/) {
    return $1.$2.".".$3;
  } elsif ($n =~ /^\s*(.*?)\s*$/) {
    return $1;
  } else {
    return $n;
  }
}

sub compatibility_methods {
  my ($self) = @_;
  # add_perfdata
  # add_message
  # nagios_exit
  # ->{warningrange}
  # ->{criticalrange}
  # ...
  $self->{warningrange} = ($self->get_thresholds())[0];
  $self->{criticalrange} = ($self->get_thresholds())[1];
  my $old_init = $self->can('init');
  my %params = (
    'mode' => join('::', split(/-/, $self->opts->mode)),
    'name' => $self->opts->name,
    'name2' => $self->opts->name2,
  );
  {
    no strict 'refs';
    no warnings 'redefine';
    *{ref($self).'::init'} = sub {
      $self->$old_init(%params);
      $self->nagios(%params);
    };
    *{ref($self).'::add_nagios'} = \&{"Monitoring::GLPlugin::add_message"};
    *{ref($self).'::add_nagios_ok'} = \&{"Monitoring::GLPlugin::add_ok"};
    *{ref($self).'::add_nagios_warning'} = \&{"Monitoring::GLPlugin::add_warning"};
    *{ref($self).'::add_nagios_critical'} = \&{"Monitoring::GLPlugin::add_critical"};
    *{ref($self).'::add_nagios_unknown'} = \&{"Monitoring::GLPlugin::add_unknown"};
    *{ref($self).'::add_perfdata'} = sub {
      my $self = shift;
      my $message = shift;
      foreach my $perfdata (split(/\s+/, $message)) {
      my ($label, $perfstr) = split(/=/, $perfdata);
      my ($value, $warn, $crit, $min, $max) = split(/;/, $perfstr);
      $value =~ /^([\d\.\-\+]+)(.*)$/;
      $value = $1;
      my $uom = $2;
      $Monitoring::GLPlugin::plugin->add_perfdata(
        label => $label,
        value => $value,
        uom => $uom,
        warn => $warn,
        crit => $crit,
        min => $min,
        max => $max,
      );
      }
    };
    *{ref($self).'::check_thresholds'} = sub {
      my $self = shift;
      my $value = shift;
      my $defaultwarningrange = shift;
      my $defaultcriticalrange = shift;
      $Monitoring::GLPlugin::plugin->set_thresholds(
          metric => 'default',
          warning => $defaultwarningrange,
          critical => $defaultcriticalrange,
      );
      $self->{warningrange} = ($self->get_thresholds())[0];
      $self->{criticalrange} = ($self->get_thresholds())[1];
      return $Monitoring::GLPlugin::plugin->check_thresholds(
          metric => 'default',
          value => $value,
          warning => $defaultwarningrange,
          critical => $defaultcriticalrange,
      );
    };
  }
}

sub AUTOLOAD {
  my ($self, @params) = @_;
  return if ($AUTOLOAD =~ /DESTROY/);
  $self->debug("AUTOLOAD %s\n", $AUTOLOAD)
        if $self->opts->verbose >= 2;
  if ($AUTOLOAD =~ /^(.*)::analyze_and_check_(.*)_subsystem$/) {
    my $class = $1;
    my $subsystem = $2;
    my $analyze = sprintf "analyze_%s_subsystem", $subsystem;
    my $check = sprintf "check_%s_subsystem", $subsystem;
    if (@params) {
      # analyzer class
      my $subsystem_class = shift @params;
      $self->{components}->{$subsystem.'_subsystem'} = $subsystem_class->new();
      $self->debug(sprintf "\$self->{components}->{%s_subsystem} = %s->new()",
          $subsystem, $subsystem_class);
    } else {
      $self->$analyze();
      $self->debug("call %s()", $analyze);
    }
    $self->$check();
  } elsif ($AUTOLOAD =~ /^(.*)::check_(.*)_subsystem$/) {
    my $class = $1;
    my $subsystem = sprintf "%s_subsystem", $2;
    $self->{components}->{$subsystem}->check();
    $self->{components}->{$subsystem}->dump()
        if $self->opts->verbose >= 2;
  } elsif ($AUTOLOAD =~ /^.*::(status_code|check_messages|nagios_exit|html_string|perfdata_string|selected_perfdata|check_thresholds|get_thresholds|opts|pandora_string|strequal)$/) {
    return $Monitoring::GLPlugin::plugin->$1(@params);
  } elsif ($AUTOLOAD =~ /^.*::(reduce_messages|reduce_messages_short|clear_messages|suppress_messages|add_html|add_perfdata|override_opt|create_opt|set_thresholds|force_thresholds|add_pandora)$/) {
    $Monitoring::GLPlugin::plugin->$1(@params);
  } elsif ($AUTOLOAD =~ /^.*::mod_arg_(.*)$/) {
    return $Monitoring::GLPlugin::plugin->mod_arg($1, @params);
  } else {
    $self->debug("AUTOLOAD: class %s has no method %s\n",
        ref($self), $AUTOLOAD);
  }
}



package Monitoring::GLPlugin::Item;
our @ISA = qw(Monitoring::GLPlugin);

use strict;

sub new {
  my ($class, %params) = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub check {
  my ($self, $lists) = @_;
  my @lists = $lists ? @{$lists} : grep { ref($self->{$_}) eq "ARRAY" } keys %{$self};
  foreach my $list (@lists) {
    $self->add_info('checking '.$list);
    foreach my $element (@{$self->{$list}}) {
      $element->blacklist() if $self->is_blacklisted();
      $element->check();
    }
  }
}



package Monitoring::GLPlugin::TableItem;
our @ISA = qw(Monitoring::GLPlugin::Item);

use strict;

sub new {
  my ($class, %params) = @_;
  my $self = {};
  bless $self, $class;
  foreach (keys %params) {
    $self->{$_} = $params{$_};
  }
  if ($self->can("finish")) {
    $self->finish(%params);
  }
  return $self;
}

sub check {
  my ($self) = @_;
  # some tableitems are not checkable, they are only used to enhance other
  # items (e.g. sensorthresholds enhance sensors)
  # normal tableitems should have their own check-method
}



package Monitoring::GLPlugin::DB;
our @ISA = qw(Monitoring::GLPlugin);
use strict;
use File::Basename qw(basename dirname);
use File::Temp qw(tempfile);

{
  our $session = undef;
  our $fetchall_array_cache = {};
}

sub new {
  my ($class, %params) = @_;
  require Monitoring::GLPlugin
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::;
  require Monitoring::GLPlugin::DB::CSF
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::DB::CSF::;
  require Monitoring::GLPlugin::DB::DBI
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::DB::DBI::;
  require Monitoring::GLPlugin::DB::Item
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::DB::Item::;
  require Monitoring::GLPlugin::DB::TableItem
      if ! grep /BEGIN/, keys %Monitoring::GLPlugin::DB::TableItem::;
  my $self = Monitoring::GLPlugin->new(%params);
  bless $self, $class;
  return $self;
}

sub add_db_modes {
  my ($self) = @_;
  $self->add_mode(
      internal => 'server::connectiontime',
      spec => 'connection-time',
      alias => undef,
      help => 'Time to connect to the server',
  );
  $self->add_mode(
      internal => 'server::sql',
      spec => 'sql',
      alias => undef,
      help => 'any sql command returning a single number',
  );
  $self->add_mode(
      internal => 'server::sqlruntime',
      spec => 'sql-runtime',
      alias => undef,
      help => 'the time an sql command needs to run',
  );
  $self->add_mode(
      internal => 'internal::encode',
      spec => 'encode',
      alias => undef,
      help => 'url-encodes stdin',
  );
}

sub add_db_args {
  my ($self) = @_;
  $self->add_arg(
      spec => 'dbthresholds:s',
      help => '--dbthresholds
   Read thresholds from a database table',
      required => 0,
      env => 'DBTHRESHOLDS',
  );
  $self->add_arg(
      spec => 'notemp',
      help => '--notemp
   Ignore temporary databases/tablespaces',
      required => 0,
  );
  $self->add_arg(
      spec => 'commit',
      help => '--commit
   turns on autocommit for the dbd::* module',
      default => 0,
      required => 0,
  );
  $self->add_arg(
      spec => 'method:s',
      help => '--method
   how to connect to the database, perl-dbi or calling a command line client.
   Default is "dbi", which requires the installation of a suitable perl-module.',
      default => 'dbi',
      required => 0,
  );
}

sub get_db_tables {
#  $self->get_db_tables([
#    ['databases', 'select * from', 'Classes::POSTGRES::Component::DatabaseSubsystem::Database']
#  ]);
  my ($self, $infos) = @_;
  foreach my $info (@{$infos}) {
    my $arrayname = $info->[0];
    my $sql = $info->[1];
    my $class = $info->[2];
    my $filter = $info->[3];
    my $mapping = $info->[4];
    my $args = $info->[5];
    $self->{$arrayname} = [] if ! exists $self->{$arrayname};
    my $max_idx = scalar(@{$mapping});;
    foreach my $row ($self->fetchall_array($sql, @{$args})) {
      my $col_idx = -1;
      my $params = {};
      while ($col_idx < $max_idx) {
        $params->{$mapping->[$col_idx]} = $row->[$col_idx];
        $col_idx++;
      }
      my $new_object = $class->new(%{$params});
      next if (defined $filter && ! &$filter($new_object));
      push(@{$self->{$arrayname}}, $new_object);
    }
  }
}

sub validate_args {
  my ($self) = @_;
  $self->SUPER::validate_args();
  if ($self->opts->name && $self->opts->name =~ /(select|exec)%20/i) {
    my $name = $self->opts->name;
    $name =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    $self->override_opt('name', $name);
  }
}

sub no_such_mode {
  my ($self) = @_;
  if (ref($self) eq "Classes::Device") {
    $self->add_unknown('the device is no known type of database server');
  } else {
    bless $self, "Monitoring::GLPlugin::DB";
    $self->init();
  }
  if (ref($self) eq "Monitoring::GLPlugin") {
    printf "Mode %s is not implemented for this type of device\n",
        $self->opts->mode;
    exit 3;
  }
}

sub init {
  my ($self) = @_;
  if ($self->mode =~ /^server::connectiontime/) {
    my $connection_time = $self->{tac} - $self->{tic};
    $self->set_thresholds(warning => 1, critical => 5);
    $self->add_message($self->check_thresholds($connection_time),
         sprintf "%.2f seconds to connect as %s",
              $connection_time, $self->opts->username,);
    $self->add_perfdata(
        label => 'connection_time',
        value => $connection_time,
    );
  } elsif ($self->mode =~ /^server::sqlruntime/) {
    my $tic = Time::HiRes::time();
    my @genericsql = $self->fetchrow_array($self->opts->name);
    my $runtime = Time::HiRes::time() - $tic;
    # normally, sql errors and stderr result in CRITICAL or WARNING
    # we can clear these errors if we are only interested in the runtime
    $self->clear_all() if $self->check_messages() &&
        defined $self->opts->mitigation && $self->opts->mitigation == 0;
    $self->set_thresholds(warning => 1, critical => 5);
    $self->add_message($self->check_thresholds($runtime),
        sprintf "%.2f seconds to execute %s",
            $runtime,
            $self->opts->name2 ? $self->opts->name2 : $self->opts->name);
    $self->add_perfdata(
        label => "sql_runtime",
        value => $runtime,
        uom => "s",
    );
  } elsif ($self->mode =~ /^server::sql/) {
    if ($self->opts->regexp) {
      # sql output is treated as text
      my $pattern = $self->opts->name2;
      #if ($self->opts->name2 eq $self->opts->name) {
      my $genericsql = $self->fetchrow_array($self->opts->name);
      if (! defined $genericsql) {
        $self->add_unknown(sprintf "got no valid response for %s",
            $self->opts->name);
      } else {
        if (substr($pattern, 0, 1) eq '!') {
          $pattern =~ s/^!//;
          if ($genericsql !~ /$pattern/) {
            $self->add_ok(
                sprintf "output %s does not match pattern %s",
                    $genericsql, $pattern);
          } else {
            $self->add_critical(
                sprintf "output %s matches pattern %s",
                    $genericsql, $pattern);
          }
        } else {
          if ($genericsql =~ /$pattern/) {
            $self->add_ok(
                sprintf "output %s matches pattern %s",
                    $genericsql, $pattern);
          } else {
            $self->add_critical(
                sprintf "output %s does not match pattern %s",
                    $genericsql, $pattern);
          }
        }
      }
    } else {
      # sql output must be a number (or array of numbers)
      my @genericsql = $self->fetchrow_array($self->opts->name);
      #$self->create_opt("name2") if ! $self->opts->name2
      $self->override_opt("name2", $self->opts->name) if ! $self->opts->name2;
      if (! @genericsql) {
          #(scalar(grep { /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/ } @{$self->{genericsql}})) ==
          #scalar(@{$self->{genericsql}}))) {
        $self->add_unknown(sprintf "got no valid response for %s",
            $self->opts->name);
      } else {
        # name2 in array
        # units in array

        $self->set_thresholds(warning => 1, critical => 5);
        $self->add_message(
          # the first item in the list will trigger the threshold values
            $self->check_thresholds($genericsql[0]),
                sprintf "%s: %s%s",
                $self->opts->name2 ? lc $self->opts->name2 : lc $self->opts->name,
              # float as float, integers as integers
                join(" ", map {
                    (sprintf("%d", $_) eq $_) ? $_ : sprintf("%f", $_)
                } @genericsql),
                $self->opts->units ? $self->opts->units : "");
        my $i = 0;
        # workaround... getting the column names from the database would be nicer
        my @names2_arr = split(/\s+/, $self->opts->name2);
        foreach my $t (@genericsql) {
          $self->add_perfdata(
              label => $names2_arr[$i] ? lc $names2_arr[$i] : lc $self->opts->name,
              value => (sprintf("%d", $t) eq $t) ? $t : sprintf("%f", $t),
              uom => $self->opts->units ? $self->opts->units : "",
          );
          $i++;
        }
      }
    }
  } else {
    bless $self, "Monitoring::GLPlugin"; # see above: no_such_mode
  }
}

sub compatibility_methods {
  my ($self) = @_;
  $self->{handle} = $self;
  $self->SUPER::compatibility_methods() if $self->SUPER::can('compatibility_methods');
}

sub has_threshold_table {
  my ($self) = @_;
  # has to be implemented in each database driver class
  return 0;
}

sub set_thresholds {
  my ($self, %params) = @_;
  $self->SUPER::set_thresholds(%params);
  if (defined $self->opts->dbthresholds && $self->has_threshold_table()) {
    #
    my @dbthresholds = $self->fetchall_array(
        sprintf "SELECT * FROM %s WHERE mode = '%s'",
            $self->{has_threshold_table}, $self->opts->mode
    );
    if (@dbthresholds) {
      # | mode | =metric | warning | critical |
      # | mode | =dbthresholds | warning | critical |
      # | mode | =name2 | warning | critical |
      # | mode | =name | warning | critical |
      # | mode | NULL | warning | critical |
      my %newparams = ();
      my @metricmatches = grep { $params{metric} eq $_->[1] }
          grep { defined $_->[1] }
          grep { exists $params{metric} } @dbthresholds;
      my @dbtmatches = grep { $self->opts->dbthresholds eq $_->[1] }
          grep { defined $_->[1] }
          grep { $self->opts->dbthresholds ne '1' } @dbthresholds;
      my @name2matches = grep { $self->opts->name2 eq $_->[1] }
          grep { defined $_->[1] }
          grep { $self->opts->name2 } @dbthresholds;
      my @namematches = grep { $self->opts->name eq $_->[1] }
          grep { defined $_->[1] }
          grep { $self->opts->name } @dbthresholds;
      my @modematches = grep { ! defined $_->[1] } @dbthresholds;
      if (@metricmatches) {
        $newparams{warning} = $metricmatches[0]->[2];
        $newparams{critical} = $metricmatches[0]->[3];
      } elsif (@dbtmatches) {
        $newparams{warning} = $dbtmatches[0]->[2];
        $newparams{critical} = $dbtmatches[0]->[3];
      } elsif (@name2matches) {
        $newparams{warning} = $name2matches[0]->[2];
        $newparams{critical} = $name2matches[0]->[3];
      } elsif (@namematches) {
        $newparams{warning} = $namematches[0]->[2];
        $newparams{critical} = $namematches[0]->[3];
      } elsif (@modematches) {
        $newparams{warning} = $modematches[0]->[2];
        $newparams{critical} = $modematches[0]->[3];
      }
      delete $newparams{warning} if
          (! defined $newparams{warning} ||
              $newparams{warning} !~ /^[-+]?[0-9]*\.?[0-9]+$/);
      delete $newparams{critical} if
          (! defined $newparams{critical} ||
              $newparams{critical} !~ /^[-+]?[0-9]*\.?[0-9]+$/);
      $newparams{metric} = $params{metric} if exists $params{metric};
      $self->debug("overwrite thresholds with db-values: %s", Data::Dumper::Dumper(\%newparams)) if scalar(%newparams);
      $self->SUPER::set_thresholds(%newparams) if scalar(%newparams);
    }
  }
}

sub find_extcmd {
  my ($self, $cmd, @envpaths) = @_;
  my @paths = $^O =~ /MSWin/ ?
      split(';', $ENV{PATH}) : split(':', $ENV{PATH});
  return $self->{extcmd} if $self->{extcmd};
  foreach my $path (@envpaths) {
    if ($ENV{$path}) {
      if (! -d $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd) &&
          -x $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd)) {
        $self->{extcmd} = $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd);
        last;
      } elsif (! -d $path.'/bin/'.$cmd && -x $path.'/bin/'.$cmd) {
        $self->{extcmd} = $path.'/bin/'.$cmd;
        last;
      }
    }
  }
  return $self->{extcmd} if $self->{extcmd};
  foreach my $path (@paths) {
    if (! -d $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd) &&
        -x $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd)) {
      $self->{extcmd} = $path.'/'.($^O =~ /MSWin/ ? $cmd.'.exe' : $cmd);
      if ($^O =~ /MSWin/) {
        map { $ENV{$_} = $path } @envpaths;
      } else {
        if (basename(dirname($path)) eq "bin") {
          $path = dirname(dirname($path));
        }
        map { $ENV{$_} = $path } @envpaths;
      }
      last;
    }
  }
  return $self->{extcmd};
}

sub write_extcmd_file {
  my ($self, $sql) = @_;
}

sub create_extcmd_files {
  my ($self) = @_;
  my $template = $self->opts->mode.'XXXXX';
  if ($^O =~ /MSWin/) {
    $template =~ s/::/_/g;
  }
  ($self->{sql_commandfile_handle}, $self->{sql_commandfile}) =
      tempfile($template, SUFFIX => ".sql",
      DIR => $self->system_tmpdir() );
  close $self->{sql_commandfile_handle};
  ($self->{sql_resultfile_handle}, $self->{sql_resultfile}) =
      tempfile($template, SUFFIX => ".out",
      DIR => $self->system_tmpdir() );
  close $self->{sql_resultfile_handle};
  ($self->{sql_outfile_handle}, $self->{sql_outfile}) =
      tempfile($template, SUFFIX => ".out",
      DIR => $self->system_tmpdir() );
  close $self->{sql_outfile_handle};
  $Monitoring::GLPlugin::DB::sql_commandfile = $self->{sql_commandfile};
  $Monitoring::GLPlugin::DB::sql_resultfile = $self->{sql_resultfile};
  $Monitoring::GLPlugin::DB::sql_outfile = $self->{sql_outfile};
}

sub delete_extcmd_files {
  my ($self) = @_;
  unlink $Monitoring::GLPlugin::DB::sql_commandfile
      if $Monitoring::GLPlugin::DB::sql_commandfile &&
      -f $Monitoring::GLPlugin::DB::sql_commandfile;
  unlink $Monitoring::GLPlugin::DB::sql_resultfile
      if $Monitoring::GLPlugin::DB::sql_resultfile &&
      -f $Monitoring::GLPlugin::DB::sql_resultfile;
  unlink $Monitoring::GLPlugin::DB::sql_outfile
      if $Monitoring::GLPlugin::DB::sql_outfile &&
      -f $Monitoring::GLPlugin::DB::sql_outfile;
}

sub fetchall_array_cached {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my @rows = ();
  my $key = Digest::MD5::md5_hex($sql.Data::Dumper::Dumper(\@arguments));
  if (! exists $Monitoring::GLPlugin::DB->{fetchall_array_cache}->{$key}) {
    @rows = $self->fetchall_array($sql, @arguments);
    $Monitoring::GLPlugin::DB->{fetchall_array_cache}->{$key} = \@rows;
  } else {
    $self->debug(sprintf "cached SQL:\n%s\n", $sql);
    @rows = @{$Monitoring::GLPlugin::DB->{fetchall_array_cache}->{$key}};
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@rows));
  }
  return @rows;
}


sub DESTROY {
  my ($self) = @_;
  $self->delete_extcmd_files();
}



package Monitoring::GLPlugin::DB::DBI;
our @ISA = qw(Monitoring::GLPlugin::DB);
use strict;

sub fetchrow_array {
  my ($self, $sql, @arguments) = @_;
  my $sth = undef;
  my @row = ();
  my $stderrvar = "";
  $self->set_variable("verbosity", 2);
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments) || die DBI::errstr();
    } else {
      $sth->execute() || die DBI::errstr();
    }
    @row = $sth->fetchrow_array();
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@row));
    my $rest = $sth->fetchall_arrayref();
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return $row[0] unless wantarray;
  return @row;
}

sub fetchall_array {
  my ($self, $sql, @arguments) = @_;
  my $sth = undef;
  my $rows = undef;
  my $stderrvar = "";
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments);
    } else {
      $sth->execute();
    }
    $rows = $sth->fetchall_arrayref();
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $rows = [];
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  }
  return @{$rows};
}

sub execute {
  my ($self, $sql) = @_;
  my $errvar = "";
  my $stderrvar = "";
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "EXEC:\n%s\n", $sql);
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    $sth->execute();
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar || $errvar) {
    $errvar = join("\n", (split(/\n/, $errvar), $stderrvar));
    $self->debug(sprintf "stderr %s", $errvar) ;
    $self->add_warning($errvar);
  }
}

sub DESTROY {
  my ($self) = @_;
  $self->debug(sprintf "disconnecting DBD %s",
      $Monitoring::GLPlugin::DB::session ? "with handle" : "without handle");
  $Monitoring::GLPlugin::DB::session->disconnect() if $Monitoring::GLPlugin::DB::session;
}

sub add_dbi_funcs {
  my ($self) = @_;
  $self->SUPER::add_dbi_funcs();
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::fetchall_array'} = \&{"Monitoring::GLPlugin::DB::DBI::fetchall_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_array'} = \&{"Monitoring::GLPlugin::DB::DBI::fetchrow_array"};
    *{'Monitoring::GLPlugin::DB::execute'} = \&{"Monitoring::GLPlugin::DB::DBI::execute"};
  }
}

package Monitoring::GLPlugin::DB::CSF;
#our @ISA = qw(Monitoring::GLPlugin::DB);
use strict;

# sub create_statefile
# will be set via symbol table, because different database types can have
# different command line parameters (used to construct a filename)



package Monitoring::GLPlugin::DB::Item;
our @ISA = qw(Monitoring::GLPlugin::DB::CSF Monitoring::GLPlugin::Item Monitoring::GLPlugin::DB);
use strict;



package Monitoring::GLPlugin::DB::TableItem;
our @ISA = qw(Monitoring::GLPlugin::DB::CSF Monitoring::GLPlugin::TableItem Monitoring::GLPlugin::DB);
use strict;

sub globalize_errors {
  my ($self) = @_;
  #delete *{'add_message'};
  {
    no strict 'refs';
    foreach my $sub (qw(add_ok add_warning add_critical add_unknown
        add_message check_messages)) {
      *{$sub} = *{'Monitoring::GLPlugin::'.$sub};
    }
  }
}

sub localize_errors {
  my ($self) = @_;
  $self->{messages} = { 
      ok=> [],
      warning => [],
      critical => [],
      unknown => []
  } if ! exists $self->{messages};
  # save global errors
  {
    no strict 'refs';
    foreach my $sub (qw(add_ok add_warning add_critical add_unknown
        add_message check_messages)) {
      *{$sub} = *{'Monitoring::GLPlugin::Commandline::'.$sub};
    }
  }
}



package Classes::MSSQL::Component::AvailabilitygroupSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my ($self) = @_;
  my $sql = undef;
  my $allfilter = sub {
    my ($o) = @_;
    $self->filter_name($o->{name});
  };
  if ($self->mode =~ /server::availabilitygroup::status/) {
    if ($self->version_is_minimum("11.x")) {
      my $columns = [qw(server_name group_id name primary_replica primary_recovery_health_desc
          secondary_recovery_health_desc synchronization_health_desc)];
      my $avgfilter = sub {
        my $o = shift;
        $self->filter_name($o->{name});
      };
      my $sql = q{
        SELECT
          @@ServerName,
          [ag].[group_id],
          [ag].[name],
          [gs].[primary_replica],
          [gs].[primary_recovery_health_desc],
          [gs].[secondary_recovery_health_desc],
          [gs].[synchronization_health_desc]
        FROM
          [master].[sys].[availability_groups]
        AS
          [ag]
        INNER JOIN
          [master].[sys].[dm_hadr_availability_group_states]
        AS
          [gs]
        ON
          [ag].[group_id] = [gs].[group_id]
      };
      my $resql = q{
        select @@ServerName,* from [master].[sys].[dm_hadr_availability_replica_states]
      };
      my $recolumns = [qw(server_name replica_id group_id is_local role role_desc operational_state
          operational_state_desc connected_state connected_state_desc recovery_health
          recovery_health_desc synchronization_health synchronization_health_desc
          last_connect_error_number last_connect_error_description
          last_connect_error_timestamp)];
      $self->get_db_tables([
          ['avgroups', $sql, 'Classes::MSSQL::Component::AvailabilitygroupSubsystem::Availabilitygroup', $avgfilter, $columns],
          # vielleicht spaeter mal, um mehr details zu holen
          #['regroups', $resql, 'Classes::MSSQL::Component::AvailabilitygroupSubsystem::Replicastate', $avgfilter, $recolumns],
      ]);
    } else {
      $self->add_ok(sprintf 'your version %s is too old, availability group monitoring is not possible', $self->get_variable('version'));
    }
  }
}


package Classes::MSSQL::Component::AvailabilitygroupSubsystem::Replicastate;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

package Classes::MSSQL::Component::AvailabilitygroupSubsystem::Availabilitygroup;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub check {
  my ($self) = @_;
  if ($self->mode =~ /server::availabilitygroup::status/) {
    $self->add_info(sprintf 'availability group %s has synch. status %s', $self->{name},
        lc $self->{synchronization_health_desc});
    if ($self->{server_name} ne $self->{primary_replica}) {
      $self->add_ok(sprintf 'this is is a secondary replica if group %s. for a reliable status you have to ask the primary replica',
          $self->{name});
    } elsif ($self->{synchronization_health_desc} eq 'HEALTHY') {
      $self->add_ok();
    } elsif ($self->{synchronization_health_desc} eq 'PARTIALLY_HEALTHY') {
      $self->add_warning();
    } elsif ($self->{synchronization_health_desc} eq 'NOT_HEALTHY') {
      $self->add_critical();
    } else {
      $self->add_unknown();
    }
  }
}

package Classes::MSSQL::Component::DatabaseSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub filter_all {
  my $self = shift;
}

# database-free			database::free
# database-data-free		database::datafree
# database-logs-free		database::logfree
# list-databases		database::list
# list-database-filegroups	database::filegroup::list
# list-database-files		database::file::list
# database-files-free		database::file::free
# database-filegroups-free	database::filegroup::free
sub init {
  my $self = shift;
  my $sql = undef;
  my $allfilter = sub {
    my $o = shift;
    $self->filter_name($o->{name}) &&
        ! (($self->opts->notemp && $o->is_temp) || ($self->opts->nooffline && ! $o->is_online));
  };
  if ($self->mode =~ /server::database::(createuser|deleteuser|list|free.*|datafree.*|logfree.*|transactions|size)$/ ||
      $self->mode =~ /server::database::(file|filegroup)/) {
    my $columns = ['name', 'id', 'state', 'state_desc'];
    if ($self->version_is_minimum("9.x")) {
      if ($self->get_variable('ishadrenabled')) {
        if ($self->version_is_minimum("12.x")) {
          # is_primary_replica was introduced with 12.0 "Hekaton" (2014)
          $sql = q{
            SELECT
                db.name, db.database_id AS id, db.state, db.state_desc
            FROM
                master.sys.databases db
            LEFT OUTER JOIN
                master.sys.dm_hadr_database_replica_states AS dbrs
            ON
                db.replica_id = dbrs.replica_id AND db.group_database_id = dbrs.group_database_id
            WHERE
                -- ignore database snapshots  AND -- ignore alwayson replicas 
                db.source_database_id IS NULL AND (dbrs.is_primary_replica IS NULL OR dbrs.is_primary_replica = 1)
          };
        } else {
          $sql = q{
            SELECT
                db.name, db.database_id AS id, db.state, db.state_desc
            FROM
                master.sys.databases db
            LEFT OUTER JOIN
                master.sys.dm_hadr_database_replica_states AS dbrs
            ON
                db.replica_id = dbrs.replica_id AND db.group_database_id = dbrs.group_database_id
            WHERE
                -- ignore database snapshots
                db.source_database_id IS NULL
          };
        }
      } else {
        $sql = q{
          SELECT
              name, database_id AS id, state, state_desc
          FROM
              master.sys.databases
          WHERE
              source_database_id IS NULL
          ORDER BY
              name
        };
      }
    } else {
      $sql = q{
        SELECT
            name, dbid AS id, status, NULL
        FROM
            master.dbo.sysdatabases
        ORDER BY
            name
      };
    }
    if ($self->mode =~ /server::database::(free|datafree|logfree|size)/ ||
        $self->mode =~ /server::database::(file|filegroup)/) {
      $self->filesystems();
    }
    $self->get_db_tables([
        ['databases', $sql, 'Classes::MSSQL::Component::DatabaseSubsystem::DatabaseStub', $allfilter, $columns],
    ]);
    @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
    foreach (@{$self->{databases}}) {
      # extra Schritt, weil finish() aufwendig ist und bei --name sparsamer aufgerufen wird
      bless $_, 'Classes::MSSQL::Component::DatabaseSubsystem::Database';
      $_->finish();
    }
  } elsif ($self->mode =~ /server::database::online/) {
    my $columns = ['name', 'state', 'state_desc', 'collation_name'];
    if ($self->version_is_minimum("9.x")) {
      if ($self->get_variable('ishadrenabled')) {
        if ($self->version_is_minimum("12.x")) {
          $sql = q{
            SELECT
                db.name, db.state, db.state_desc, db.collation_name
            FROM
                master.sys.databases db
            LEFT OUTER JOIN
                master.sys.dm_hadr_database_replica_states AS dbrs
            ON
                db.replica_id = dbrs.replica_id AND db.group_database_id = dbrs.group_database_id
            WHERE
                -- ignore database snapshots  AND -- ignore alwayson replicas
                db.source_database_id IS NULL AND (dbrs.is_primary_replica IS NULL OR dbrs.is_primary_replica = 1)
          };
        } else {
          $sql = q{
            SELECT
                db.name, db.state, db.state_desc, db.collation_name
            FROM
                master.sys.databases db
            LEFT OUTER JOIN
                master.sys.dm_hadr_database_replica_states AS dbrs
            ON
                db.replica_id = dbrs.replica_id AND db.group_database_id = dbrs.group_database_id
            WHERE
                -- ignore database snapshots
                db.source_database_id IS NULL
          };
        }
      } else {
        $sql = q{
          SELECT
              name, state, state_desc, collation_name
          FROM
              master.sys.databases
          WHERE
              source_database_id IS NULL
          ORDER BY
              name
        };
      }
    }
    $self->get_db_tables([
        ['databases', $sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database', $allfilter, $columns],
    ]);
    @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
  } elsif ($self->mode =~ /server::database::(.*backupage)/) {
    my $columns = ['name', 'recovery_model', 'backup_age', 'backup_duration'];
    if ($self->mode =~ /server::database::backupage/) {
      if ($self->version_is_minimum("9.x")) {
        $sql = q{
          SELECT D.name AS [database_name], D.recovery_model, BS1.last_backup, BS1.last_duration
          FROM sys.databases D
          LEFT JOIN (
            SELECT BS.[database_name],
            DATEDIFF(HH,MAX(BS.[backup_finish_date]),GETDATE()) AS last_backup,
            DATEDIFF(MI,MAX(BS.[backup_start_date]),MAX(BS.[backup_finish_date])) AS last_duration
            FROM msdb.dbo.backupset BS WITH (NOLOCK)
            WHERE BS.type IN ('D', 'I')
            GROUP BY BS.[database_name]
          ) BS1 ON D.name = BS1.[database_name] WHERE D.source_database_id IS NULL
          ORDER BY D.[name];
        };
      } else {
        $sql = q{
          SELECT
            a.name,
            CASE databasepropertyex(a.name, 'Recovery')
              WHEN 'FULL' THEN 1
              WHEN 'BULK_LOGGED' THEN 2
              WHEN 'SIMPLE' THEN 3
              ELSE 0
            END AS recovery_model,
            DATEDIFF(HH, MAX(b.backup_finish_date), GETDATE()),
            DATEDIFF(MI, MAX(b.backup_start_date), MAX(b.backup_finish_date))
          FROM master.dbo.sysdatabases a LEFT OUTER JOIN msdb.dbo.backupset b
          ON b.database_name = a.name
          GROUP BY a.name
          ORDER BY a.name
        };
      }
    } elsif ($self->mode =~ /server::database::logbackupage/) {
      if ($self->version_is_minimum("9.x")) {
        $sql = q{
          SELECT D.name AS [database_name], D.recovery_model, BS1.last_backup, BS1.last_duration
          FROM sys.databases D
          LEFT JOIN (
            SELECT BS.[database_name],
            DATEDIFF(HH,MAX(BS.[backup_finish_date]),GETDATE()) AS last_backup,
            DATEDIFF(MI,MAX(BS.[backup_start_date]),MAX(BS.[backup_finish_date])) AS last_duration
            FROM msdb.dbo.backupset BS WITH (NOLOCK)
            WHERE BS.type = 'L'
            GROUP BY BS.[database_name]
          ) BS1 ON D.name = BS1.[database_name] WHERE D.source_database_id IS NULL
          ORDER BY D.[name];
        };
      } else {
        $self->no_such_mode();
      }
    }
    $self->get_db_tables([
        ['databases', $sql, 'Classes::MSSQL::Component::DatabaseSubsystem::DatabaseStub', $allfilter, $columns],
    ]);
    @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
    foreach (@{$self->{databases}}) {
      bless $_, 'Classes::MSSQL::Component::DatabaseSubsystem::Database';
      $_->finish();
    }
  } elsif ($self->mode =~ /server::database::auto(growths|shrinks)/) {
    if ($self->version_is_minimum("9.x")) {
      my $db_columns = ['name'];
      my $db_sql = q{
        SELECT name FROM master.sys.databases
      };
      $self->override_opt('lookback', 30) if ! $self->opts->lookback;
      my $evt_columns = ['name', 'count'];
      my $evt_sql = q{
          DECLARE @path NVARCHAR(1000)
          SELECT
              @path = Substring(PATH, 1, Len(PATH) - Charindex('\', Reverse(PATH))) + '\log.trc'
          FROM
              sys.traces
          WHERE
              id = 1
          SELECT
              databasename, COUNT(*)
          FROM
              ::fn_trace_gettable(@path, 0)
          INNER JOIN
              sys.trace_events e
          ON
              eventclass = trace_event_id
          -- INNER JOIN
          --    sys.trace_categories AS cat
          -- ON
          --     e.category_id = cat.category_id
          WHERE
              e.name IN( EVENTNAME ) AND datediff(Minute, starttime, current_timestamp) < ?
          GROUP BY
              databasename
      };
      if ($self->mode =~ /server::database::autogrowths::file/) {
        $evt_sql =~ s/EVENTNAME/'Data File Auto Grow', 'Log File Auto Grow'/;
      } elsif ($self->mode =~ /server::database::autogrowths::logfile/) {
        $evt_sql =~ s/EVENTNAME/'Log File Auto Grow'/;
      } elsif ($self->mode =~ /server::database::autogrowths::datafile/) {
        $evt_sql =~ s/EVENTNAME/'Data File Auto Grow'/;
      }
      if ($self->mode =~ /server::database::autoshrinks::file/) {
        $evt_sql =~ s/EVENTNAME/'Data File Auto Shrink', 'Log File Auto Shrink'/;
      } elsif ($self->mode =~ /server::database::autoshrinks::logfile/) {
        $evt_sql =~ s/EVENTNAME/'Log File Auto Shrink'/;
      } elsif ($self->mode =~ /server::database::autoshrinks::datafile/) {
        $evt_sql =~ s/EVENTNAME/'Data File Auto Shrink'/;
      }
      $self->get_db_tables([
          ['databases', $db_sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database', $allfilter, $db_columns],
          ['events', $evt_sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database', $allfilter, $evt_columns, [$self->opts->lookback]],
      ]);
      @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
      foreach my $database (@{$self->{databases}}) {
        $database->{autogrowshrink} = eval {
            map { $_->{count} } grep { $_->{name} eq $database->{name} } @$self->{events}
        } || 0;
        $database->{growshrinkinterval} = $self->opts->lookback;
      }
    } else {
      $self->no_such_mode();
    }
  } elsif ($self->mode =~ /server::database::dbccshrinks/) {
    if ($self->version_is_minimum("9.x")) {
      my $db_columns = ['name'];
      my $db_sql = q{
        SELECT name FROM master.sys.databases
      };
      $self->override_opt('lookback', 30) if ! $self->opts->lookback;
      my $evt_columns = ['name', 'count'];
      # starttime = Oct 22 2012 01:51:41:373AM = DBD::Sybase datetype LONG
      my $evt_sql = q{
          DECLARE @path NVARCHAR(1000)
          SELECT
              @path = Substring(PATH, 1, Len(PATH) - Charindex('\', Reverse(PATH))) + '\log.trc'
          FROM
              sys.traces
          WHERE
              id = 1
          SELECT
              databasename, COUNT(*)
          FROM
              ::fn_trace_gettable(@path, 0)
          INNER JOIN
              sys.trace_events e
          ON
              eventclass = trace_event_id
          -- INNER JOIN
          --     sys.trace_categories AS cat
          -- ON
          --     e.category_id = cat.category_id
          WHERE
              EventClass = 116 AND TEXTData LIKE '%SHRINK%' AND datediff(Minute, starttime, current_timestamp) < ?
          GROUP BY
              databasename
      };
      $self->get_db_tables([
          ['databases', $db_sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database', $allfilter, $db_columns],
          ['events', $evt_sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database', $allfilter, $evt_columns, [$self->opts->lookback]],
      ]);
      @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
      foreach my $database (@{$self->{databases}}) {
        $database->{autogrowshrink} = eval {
            map { $_->{count} } grep { $_->{name} eq $database->{name} } @$self->{events}
        } || 0;
        $database->{growshrinkinterval} = $self->opts->lookback;
      }
    } else {
      $self->no_such_mode();
    }
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking databases');
  if ($self->mode =~ /server::database::deleteuser$/) {
    foreach (@{$self->{databases}}) {
      $_->check();
    }
    $self->execute(q{
      USE MASTER DROP USER
    }.$self->opts->name2);
    $self->execute(q{
      USE MASTER DROP LOGIN
    }.$self->opts->name2);
  } elsif ($self->mode =~ /server::database::createuser$/) {
    # --username admin --password ... --name <db> --name2 <monuser> --name3 <monpass>
    my $user = $self->opts->name2;
    #$user =~ s/\\/\\\\/g if $user =~ /\\/;
    $self->override_opt("name2", "[".$user."]");
    my $sql = sprintf "CREATE LOGIN %s %s DEFAULT_DATABASE=MASTER, DEFAULT_LANGUAGE=English",
        $self->opts->name2,
        ($self->opts->name2 =~ /\\/) ?
            "FROM WINDOWS WITH" :
            sprintf("WITH PASSWORD='%s',", $self->opts->name3);
    $self->execute($sql);
    $self->execute(q{
      USE MASTER GRANT VIEW SERVER STATE TO
    }.$self->opts->name2);
    $self->execute(q{
      USE MASTER GRANT ALTER trace TO
    }.$self->opts->name2);
    if ($self->get_variable('ishadrenabled')) {
      $self->execute(q{
        USE MASTER GRANT SELECT ON sys.availability_groups TO
      }.$self->opts->name2);
      $self->execute(q{
        USE MASTER GRANT SELECT ON sys.availability_replicas TO
      }.$self->opts->name2);
      $self->execute(q{
        USE MASTER GRANT SELECT ON sys.dm_hadr_database_replica_cluster_states TO
      }.$self->opts->name2);
      $self->execute(q{
        USE MASTER GRANT SELECT ON sys.fn_hadr_backup_is_preferred_replica TO
      }.$self->opts->name2);
    }
    # for instances with secure configuration
    $self->execute(q{
      USE MASTER GRANT SELECT ON sys.filegroups TO
    }.$self->opts->name2);
    $self->execute(q{
      USE MSDB CREATE USER
    }.$self->opts->name2.q{
      FOR LOGIN
    }.$self->opts->name2);
    $self->execute(q{
      USE MSDB GRANT SELECT ON sysjobhistory TO
    }.$self->opts->name2);
    $self->execute(q{
      USE MSDB GRANT SELECT ON sysjobschedules TO
    }.$self->opts->name2);
    $self->execute(q{
      USE MSDB GRANT SELECT ON sysjobs TO
    }.$self->opts->name2);
    if (my ($code, $message) = $self->check_messages(join_all => "\n")) {
printf "CODE %d MESS %s\n", $code, $message;
      if (grep ! /(The server principal.*already exists)|(User.*group.*role.*already exists in the current database)/, split(/\n/, $message)) {
        $self->clear_critical();
        foreach (@{$self->{databases}}) {
          $_->check();
        }
      }
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /server::database::.*list$/) {
    $self->SUPER::check();
    $self->add_ok("have fun");
  } else {
    foreach (@{$self->{databases}}) {
      $_->check();
    }
  }
}

sub filesystems {
  my $self = shift;
  $self->get_db_tables([
      ['filesystems', 'exec master.dbo.xp_fixeddrives', 'Monitoring::GLPlugin::DB::TableItem', undef, ['drive', 'mb_free']],
  ]);
  $Classes::MSSQL::Component::DatabaseSubsystem::filesystems =
      { map { uc $_->{drive} => 1024 * 1024 * $_->{mb_free} } @{$self->{filesystems}} };
}

package Classes::MSSQL::Component::DatabaseSubsystem::DatabaseStub;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub is_backup_node {
  my $self = shift;
  if ($self->version_is_minimum("11.x")) {
    if (exists $self->{preferred_replica} && $self->{preferred_replica} == 1) {
      return 1;
    } else {
      return 0;
    }
  } else {
    return 1;
  }
}

sub is_online {
  my $self = shift;
  return 0 if $self->{messages}->{critical} && grep /is offline/, @{$self->{messages}->{critical}};
  if ($self->version_is_minimum("9.x")) {
    return 1 if $self->{state_desc} && $self->{state_desc} eq "online";
    # ehem. offline = $self->{state} == 6 ? 1 : 0;
  } else {
    # bit 512 is offline
    return $self->{state} & 0x0200 ? 0 : 1;
  }
  return 0;
}

sub is_problematic {
  my $self = shift;
  if ($self->{messages}->{critical}) {
    my $error = join(", ", @{$self->{messages}->{critical}});
    if ($error =~ /Message String: ([\w ]+)/) {
      return $1;
    } else {
      return $error;
    }
  } else {
    return 0;
  }
}

sub is_readable {
  my $self = shift;
  return ($self->{messages}->{critical} && grep /is not able to access the database/i, @{$self->{messages}->{critical}}) ? 0 : 1;
}

sub is_temp {
  my $self = shift;
  return $self->{name} eq "tempdb" ? 1 : 0;
}

sub mbize {
  my $self = shift;
  foreach (qw(max_size size used_size rows_max_size rows_size rows_used_size logs_max_size logs_size logs_used_size)) {
    next if ! exists $self->{$_};
    $self->{$_.'_mb'} = $self->{$_} / (1024*1024);
  }
}

package Classes::MSSQL::Component::DatabaseSubsystem::Database;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem Classes::MSSQL::Component::DatabaseSubsystem::DatabaseStub);
use strict;

sub finish {
  my $self = shift;
  $self->override_opt("units", "%") if ! $self->opts->units;
  $self->{full_name} = $self->{name};
  $self->{state_desc} = lc $self->{state_desc} if $self->{state_desc};
  if ($self->mode =~ /server::database::(free.*|datafree.*|logfree.*|size)$/ ||
      $self->mode =~ /server::database::(file|filegroup)/) {
    # private copy for this database
    %{$self->{filesystems}} = %{$Classes::MSSQL::Component::DatabaseSubsystem::filesystems};
    my @filesystems = keys %{$self->{filesystems}};
    $self->{size} = 0;
    $self->{max_size} = 0;
    $self->{used_size} = 0;
    $self->{drive_reserve} = 0;
    my $sql;
    my $columns = ['database_name', 'filegroup_name', 'name', 'is_media_read_only', 'is_read_only',
        'is_sparse', 'size', 'max_size', 'growth', 'is_percent_growth',
        'used_size', 'type', 'state', 'drive', 'path'];
    if ($self->version_is_minimum("9.x")) {
      $sql = q{
        USE
      [}.$self->{name}.q{]
        SELECT
          '}.$self->{name}.q{',
          ISNULL(fg.name, 'TLOGS'),
          dbf.name,
          dbf.is_media_read_only,
          dbf.is_read_only,
          dbf.is_sparse, -- erstmal wurscht, evt. sys.dm_io_virtual_file_stats fragen
          -- dbf.size * 8.0 * 1024,
          -- dbf.max_size * 8.0 * 1024 AS max_size,
          -- dbf.growth,
          -- FILEPROPERTY(dbf.NAME,'SpaceUsed') * 8.0 * 1024 AS used_size,
          dbf.size,
          dbf.max_size,
          dbf.growth,
          dbf.is_percent_growth,
          FILEPROPERTY(dbf.NAME,'SpaceUsed') AS used_size,
          dbf.type_desc,
          dbf.state_desc,
          UPPER(SUBSTRING(dbf.physical_name, 1, 1)) AS filesystem_drive_letter,
          dbf.physical_name AS filesystem_path
        FROM
          sys.database_files AS dbf --use sys.master_files if the database is read only (more recent data)
        LEFT OUTER JOIN
          -- leider muss man mit AS arbeiten statt database_files.data_space_id.
          -- das kracht bei 2005-compatibility-dbs wegen irgendeines ansi-92/outer-join syntaxmischmaschs
          sys.filegroups AS fg
        ON
          dbf.data_space_id = fg.data_space_id
        WHERE
          dbf.type_desc != 'FILESTREAM'
      };
    }
    if ($self->is_online) {
      $self->localize_errors();
      $self->get_db_tables([
        ['files', $sql, 'Classes::MSSQL::Component::DatabaseSubsystem::Database::Datafile', undef, $columns],
      ]);
      $self->globalize_errors();
      $self->{filegroups} = [];
      my %seen = ();
      foreach my $group (grep !$seen{$_}++, map { $_->{filegroup_name} } @{$self->{files}}) {
        push (@{$self->{filegroups}},
            Classes::MSSQL::Component::DatabaseSubsystem::Database::Datafilegroup->new(
                name => $group,
                database_name => $self->{name},
                files => [grep { $_->{filegroup_name} eq $group } @{$self->{files}}],
        ));
      #  @{$self->{files}} = grep { $_->{filegroup_name} eq $group } @{$self->{files}};
      }
      delete $self->{files};
      # $filegroup->{drive_reserve} ist mehrstufig, drives jeweils extra
      $self->{drive_reserve} = {};
      map { $self->{drive_reserve}->{$_} = 0; } @filesystems;
      foreach my $filegroup (@{$self->{filegroups}}) {
        next if $filegroup->{type} eq 'LOG'; # alles ausser logs zaehlt als rows
        $self->{'rows_size'} += $filegroup->{size};
        $self->{'rows_used_size'} += $filegroup->{used_size};
        $self->{'rows_max_size'} += $filegroup->{max_size};
        map { $self->{drive_reserve}->{$_} += $filegroup->{drive_reserve}->{$_}} @filesystems;
      }
      # 1x reserve pro drive erlaubt
      map {
        $self->{'rows_max_size'} -= --$self->{drive_reserve}->{$_} * $self->{filesystems}->{$_};
        $self->{drive_reserve}->{$_} = 1;
      } grep {
        $self->{drive_reserve}->{$_};
      } @filesystems;
      # fuer modus database-free wird freier drive-platz sowohl den rows als auch den logs zugeschlagen
      map { $self->{drive_reserve}->{$_} = 0; } @filesystems;
      foreach my $filegroup (@{$self->{filegroups}}) {
        next if $filegroup->{type} ne 'LOG';
        $self->{'logs_size'} += $filegroup->{size};
        $self->{'logs_used_size'} += $filegroup->{used_size};
        $self->{'logs_max_size'} += $filegroup->{max_size};
        map { $self->{drive_reserve}->{$_} += $filegroup->{drive_reserve}->{$_}} @filesystems;
      }
      map {
        $self->{'logs_max_size'} -= --$self->{drive_reserve}->{$_} * $self->{filesystems}->{$_};
        $self->{drive_reserve}->{$_} = 1;
      } grep {
        exists $self->{'logs_max_size'} && $self->{drive_reserve}->{$_};
      } @filesystems;
    }
    $self->mbize();
  } elsif ($self->mode =~ /server::database::(.*backupage)$/) {
    if ($self->version_is_minimum("11.x")) {
      if ($self->get_variable('ishadrenabled')) {
        my @replicated_databases = $self->fetchall_array_cached(q{
          SELECT
            DISTINCT CS.database_name AS [DatabaseName]
          FROM
            master.sys.availability_groups AS AG
          INNER JOIN
            master.sys.availability_replicas AS AR ON AG.group_id = AR.group_id
          INNER JOIN
            master.sys.dm_hadr_database_replica_cluster_states AS CS
          ON
            AR.replica_id = CS.replica_id
          WHERE
            CS.is_database_joined = 1 -- DB muss aktuell auch in AG aktiv sein
        });
        if (grep { $self->{name} eq $_->[0] } @replicated_databases) {
          # this database is part of an availability group
          # find out if we are the preferred node, where the backup takes place
          $self->{preferred_replica} = $self->fetchrow_array(q{
            SELECT sys.fn_hadr_backup_is_preferred_replica(?)
          }, $self->{name});
        } else {
          # -> every node hat to be backupped, the db is local on every node
          $self->{preferred_replica} = 1;
        }
      } else {
        $self->{preferred_replica} = 1;
      }
    }
  } elsif ($self->mode =~ /server::database::(transactions)$/) {
    # Transactions/sec ist irrefuehrend, das ist in Wirklichkeit ein Hochzaehldings
    $self->get_perf_counters([
        ['transactions', 'SQLServer:Databases', 'Transactions/sec', $self->{name}],
    ]);
    return if $self->check_messages();
    my $label = $self->{name}.'_transactions_per_sec';
    my $autoclosed = 0;
    if ($self->{name} ne '_Total' && $self->version_is_minimum("9.x")) {
      my $sql = q{
          SELECT is_cleanly_shutdown, CAST(DATABASEPROPERTYEX('?', 'isautoclose') AS VARCHAR)
          FROM master.sys.databases WHERE name = '?'};
      $sql =~ s/\?/$self->{name}/g;
      my @autoclose = $self->fetchrow_array($sql);
      if ($autoclose[0] == 1 && $autoclose[1] == 1) {
        $autoclosed = 1;
      }
    }
    if ($autoclosed) {
      $self->{transactions_per_sec} = 0;
    }
    $self->set_thresholds(
        metric => $label,
        warning => 10000, critical => 50000
    );
    $self->add_message($self->check_thresholds(
        metric => $label,
        value => $self->{transactions_per_sec},
    ), sprintf "%s has %.4f transactions / sec",
        $self->{name}, $self->{transactions_per_sec}
    );
    $self->add_perfdata(
        label => $label,
        value => $self->{transactions_per_sec},
    );
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /server::database::list$/) {
    printf "%s\n", $self->{name};
  } elsif ($self->mode =~ /server::database::deleteuser$/) {
    $self->execute(q{
      USE
    }.$self->{name}.q{
      DROP USER
    }.$self->opts->name2);
    $self->execute(q{
      USE
    }.$self->{name}.q{
      DROP ROLE CHECKMSSQLHEALTH
    });
  } elsif ($self->mode =~ /server::database::createuser$/) {
    $self->execute(q{
      USE
    }.$self->{name}.q{
      CREATE USER
    }.$self->opts->name2.q{
      FOR LOGIN
    }.$self->opts->name2) if $self->{name} ne "msdb";
    $self->execute(q{
      USE
    }.$self->{name}.q{
      CREATE ROLE CHECKMSSQLHEALTH
    });
    $self->execute(q{
      USE
    }.$self->{name}.q{
      EXEC sp_addrolemember CHECKMSSQLHEALTH,
    }.$self->opts->name2);
    $self->execute(q{
      USE
    }.$self->{name}.q{
      GRANT EXECUTE TO
    }.$self->opts->name2);
    $self->execute(q{
      USE
    }.$self->{name}.q{
      GRANT VIEW DATABASE STATE TO
    }.$self->opts->name2);
    $self->execute(q{
      USE
    }.$self->{name}.q{
      GRANT VIEW DEFINITION TO
    }.$self->opts->name2);
    if (my ($code, $message) = $self->check_messages(join_all => "\n")) {
      if (! grep ! /User.*group.*role.*already exists in the current database/, split(/\n/, $message)) {
        $self->clear_critical();
      }
      if (! grep ! /availability_groups.*because it does not exist/, split(/\n/, $message)) {
        $self->clear_critical();
      }
    }
  } elsif ($self->mode =~ /server::database::(filegroup|file)/) {
    foreach (@{$self->{filegroups}}) {
      if ($self->filter_name2($_->{name})) {
        $_->check();
      }
    }
  } elsif ($self->mode =~ /server::database::(free|datafree|logfree)/) {
    my @filetypes = qw(rows logs);
    if ($self->mode =~ /server::database::datafree/) {
      @filetypes = qw(rows);
    } elsif ($self->mode =~ /server::database::logfree/) {
      @filetypes = qw(logs);
    }
    if (! $self->is_online) {
      # offlineok hat vorrang
      $self->override_opt("mitigation", $self->opts->offlineok ? 0 : $self->opts->mitigation ? $self->opts->mitigation : 1);
      $self->add_message($self->opts->mitigation,
          sprintf("database %s is not online", $self->{name})
      );
    } elsif (! $self->is_readable) {
      $self->add_message($self->opts->mitigation ? $self->opts->mitigation : 1,
          sprintf("insufficient privileges to access %s", $self->{name})
      );
    } elsif ($self->is_problematic) {
      $self->add_message($self->opts->mitigation ? $self->opts->mitigation : 1,
          sprintf("error accessing %s: %s", $self->{name}, $self->is_problematic)
      );
    } else {
      foreach (@{$self->{filegroups}}) {
        $_->check();
      }
      $self->clear_ok();
      foreach my $type (@filetypes) {
        next if ! exists $self->{$type."_size"}; # not every db has a separate log
        my $metric_pct = ($type eq "rows") ?
            'db_'.lc $self->{name}.'_free_pct' : 'db_'.lc $self->{name}.'_log_free_pct';
        my $metric_units = ($type eq "rows") ?
            'db_'.lc $self->{name}.'_free' : 'db_'.lc $self->{name}.'_log_free';
        my $metric_allocated = ($type eq "rows") ?
            'db_'.lc $self->{name}.'_allocated_pct' : 'db_'.lc $self->{name}.'_log_allocated_pct';
        my ($free_percent, $free_size, $free_units, $allocated_percent, $factor) = $self->calc(
            'database', $self->{full_name}, $type,
            $self->{$type."_used_size"}, $self->{$type."_size"}, $self->{$type."_max_size"},
            $metric_pct, $metric_units, $metric_allocated
        );
        $self->add_perfdata(
            label => $metric_pct,
            value => $free_percent,
            places => 2,
            uom => '%',
        );
        $self->add_perfdata(
            label => $metric_units,
            value => $free_units,
            uom => $self->opts->units eq "%" ? "MB" : $self->opts->units,
            places => 2,
            min => 0,
            max => $self->{$type."_max_size"} / $factor,
        );
        $self->add_perfdata(
            label => $metric_allocated,
            value => $allocated_percent,
            places => 2,
            uom => '%',
        );
      }
    }
    if ($self->mode =~ /server::database::logfree/ && ! exists $self->{logs_size}) {
      $self->add_ok(sprintf "database %s has no logs", $self->{name});
    }
  } elsif ($self->mode =~ /server::database::online/) {
    if ($self->is_online) {
      if ($self->{collation_name}) {
        $self->add_ok(
          sprintf "%s is %s and accepting connections", $self->{name}, $self->{state_desc});
      } else {
        $self->add_warning(sprintf "%s is %s but not accepting connections",
            $self->{name}, $self->{state_desc});
      }
    } elsif ($self->{state_desc} =~ /^recover/i) {
      $self->add_warning(sprintf "%s is %s", $self->{name}, $self->{state_desc});
    } else {
      $self->add_critical(sprintf "%s is %s", $self->{name}, $self->{state_desc});
    }
  } elsif ($self->mode =~ /server::database::size/) {
    $self->override_opt("units", "MB") if (! $self->opts->units || $self->opts->units eq "%");
    my $factor = 1;
    if (uc $self->opts->units eq "GB") {
      $factor = 1024 * 1024 * 1024;
    } elsif (uc $self->opts->units eq "MB") {
      $factor = 1024 * 1024;
    } elsif (uc $self->opts->units eq "KB") {
      $factor = 1024;
    }
    $self->add_ok(sprintf "db %s allocated %.4f%s",
        $self->{name}, $self->{rows_size} / $factor,
        $self->opts->units);
    $self->add_perfdata(
        label => 'db_'.$self->{name}.'_alloc_size',
        value => $self->{rows_size} / $factor,
        uom => $self->opts->units,
        max => $self->{rows_max_size} / $factor,
    );
    if ($self->{logs_size}) {
      $self->add_ok(sprintf "db %s logs allocated %.4f%s",
          $self->{name}, $self->{logs_size} / $factor,
          $self->opts->units);
      $self->add_perfdata(
          label => 'db_'.$self->{name}.'_alloc_logs_size',
          value => $self->{logs_size} / $factor,
          uom => $self->opts->units,
          max => $self->{logs_max_size} / $factor,
      );
    }
  } elsif ($self->mode =~ /server::database::(.*backupage)$/) {
    if (! $self->is_backup_node) {
      $self->add_ok(sprintf "this is not the preferred replica for backups of %s", $self->{name});
      return;
    }
    my $log = "";
    if ($self->mode =~ /server::database::logbackupage/) {
      $log = "log of ";
    }
    if ($self->mode =~ /server::database::logbackupage/ && $self->{recovery_model} == 3) {
      $self->add_ok(sprintf "%s has no logs", $self->{name});
    } else {
      $self->set_thresholds(metric => $self->{name}.'_bck_age', warning => 48, critical => 72);
      if (! defined $self->{backup_age}) {
        $self->add_message(defined $self->opts->mitigation() ? $self->opts->mitigation() : 2,
            sprintf "%s%s was never backed up", $log, $self->{name});
        $self->{backup_age} = 0;
        $self->{backup_duration} = 0;
      } else {
        $self->add_message(
            $self->check_thresholds(metric => $self->{name}.'_bck_age', value => $self->{backup_age}),
            sprintf "%s%s was backed up %dh ago", $log, $self->{name}, $self->{backup_age});
      }
      $self->add_perfdata(
          label => $self->{name}.'_bck_age',
          value => $self->{backup_age},
      );
      $self->add_perfdata(
          label => $self->{name}.'_bck_time',
          value => $self->{backup_duration},
      );
    }
  } elsif ($self->mode =~ /server::database::auto(growths|shrinks)/) {
    my $type = "";
    if ($self->mode =~ /::datafile/) {
      $type = "data ";
    } elsif ($self->mode =~ /::logfile/) {
      $type = "log ";
    }
    my $label = sprintf "%s_auto_%ss",
        $type, ($self->mode =~ /server::database::autogrowths/) ? "grow" : "shrink";
    $self->set_thresholds(
        metric => $label,
        warning => 1, critical => 5
    );
    $self->add_message(
        $self->check_thresholds(metric => $label, value => $self->{autogrowshrink}),
        sprintf "%s had %d %sfile auto %s events in the last %d minutes", $self->{name},
            $self->{autogrowshrink}, $type,
            ($self->mode =~ /server::database::autogrowths/) ? "grow" : "shrink",
            $self->{growshrinkinterval}
    );
  } elsif ($self->mode =~ /server::database::dbccshrinks/) {
    # nur relevant fuer master
    my $label = "dbcc_shrinks";
    $self->set_thresholds(
        metric => $label,
        warning => 1, critical => 5
    );
    $self->add_message(
        $self->check_thresholds(metric => $label, value => $self->{autogrowshrink}),
        sprintf "%s had %d DBCC Shrink events in the last %d minutes", $self->{name}, $self->{autogrowshrink}, $self->{growshrinkinterval});
  }
}

sub calc {
  my ($self, $item, $name, $type, $used_size, $size, $max_size,
      $metric_pct, $metric_units, $metric_allocated) = @_;
  #item = database,filegroup,file
  #type log, rows oder nix
  my $factor = 1048576; # MB
  my $warning_units;
  my $critical_units;
  my $warning_pct;
  my $critical_pct;
  if ($self->opts->units ne "%") {
    if (uc $self->opts->units eq "GB") {
      $factor = 1024 * 1024 * 1024;
    } elsif (uc $self->opts->units eq "MB") {
     $factor = 1024 * 1024;
    } elsif (uc $self->opts->units eq "KB") {
     $factor = 1024;
    }
  }
  my $free_percent = 100 - 100 * $used_size / $max_size;
  my $allocated_percent = 100 * $size / $max_size;
  my $free_size = $max_size - $used_size;
  my $free_units = $free_size / $factor;
  if ($self->opts->units eq "%") {
    $self->set_thresholds(metric => $metric_pct, warning => "10:", critical => "5:");
    ($warning_pct, $critical_pct) = ($self->get_thresholds(metric => $metric_pct));
    ($warning_units, $critical_units) = map {
        # sonst schnippelt der von den originalen den : weg
        $_ =~ s/://g; (($_ * $max_size / 100) / $factor).":";
    } map { my $tmp = $_; $tmp; } ($warning_pct, $critical_pct);
    $self->set_thresholds(metric => $metric_units, warning => $warning_units, critical => $critical_units);
    $self->add_message($self->check_thresholds(metric => $metric_pct, value => $free_percent),
        sprintf("%s %s has %.2f%s free %sspace left", $item, $name, $free_percent, $self->opts->units, ($type eq "logs" ? "log " : "")));
  } else {
    $self->set_thresholds(metric => $metric_units, warning => "5:", critical => "10:");
    ($warning_units, $critical_units) = ($self->get_thresholds(metric => $metric_units));
    ($warning_pct, $critical_pct) = map {
        $_ =~ s/://g; (100 * ($_ * $factor) / $max_size).":";
    } map { my $tmp = $_; $tmp; } ($warning_units, $critical_units);
    $self->set_thresholds(metric => $metric_pct, warning => $warning_pct, critical => $critical_pct);
    $self->add_message($self->check_thresholds(metric => $metric_units, value => $free_units),
        sprintf("%s %s has %.2f%s free %sspace left", $item, $name, $free_units, $self->opts->units, ($type eq "logs" ? "log " : "")));
  }
  return ($free_percent, $free_size, $free_units, $allocated_percent, $factor);
}

package Classes::MSSQL::Component::DatabaseSubsystem::Database::Datafilegroup;
our @ISA = qw(Classes::MSSQL::Component::DatabaseSubsystem::Database);
use strict;

sub finish {
  my ($self, %params) = @_;
  %{$self->{filesystems}} = %{$Classes::MSSQL::Component::DatabaseSubsystem::filesystems};
  my @filesystems = keys %{$self->{filesystems}};
  $self->{full_name} = sprintf "%s::%s",
      $self->{database_name}, $self->{name};
  $self->{size} = 0;
  $self->{max_size} = 0;
  $self->{used_size} = 0;
  $self->{drive_reserve} = {};
  map { $self->{drive_reserve}->{$_} = 0; } keys %{$self->{filesystems}};
  # file1 E reserve 0          += max_size
  # file2 E reserve 100        += max_size    += drive_reserve (von E)   filesystems->E fliegt raus
  # file3 E reserve 100        += max_size    -= max_size, reserve(E) abziehen
  # file4 F reserve 0	       += max_size
  # file5 G reserve 1000       += max_size    += drive_reserve (von G)   filesystems->G fliegt raus
  foreach my $datafile (@{$self->{files}}) {
    $self->{size} += $datafile->{size};
    $self->{used_size} += $datafile->{used_size};
    $self->{max_size} += $datafile->{max_size};
    $self->{type} = $datafile->{type};
    if ($datafile->{drive_reserve}->{$datafile->{drive}}) {
      $self->{drive_reserve}->{$datafile->{drive}}++;
    }
  }
  my $ddsub = join " ", map { my $x = sprintf "%d*%s", $self->{drive_reserve}->{$_} - 1, $_; $x; } grep { $self->{drive_reserve}->{$_} > 1 } grep { $self->{drive_reserve}->{$_} } keys %{$self->{drive_reserve}};
  $self->{formula} = sprintf "g %15s msums %d (%dMB) %s", $self->{name}, $self->{max_size}, $self->{max_size} / 1048576, $ddsub ? " - (".$ddsub.")" : "";
  map {
    $self->{max_size} -= --$self->{drive_reserve}->{$_} * $self->{filesystems}->{$_};
    $self->{drive_reserve}->{$_} = 1;
  } grep {
    $self->{drive_reserve}->{$_};
  } @filesystems;
  $self->mbize();
}

sub check {
  my ($self) = @_;
  if ($self->mode =~ /server::database::datafree/ && $self->{type} eq "LOG") {
    return;
  } elsif ($self->mode =~ /server::database::logfree/ && $self->{type} ne "LOG") {
    return;
  }
  if ($self->mode =~ /server::database::filegroup::list$/) {
    printf "%s %s %d\n", $self->{database_name}, $self->{name}, scalar(@{$self->{files}});
  } elsif ($self->mode =~ /server::database::file::list/) {
    foreach (@{$self->{files}}) {
      $_->{database_name} = $self->{database_name};
      if ($self->filter_name2($_->{path})) {
        $_->check();
      }
    }
  } elsif ($self->mode =~ /server::database::(free|datafree|logfree)$/) {
    my $metric_pct = 'grp_'.lc $self->{full_name}.'_free_pct';
    my $metric_units = 'grp_'.lc $self->{full_name}.'_free';
    my $metric_allocated = 'grp_'.lc $self->{full_name}.'_allocated_pct';
    my ($free_percent, $free_size, $free_units, $allocated_percent, $factor) = $self->calc(
        "filegroup", $self->{full_name}, "",
        $self->{used_size}, $self->{size}, $self->{max_size},
        $metric_pct, $metric_units, $metric_allocated
    );
  } elsif ($self->mode =~ /server::database::filegroup::free$/ ||
      $self->mode =~ /server::database::(free|datafree|logfree)::details/) {
    my $metric_pct = 'grp_'.lc $self->{full_name}.'_free_pct';
    my $metric_units = 'grp_'.lc $self->{full_name}.'_free';
    my $metric_allocated = 'grp_'.lc $self->{full_name}.'_allocated_pct';
    my ($free_percent, $free_size, $free_units, $allocated_percent, $factor) = $self->calc(
        "filegroup", $self->{full_name}, "",
        $self->{used_size}, $self->{size}, $self->{max_size},
        $metric_pct, $metric_units, $metric_allocated
    );
    $self->add_perfdata(
        label => $metric_pct,
        value => $free_percent,
        places => 2,
        uom => '%',
    );
    $self->add_perfdata(
        label => $metric_units,
        value => $free_units,
        uom => $self->opts->units eq "%" ? "MB" : $self->opts->units,
        places => 2,
        min => 0,
        max => $self->{max_size} / $factor,
    );
    $self->add_perfdata(
        label => $metric_allocated,
        value => $allocated_percent,
        places => 2,
        uom => '%',
    );
  } elsif ($self->mode =~ /server::database::file::free$/) {
    foreach (@{$self->{files}}) {
      if ($self->filter_name3($_->{name})) {
        $_->check();
      }
    }
  }
}

package Classes::MSSQL::Component::DatabaseSubsystem::Database::Datafile;
our @ISA = qw(Classes::MSSQL::Component::DatabaseSubsystem::Database);
use strict;

sub finish {
  my ($self) = @_;
  %{$self->{filesystems}} = %{$Classes::MSSQL::Component::DatabaseSubsystem::filesystems};
  $self->{full_name} = sprintf "%s::%s::%s",
      $self->{database_name}, $self->{filegroup_name}, $self->{name};
  # 8k-pages, umrechnen in bytes
  $self->{size} *= 8*1024;
  $self->{used_size} ||= 0; # undef kommt vor, alles schon gesehen.
  $self->{used_size} *= 8*1024;
  $self->{max_size} =~ s/\.$//g;
  if ($self->{growth} == 0) {
    # ist schon am anschlag
    $self->{max_size} = $self->{size};
    $self->{drive_reserve}->{$self->{drive}} = 0;
    $self->{formula} = sprintf "f %15s fixed %d (%dMB)", $self->{name}, $self->{max_size}, $self->{max_size} / 1048576;
    $self->{growth_desc} = "fixed size";
  } else {
    if ($self->{max_size} == -1) {
      # kann unbegrenzt wachsen, bis das filesystem voll ist.
      $self->{max_size} = $self->{size} +
          (exists $self->{filesystems}->{$self->{drive}} ? $self->{filesystems}->{$self->{drive}} : 0);
      $self->{drive_reserve}->{$self->{drive}} = 1;
      $self->{formula} = sprintf "f %15s ulimt %d (%dMB)", $self->{name}, $self->{max_size}, $self->{max_size} / 1048576;
      $self->{growth_desc} = "unlimited size";
    } elsif ($self->{max_size} == 268435456) {
      $self->{max_size} = 2 * 1024 * 1024 * 1024 * 1024;
      $self->{formula} = sprintf "f %15s ulims %d (%dMB)", $self->{name}, $self->{max_size}, $self->{max_size} / 1048576;
      $self->{drive_reserve}->{$self->{drive}} = 0;
      $self->{growth_desc} = "limited to 2TB";
    } else {
      # hat eine obergrenze
      $self->{max_size} *= 8*1024;
      $self->{formula} = sprintf "f %15s  limt %d (%dMB)", $self->{name}, $self->{max_size}, $self->{max_size} / 1048576;
      $self->{drive_reserve}->{$self->{drive}} = 0;
      $self->{growth_desc} = "limited";
    }
  }
  $self->mbize();
}

sub check {
  my ($self) = @_;
  if ($self->mode =~ /server::database::file::list$/) {
    printf "%s %s %s %s\n", $self->{database_name}, $self->{filegroup_name}, $self->{name}, $self->{path};
  } elsif ($self->mode =~ /server::database::file::free$/) {
    my $metric_pct = 'file_'.lc $self->{full_name}.'_free_pct';
    my $metric_units = 'file_'.lc $self->{full_name}.'_free';
    my $metric_allocated = 'file_'.lc $self->{full_name}.'_allocated_pct';
    my ($free_percent, $free_size, $free_units, $allocated_percent, $factor) = $self->calc(
        "file", $self->{full_name}, "",
        $self->{used_size}, $self->{size}, $self->{max_size},
        $metric_pct, $metric_units, $metric_allocated
    );
    $self->add_perfdata(
        label => $metric_pct,
        value => $free_percent,
        places => 2,
        uom => '%',
    );
    $self->add_perfdata(
        label => $metric_units,
        value => $free_units,
        uom => $self->opts->units eq "%" ? "MB" : $self->opts->units,
        places => 2,
        min => 0,
        max => $self->{max_size} / $factor,
    );
    $self->add_perfdata(
        label => $metric_allocated,
        value => $allocated_percent,
        places => 2,
        uom => '%',
    );
  }
}

package Classes::MSSQL::Component::MemorypoolSubsystem::Buffercache;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /server::memorypool::buffercache::hitratio/) {
    # https://social.msdn.microsoft.com/Forums/sqlserver/en-US/263e847a-fd9d-4fbf-a8f0-2aed9565aca1/buffer-hit-ratio-over-100?forum=sqldatabaseengine
    $self->get_perf_counters([
        ['cnthitratio', 'SQLServer:Buffer Manager', 'Buffer cache hit ratio'],
        ['cnthitratiobase', 'SQLServer:Buffer Manager', 'Buffer cache hit ratio base'],
    ]);
    my $sql = q{
        SELECT
            (a.cntr_value * 1.0 / b.cntr_value) * 100.0 AS BufferCacheHitRatio
        FROM
            sys.dm_os_performance_counters  a
        JOIN  (
            SELECT
                cntr_value, OBJECT_NAME 
            FROM
                sys.dm_os_performance_counters  
            WHERE
                counter_name = 'Buffer cache hit ratio base'
            AND
                object_name = 'SQLServer:Buffer Manager'
        ) b
        ON
            a.OBJECT_NAME = b.OBJECT_NAME
        WHERE
            a.counter_name = 'Buffer cache hit ratio'
        AND
            a.OBJECT_NAME = 'SQLServer:Buffer Manager'
    };
    my $instance = $self->get_variable("servicename");
    $sql =~ s/SQLServer/$instance/g;
    $self->{buffer_cache_hit_ratio} = $self->fetchrow_array($sql);
    $self->protect_value('buffer_cache_hit_ratio', 'buffer_cache_hit_ratio', 'percent');
  } elsif ($self->mode =~ /server::memorypool::buffercache::lazywrites/) {
    $self->get_perf_counters([
        ['lazy_writes', 'SQLServer:Buffer Manager', 'Lazy writes/sec'],
    ]);
    # -> lazy_writes_per_sec
  } elsif ($self->mode =~ /server::memorypool::buffercache::pagelifeexpectancy/) {
    $self->get_perf_counters([
        ['page_life_expectancy', 'SQLServer:Buffer Manager', 'Page life expectancy'],
    ]);
  } elsif ($self->mode =~ /server::memorypool::buffercache::freeliststalls/) {
    $self->get_perf_counters([
        ['free_list_stalls', 'SQLServer:Buffer Manager', 'Free list stalls/sec'],
    ]);
  } elsif ($self->mode =~ /server::memorypool::buffercache::checkpointpages/) {
    $self->get_perf_counters([
        ['checkpoint_pages', 'SQLServer:Buffer Manager', 'Checkpoint pages/sec'],
    ]);
  }
}

sub check {
  my $self = shift;
  return if $self->check_messages();
  if ($self->mode =~ /server::memorypool::buffercache::hitratio/) {
    $self->set_thresholds(
        warning => '90:', critical => '80:'
    );
    $self->add_message(
        $self->check_thresholds($self->{buffer_cache_hit_ratio}),
        sprintf "buffer cache hit ratio is %.2f%%", $self->{buffer_cache_hit_ratio}
    );
    $self->add_perfdata(
        label => 'buffer_cache_hit_ratio',
        value => $self->{buffer_cache_hit_ratio},
        uom => '%',
    );
  } elsif ($self->mode =~ /server::memorypool::buffercache::lazywrites/) {
    $self->set_thresholds(
        warning => 20, critical => 40,
    );
    $self->add_message(
        $self->check_thresholds($self->{lazy_writes_per_sec}),
        sprintf "%.2f lazy writes per second", $self->{lazy_writes_per_sec}
    );
    $self->add_perfdata(
        label => 'lazy_writes_per_sec',
        value => $self->{lazy_writes_per_sec},
    );
  } elsif ($self->mode =~ /server::memorypool::buffercache::pagelifeexpectancy/) {
    $self->set_thresholds(
        warning => '300:', critical => '180:',
    );
    $self->add_message(
        $self->check_thresholds($self->{page_life_expectancy}),
        sprintf "page life expectancy is %d seconds", $self->{page_life_expectancy}
    );
    $self->add_perfdata(
        label => 'page_life_expectancy',
        value => $self->{page_life_expectancy},
    );
  } elsif ($self->mode =~ /server::memorypool::buffercache::freeliststalls/) {
    $self->set_thresholds(
        warning => '4', critical => '10',
    );
    $self->add_message(
        $self->check_thresholds($self->{free_list_stalls_per_sec}),
        sprintf "%.2f free list stalls per second", $self->{free_list_stalls_per_sec}
    );
    $self->add_perfdata(
        label => 'free_list_stalls_per_sec',
        value => $self->{free_list_stalls_per_sec},
    );
  } elsif ($self->mode =~ /server::memorypool::buffercache::checkpointpages/) {
    $self->set_thresholds(
        warning => '100', critical => '500',
    );
    $self->add_message(
        $self->check_thresholds($self->{checkpoint_pages_per_sec}),
        sprintf "%.2f pages flushed per second", $self->{checkpoint_pages_per_sec}
    );
    $self->add_perfdata(
        label => 'checkpoint_pages_per_sec',
        value => $self->{checkpoint_pages_per_sec},
    );
  }
}


package Classes::MSSQL::Component::MemorypoolSubsystem::Lock;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub check {
  my $self = shift;
  if ($self->mode =~ /server::memorypool::lock::waits/) {
    $self->get_perf_counters([
        ["waits", "SQLServer:Locks", "Lock Waits/sec", $self->{name}],
    ]);
    return if $self->check_messages();
    my $label = $self->{name}.'_waits_per_sec';
    $self->set_thresholds(
        metric => $label,
        warning => 100, critical => 500
    );
    $self->add_message($self->check_thresholds(
        metric => $label,
        value => $self->{waits_per_sec},
    ), sprintf "%.4f lock waits / sec for %s",
        $self->{waits_per_sec}, $self->{name}
    );
    $self->add_perfdata(
        label => $label,
        value => $self->{waits_per_sec},
    );
  } elsif ($self->mode =~ /^server::memorypool::lock::timeouts/) {
    $self->get_perf_counters([
        ["timeouts", "SQLServer:Locks", "Lock Timeouts/sec", $self->{name}],
    ]);
    return if $self->check_messages();
    my $label = $self->{name}.'_timeouts_per_sec';
    $self->set_thresholds(
        metric => $label,
        warning => 1, critical => 5
    );
    $self->add_message($self->check_thresholds(
        metric => $label,
        value => $self->{timeouts_per_sec},
    ), sprintf "%.4f lock timeouts / sec for %s",
        $self->{timeouts_per_sec}, $self->{name}
    );
    $self->add_perfdata(
        label => $label,
        value => $self->{timeouts_per_sec},
    );
  } elsif ($self->mode =~ /^server::memorypool::lock::deadlocks/) {
    $self->get_perf_counters([
        ["deadlocks", "SQLServer:Locks", "Number of Deadlocks/sec", $self->{name}],
    ]);
    return if $self->check_messages();
    my $label = $self->{name}.'_deadlocks_per_sec';
    $self->set_thresholds(
        metric => $label,
        warning => 1, critical => 5
    );
    $self->add_message($self->check_thresholds(
        metric => $label,
        value => $self->{deadlocks_per_sec},
    ), sprintf "%.4f lock deadlocks / sec for %s",
        $self->{deadlocks_per_sec}, $self->{name}
    );
    $self->add_perfdata(
        label => $label,
        value => $self->{deadlocks_per_sec},
    );
  }
}


package Classes::MSSQL::Component::MemorypoolSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::memorypool::lock/) {
    my $columns = ['name'];
    my @locks = $self->get_instance_names('SQLServer:Locks');
    @locks = map {
      "'".$_."'";
    } map {
      s/\s*$//g; $_;
    } map {
      $_->[0];
    } @locks;
    $sql = join(" UNION ALL ", map { "SELECT ".$_ } @locks);
    $self->get_db_tables([
        ['locks', $sql, 'Classes::MSSQL::Component::MemorypoolSubsystem::Lock', sub { my $o = shift; $self->filter_name($o->{name}) }, $columns],
    ]);      
  } elsif ($self->mode =~ /server::memorypool::buffercache/) {
    $self->analyze_and_check_buffercache_subsystem("Classes::MSSQL::Component::MemorypoolSubsystem::Buffercache");
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking memorypools');
  if ($self->mode =~ /server::memorypool::lock::listlocks$/) {
    foreach (@{$self->{locks}}) {
      printf "%s\n", $_->{name};
    }
    $self->add_ok("have fun");
  } else {
    $self->SUPER::check();
  }
}

package Classes::MSSQL::Component::JobSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::jobs::(failed|enabled|list)/) {
    $self->override_opt('lookback', 30) if ! $self->opts->lookback;
    if ($self->version_is_minimum("9.x")) {
      my $columns = ['id', 'name', 'now', 'minutessincestart', 'lastrundurationseconds', 'lastrundatetime', 'lastrunstatus', 'lastrunduration', 'lastrunstatusmessage', 'nextrundatetime'];
      my $sql = q{
            SELECT
                [sJOB].[job_id] AS [JobID],
                [sJOB].[name] AS [JobName],
                CURRENT_TIMESTAMP,  --can be used for debugging
                CASE
                    WHEN
                        [sJOBH].[run_date] IS NULL OR [sJOBH].[run_time] IS NULL
                    THEN
                        NULL
                    ELSE
                        DATEDIFF(Minute, CAST(CAST([sJOBH].[run_date] AS CHAR(8)) + ' ' +
                        STUFF(STUFF(RIGHT('000000' + CAST([sJOBH].[run_time] AS VARCHAR(6)),  6), 3, 0, ':'), 6, 0, ':') AS DATETIME), CURRENT_TIMESTAMP)
                END AS [MinutesSinceStart],
                CAST(SUBSTRING(RIGHT('00000000' + CAST([sJOBH].[run_duration] AS VARCHAR(8)), 8), 1, 4) AS INT) * 3600 +
                CAST(SUBSTRING(RIGHT('00000000' + CAST([sJOBH].[run_duration] AS VARCHAR(8)), 8), 5, 2) AS INT) * 60 +
                CAST(SUBSTRING(RIGHT('00000000' + CAST([sJOBH].[run_duration] AS VARCHAR(8)), 8), 7, 2) AS INT) AS LastRunDurationSeconds,
                CASE
                    WHEN
                        [sJOBH].[run_date] IS NULL OR [sJOBH].[run_time] IS NULL
                    THEN
                        NULL
                    ELSE
                        CAST(
                            CAST([sJOBH].[run_date] AS CHAR(8)) + ' ' +
                            STUFF(STUFF(RIGHT('000000' + CAST([sJOBH].[run_time] AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS DATETIME)
                END AS [LastRunDateTime],
                CASE [sJOBH].[run_status]
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Canceled'
                    WHEN 4 THEN 'Running' -- In Progress
                    ELSE 'DidNeverRun'
                END AS [LastRunStatus],
                STUFF(STUFF(RIGHT('00000000' + CAST([sJOBH].[run_duration] AS VARCHAR(8)), 8), 5, 0, ':'), 8, 0, ':') AS [LastRunDuration (HH:MM:SS)],
                [sJOBH].[message] AS [LastRunStatusMessage],
                CASE [sJOBSCH].[NextRunDate]
                    WHEN
                        0
                    THEN
                        NULL
                    ELSE
                        CAST(
                            CAST([sJOBSCH].[NextRunDate] AS CHAR(8)) + ' ' + STUFF(STUFF(RIGHT('000000' + CAST([sJOBSCH].[NextRunTime] AS VARCHAR(6)),  6), 3, 0, ':'), 6, 0, ':') AS DATETIME)
                END AS [NextRunDateTime]
            FROM
                [msdb].[dbo].[sysjobs] AS [sJOB]
                LEFT JOIN (
                    SELECT
                        [job_id],
                        MIN([next_run_date]) AS [NextRunDate],
                        MIN([next_run_time]) AS [NextRunTime]
                    FROM
                        [msdb].[dbo].[sysjobschedules]
                    GROUP BY
                        [job_id]
                ) AS [sJOBSCH]
                ON
                    [sJOB].[job_id] = [sJOBSCH].[job_id]
                LEFT JOIN (
                    SELECT
                        [job_id],
                        [run_date],
                        [run_time],
                        [run_status],
                        [run_duration],
                        [message],
                        ROW_NUMBER()
                        OVER (
                            PARTITION BY [job_id]
                            ORDER BY [run_date] DESC, [run_time] DESC
                        ) AS RowNumber
                    FROM
                        [msdb].[dbo].[sysjobhistory]
                    WHERE
                        [step_id] = 0
                ) AS [sJOBH]
                ON
                    [sJOB].[job_id] = [sJOBH].[job_id]
                AND
                    [sJOBH].[RowNumber] = 1
            ORDER BY
                [JobName]
      };
      $self->get_db_tables([
          ['jobs', $sql, 'Classes::MSSQL::Component::JobSubsystem::Job', sub { $self->opts->lookback;my $o = shift; $self->filter_name($o->{name}) && (! defined $o->{minutessincestart} || $o->{minutessincestart} <= $self->opts->lookback);  }, $columns],
      ]);      
@{$self->{jobs}} = reverse @{$self->{jobs}};
    }
  } else {
    $self->no_such_mode();
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking jobs');
  if ($self->mode =~ /server::jobs::listjobs/) {
    foreach (@{$self->{jobs}}) {
      printf "%s\n", $_->{name};
    }
    $self->add_ok("have fun");
  } else {
    $self->SUPER::check();
    if (scalar @{$self->{jobs}} == 0) {
      $self->add_ok(sprintf "no jobs ran within the last %d minutes", $self->opts->lookback);
    }
  }
}

package Classes::MSSQL::Component::JobSubsystem::Job;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub check {
  my $self = shift;
  if ($self->mode =~ /server::jobs::failed/) {
    if (! defined $self->{lastrundatetime}) {
      $self->add_ok(sprintf "%s did never run", $self->{name});
    } elsif ($self->{lastrunstatus} eq "Failed") {
      $self->add_critical(sprintf "%s failed at %s: %s",
          $self->{name}, $self->{lastrundatetime},
          $self->{lastrunstatusmessage});
    } elsif ($self->{lastrunstatus} eq "Retry" || $self->{lastrunstatus} eq "Canceled") {
      $self->add_warning(sprintf "%s %s: %s",
          $self->{name}, $self->{lastrunstatus}, $self->{lastrunstatusmessage});
    } else {
      my $label = 'job_'.$self->{name}.'_runtime';
      $self->set_thresholds(
          metric => $label,
          warning => 60,
          critical => 300,
      );
      $self->add_message(
          $self->check_thresholds(metric => $label, value => $self->{lastrundurationseconds}),
              sprintf("job %s ran for %d seconds (started %s)", $self->{name}, 
              $self->{lastrundurationseconds}, $self->{lastrundatetime})
      );
      $self->add_perfdata(
          label => $label,
          value => $self->{lastrundurationseconds},
          uom => 's',
      );
    }
  } elsif ($self->mode =~ /server::jobs::enabled/) {
    if (! defined $self->{nextrundatetime}) {
      $self->add_critical(sprintf "%s is not enabled",
          $self->{name});
    } else {
      $self->add_ok(sprintf "job %s will run at %s",
          $self->{name},  $self->{nextrundatetime});
    }
  }
}

package Classes::MSSQL::Sqlrelay;
our @ISA = qw(Classes::MSSQL Classes::Sybase::Sqlrelay);
use strict;
package Classes::MSSQL::Sqsh;
our @ISA = qw(Classes::MSSQL Classes::Sybase::Sqsh);
use strict;
package Classes::MSSQL::DBI;
our @ISA = qw(Classes::MSSQL Classes::Sybase::DBI);
use strict;
package Classes::MSSQL;
our @ISA = qw(Classes::Sybase);

use strict;
use Time::HiRes;
use IO::File;
use File::Copy 'cp';
use Data::Dumper;
our $AUTOLOAD;


sub init {
  my $self = shift;
  $self->set_variable("dbuser", $self->fetchrow_array(
      q{ SELECT SYSTEM_USER }
  ));
  $self->set_variable("servicename", $self->fetchrow_array(
      q{ SELECT @@SERVICENAME }
  ));
  if (lc $self->get_variable("servicename") ne 'mssqlserver') {
    # braucht man fuer abfragen von dm_os_performance_counters
    # object_name ist entweder "SQLServer:Buffer Node" oder z.b. "MSSQL$OASH:Buffer Node"
    $self->set_variable("servicename", 'MSSQL$'.$self->get_variable("servicename"));
  } else {
    $self->set_variable("servicename", 'SQLServer');
  }
  $self->set_variable("ishadrenabled", $self->fetchrow_array(
      q{ SELECT CAST(COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0) as int) }
  ));
  if ($self->mode =~ /^server::connectedusers/) {
    my $connectedusers;
    if ($self->get_variable("product") eq "ASE") {
      $connectedusers = $self->fetchrow_array(q{
        SELECT
          COUNT(*)
        FROM
          master..sysprocesses
        WHERE
          hostprocess IS NOT NULL AND program_name != 'JS Agent'
      });
    } else {
      # http://www.sqlservercentral.com/articles/System+Tables/66335/
      # user processes start at 51
      $connectedusers = $self->fetchrow_array(q{
        SELECT
          COUNT(*)
        FROM
          master..sysprocesses
        WHERE
          spid >= 51
      });
    }
    if (! defined $connectedusers) {
      $self->add_unknown("unable to count connected users");
    } else {
      $self->set_thresholds(warning => 50, critical => 80);
      $self->add_message($self->check_thresholds($connectedusers),
          sprintf "%d connected users", $connectedusers);
      $self->add_perfdata(
          label => "connected_users",
          value => $connectedusers
      );
    }
  } elsif ($self->mode =~ /^server::cpubusy/) {
    if ($self->version_is_minimum("9.x")) {
      if (! defined ($self->{secs_busy} = $self->fetchrow_array(q{
          SELECT ((@@CPU_BUSY * CAST(@@TIMETICKS AS FLOAT)) /
              (SELECT CAST(CPU_COUNT AS FLOAT) FROM sys.dm_os_sys_info) /
              1000000)
      }))) {
        $self->add_unknown("got no cputime from dm_os_sys_info");
      } else {
        $self->valdiff({ name => 'secs_busy' }, qw(secs_busy));
        $self->{cpu_busy} = 100 *
            $self->{delta_secs_busy} / $self->{delta_timestamp};
        $self->protect_value('cpu_busy', 'cpu_busy', 'percent');
      }
    } else {
      my @monitor = $self->exec_sp_1hash(q{exec sp_monitor});
      foreach (@monitor) {
        if ($_->[0] eq 'cpu_busy') {
          if ($_->[1] =~ /(\d+)%/) {
            $self->{cpu_busy} = $1;
          }
        }
      }
      self->requires_version('9') unless defined $self->{cpu_busy};
    }
    if (! $self->check_messages()) {
      $self->set_thresholds(warning => 80, critical => 90);
      $self->add_message($self->check_thresholds($self->{cpu_busy}),
          sprintf "CPU busy %.2f%%", $self->{cpu_busy});
      $self->add_perfdata(
          label => 'cpu_busy',
          value => $self->{cpu_busy},
          uom => '%',
      );
    }
  } elsif ($self->mode =~ /^server::iobusy/) {
    if ($self->version_is_minimum("9.x")) {
      if (! defined ($self->{secs_busy} = $self->fetchrow_array(q{
          SELECT ((@@IO_BUSY * CAST(@@TIMETICKS AS FLOAT)) /
              (SELECT CAST(CPU_COUNT AS FLOAT) FROM sys.dm_os_sys_info) /
              1000000)
      }))) {
        $self->add_unknown("got no iotime from dm_os_sys_info");
      } else {
        $self->valdiff({ name => 'secs_busy' }, qw(secs_busy));
        $self->{io_busy} = 100 *
            $self->{delta_secs_busy} / $self->{delta_timestamp};
        $self->protect_value('io_busy', 'io_busy', 'percent');
      }
    } else {
      my @monitor = $self->exec_sp_1hash(q{exec sp_monitor});
      foreach (@monitor) {
        if ($_->[0] eq 'io_busy') {
          if ($_->[1] =~ /(\d+)%/) {
            $self->{io_busy} = $1;
          }
        }
      }
      self->requires_version('9') unless defined $self->{io_busy};
    }
    if (! $self->check_messages()) {
      $self->set_thresholds(warning => 80, critical => 90);
      $self->add_message($self->check_thresholds($self->{io_busy}),
          sprintf "IO busy %.2f%%", $self->{io_busy});
      $self->add_perfdata(
          label => 'io_busy',
          value => $self->{io_busy},
          uom => '%',
      );
    }
  } elsif ($self->mode =~ /^server::fullscans/) {
    $self->get_perf_counters([
        ['full_scans', 'SQLServer:Access Methods', 'Full Scans/sec'],
    ]);
    return if $self->check_messages();
    $self->set_thresholds(
        metric => 'full_scans_per_sec',
        warning => 100, critical => 500);
    $self->add_message(
        $self->check_thresholds(
            metric => 'full_scans_per_sec',
            value => $self->{full_scans_per_sec}),
        sprintf "%.2f full table scans / sec", $self->{full_scans_per_sec});
    $self->add_perfdata(
        label => 'full_scans_per_sec',
        value => $self->{full_scans_per_sec},
    );
  } elsif ($self->mode =~ /^server::latch::waittime/) {
    $self->get_perf_counters([
        ['latch_avg_wait_time', 'SQLServer:Latches', 'Average Latch Wait Time (ms)'],
        ['latch_wait_time_base', 'SQLServer:Latches', 'Average Latch Wait Time Base'],
    ]);
    return if $self->check_messages();
    $self->{latch_avg_wait_time} = $self->{latch_avg_wait_time} / $self->{latch_wait_time_base};
    $self->set_thresholds(
        metric => 'latch_avg_wait_time',
        warning => 1, critical => 5);
    $self->add_message(
        $self->check_thresholds(
            metric => 'latch_avg_wait_time',
            value => $self->{latch_avg_wait_time}),
        sprintf "latches have to wait %.2f ms avg", $self->{latch_avg_wait_time});
    $self->add_perfdata(
        label => 'latch_avg_wait_time',
        value => $self->{latch_avg_wait_time},
        uom => 'ms',
    );
  } elsif ($self->mode =~ /^server::latch::waits/) {
    $self->get_perf_counters([
        ['latch_waits', 'SQLServer:Latches', 'Latch Waits/sec'],
    ]);
    return if $self->check_messages();
    $self->set_thresholds(
        metric => 'latch_waits_per_sec',
        warning => 10, critical => 50);
    $self->add_message(
        $self->check_thresholds(
            metric => 'latch_waits_per_sec',
            value => $self->{latch_waits_per_sec}),
        sprintf "%.2f latches / sec have to wait", $self->{latch_waits_per_sec});
    $self->add_perfdata(
        label => 'latch_waits_per_sec',
        value => $self->{latch_waits_per_sec},
    );
  } elsif ($self->mode =~ /^server::sql.*compilations/) {
    $self->get_perf_counters([
        ['sql_recompilations', 'SQLServer:SQL Statistics', 'SQL Re-Compilations/sec'],
        ['sql_compilations', 'SQLServer:SQL Statistics', 'SQL Compilations/sec'],
    ]);
    return if $self->check_messages();
    # http://www.sqlmag.com/Articles/ArticleID/40925/pg/3/3.html
    # http://www.grumpyolddba.co.uk/monitoring/Performance%20Counter%20Guidance%20-%20SQL%20Server.htm
    if ($self->mode =~ /^server::sql::recompilations/) {
      $self->set_thresholds(
          metric => 'sql_recompilations_per_sec',
          warning => 1, critical => 10);
      $self->add_message(
          $self->check_thresholds(
              metric => 'sql_recompilations_per_sec',
              value => $self->{sql_recompilations_per_sec}),
          sprintf "%.2f SQL recompilations / sec", $self->{sql_recompilations_per_sec});
      $self->add_perfdata(
          label => 'sql_recompilations_per_sec',
          value => $self->{sql_recompilations_per_sec},
      );
    } else { # server::sql::initcompilations
      # ginge auch (weiter oben, mit sql_initcompilations im valdiff), birgt aber gefahren. warum? denksport
      # $self->{sql_initcompilations} = $self->{sql_compilations} - $self->{sql_recompilations};
      # $self->protect_value("sql_initcompilations", "sql_initcompilations", "positive");
      $self->{delta_sql_initcompilations} = $self->{delta_sql_compilations} - $self->{delta_sql_recompilations};
      $self->{sql_initcompilations_per_sec} = $self->{delta_sql_initcompilations} / $self->{delta_timestamp};
      $self->set_thresholds(
          metric => 'sql_initcompilations_per_sec',
          warning => 100, critical => 200);
      $self->add_message(
          $self->check_thresholds(
              metric => 'sql_initcompilations_per_sec',
              value => $self->{sql_initcompilations_per_sec}),
          sprintf "%.2f initial compilations / sec", $self->{sql_initcompilations_per_sec});
      $self->add_perfdata(
          label => 'sql_initcompilations_per_sec',
          value => $self->{sql_initcompilations_per_sec},
      );
    }
  } elsif ($self->mode =~ /^server::batchrequests/) {
    $self->get_perf_counters([
        ['batch_requests', 'SQLServer:SQL Statistics', 'Batch Requests/sec'],
    ]);
    return if $self->check_messages();
    $self->set_thresholds(
        metric => 'batch_requests_per_sec',
        warning => 100, critical => 200);
    $self->add_message(
        $self->check_thresholds(
            metric => 'batch_requests_per_sec',
            value => $self->{batch_requests_per_sec}),
        sprintf "%.2f batch requests / sec", $self->{batch_requests_per_sec});
    $self->add_perfdata(
        label => 'batch_requests_per_sec',
        value => $self->{batch_requests_per_sec},
    );
  } elsif ($self->mode =~ /^server::totalmemory/) {
    $self->get_perf_counters([
        ['total_server_memory', 'SQLServer:Memory Manager', 'Total Server Memory (KB)'],
    ]);
    return if $self->check_messages();
    my $warn = 1024*1024;
    my $crit = 1024*1024*5;
    my $factor = 1;
    if ($self->opts->units && lc $self->opts->units eq "mb") {
      $warn = 1024;
      $crit = 1024*5;
      $factor = 1024;
    } elsif ($self->opts->units && lc $self->opts->units eq "gb") {
      $warn = 1;
      $crit = 1*5;
      $factor = 1024*1024;
    } else {
      $self->override_opt("units", "kb");
    }
    $self->{total_server_memory} /= $factor;
    $self->set_thresholds(
        metric => 'total_server_memory',
        warning => $warn, critical => $crit);
    $self->add_message(
        $self->check_thresholds(
            metric => 'total_server_memory',
            value => $self->{total_server_memory}),
        sprintf "total server memory %.2f%s", $self->{total_server_memory}, $self->opts->units);
    $self->add_perfdata(
        label => 'total_server_memory',
        value => $self->{total_server_memory},
        uom => $self->opts->units,
    );
  } elsif ($self->mode =~ /^server::memorypool/) {
    $self->analyze_and_check_memorypool_subsystem("Classes::MSSQL::Component::MemorypoolSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::database/) {
    $self->analyze_and_check_database_subsystem("Classes::MSSQL::Component::DatabaseSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::availabilitygroup/) {
    $self->analyze_and_check_avgroup_subsystem("Classes::MSSQL::Component::AvailabilitygroupSubsystem");
    $self->reduce_messages_short();
  } elsif ($self->mode =~ /^server::jobs/) {
    $self->analyze_and_check_job_subsystem("Classes::MSSQL::Component::JobSubsystem");
    $self->reduce_messages_short();
  } else {
    $self->no_such_mode();
  }
}

sub get_perf_counters {
  my $self = shift;
  my $counters = shift;
  my @vars = ();
  foreach (@{$counters}) {
    my $var = $_->[0];
    push(@vars, $_->[3] ? $var.'_'.$_->[3] : $var);
    my $object_name = $_->[1];
    my $counter_name = $_->[2];
    my $instance_name = $_->[3];
    $self->{$var} = $self->get_perf_counter(
        $object_name, $counter_name, $instance_name
    );
    $self->add_unknown(sprintf "unable to aquire counter data %s %s%s",
        $object_name, $counter_name,
        $instance_name ? " (".$instance_name.")" : ""
    ) if ! defined $self->{$var};
    $self->valdiff({ name => $instance_name ? $var.'_'.$instance_name : $var }, $var) if $var;
  }
}

sub get_perf_counter {
  my $self = shift;
  my $object_name = shift;
  my $counter_name = shift;
  my $instance_name = shift;
  my $sql;
  if ($object_name =~ /SQLServer:(.*)/) {
    $object_name = $self->get_variable("servicename").':'.$1;
  }
  if ($self->version_is_minimum("9.x")) {
    $sql = q{
        SELECT
            cntr_value
        FROM
            sys.dm_os_performance_counters
        WHERE
            counter_name = ? AND
            object_name = ?
    };
  } else {
    $sql = q{
        SELECT
            cntr_value
        FROM
            master.dbo.sysperfinfo
        WHERE
            counter_name = ? AND
            object_name = ?
    };
  }
  if ($instance_name) {
    $sql .= " AND instance_name = ?";
    return $self->fetchrow_array($sql, $counter_name, $object_name, $instance_name);
  } else {
    return $self->fetchrow_array($sql, $counter_name, $object_name);
  }
}

sub get_perf_counter_instance {
  my $self = shift;
  my $object_name = shift;
  my $counter_name = shift;
  my $instance_name = shift;
  if ($object_name =~ /SQLServer:(.*)/) {
    $object_name = $self->get_variable("servicename").':'.$1;
  }
  if ($self->version_is_minimum("9.x")) {
    return $self->fetchrow_array(q{
        SELECT
            cntr_value
        FROM
            sys.dm_os_performance_counters
        WHERE
            counter_name = ? AND
            object_name = ? AND
            instance_name = ?
    }, $counter_name, $object_name, $instance_name);
  } else {
    return $self->fetchrow_array(q{
        SELECT
            cntr_value
        FROM
            master.dbo.sysperfinfo
        WHERE
            counter_name = ? AND
            object_name = ? AND
            instance_name = ?
    }, $counter_name, $object_name, $instance_name);
  }
}

sub get_instance_names {
  my $self = shift;
  my $object_name = shift;
  if ($object_name =~ /SQLServer:(.*)/) {
    $object_name = $self->get_variable("servicename").':'.$1;
  }
  if ($self->version_is_minimum("9.x")) {
    return $self->fetchall_array(q{
        SELECT
            DISTINCT instance_name
        FROM
            sys.dm_os_performance_counters
        WHERE
            object_name = ?
    }, $object_name);
  } else {
    return $self->fetchall_array(q{
        SELECT
            DISTINCT instance_name
        FROM
            master.dbo.sysperfinfo
        WHERE
            object_name = ?
    }, $object_name);
  }
}

sub has_threshold_table {
  my $self = shift;
  if (! exists $self->{has_threshold_table}) {
    my $find_sql;
    if ($self->version_is_minimum("9.x")) {
      $find_sql = q{
          SELECT name FROM sys.objects
          WHERE name = 'check_mssql_health_thresholds'
      };
    } else {
      $find_sql = q{
          SELECT name FROM sysobjects
          WHERE name = 'check_mssql_health_thresholds'
      };
    }
    if ($self->{handle}->fetchrow_array($find_sql)) {
      $self->{has_threshold_table} = 'check_mssql_health_thresholds';
    } else {
      $self->{has_threshold_table} = undef;
    }
  }
  return $self->{has_threshold_table};
}

sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs() if $self->SUPER::can('add_dbi_funcs');
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::get_instance_names'} = \&{"Classes::MSSQL::get_instance_names"};
    *{'Monitoring::GLPlugin::DB::get_perf_counters'} = \&{"Classes::MSSQL::get_perf_counters"};
    *{'Monitoring::GLPlugin::DB::get_perf_counter'} = \&{"Classes::MSSQL::get_perf_counter"};
    *{'Monitoring::GLPlugin::DB::get_perf_counter_instance'} = \&{"Classes::MSSQL::get_perf_counter_instance"};
  }
}

sub compatibility_class {
  my $self = shift;
  # old extension packages inherit from DBD::MSSQL::Server
  # let DBD::MSSQL::Server inherit myself, so we can reach compatibility_methods
  {
    no strict 'refs';
    *{'DBD::MSSQL::Server::new'} = sub {};
    push(@DBD::MSSQL::Server::ISA, ref($self));
  }
}

sub compatibility_methods {
  my $self = shift;
  if ($self->isa("DBD::MSSQL::Server")) {
    # a old-style extension was loaded
    $self->SUPER::compatibility_methods() if $self->SUPER::can('compatibility_methods');
  }
}

package Classes::ASE::Component::DatabaseSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub filter_all {
  my $self = shift;
}

sub init {
  my $self = shift;
  my $sql = undef;
  my $allfilter = sub {
    my $o = shift;
    $self->filter_name($o->{name}) && 
        ! (($self->opts->notemp && $o->is_temp) || ($self->opts->nooffline && ! $o->is_online));
  };
  if ($self->mode =~ /server::database::(createuser|listdatabases|databasefree)$/) {
    my $columns = ['name', 'state', 'rows_max_size', 'rows_used_size', 'log_max_size', 'log_used_size'];
    my $sql = q{
      SELECT
          db_name(d.dbid) AS name,
          d.status2 AS state,
          SUM(
              CASE WHEN u.segmap != 4
              THEN u.size/1048576.*@@maxpagesize
              END
          ) AS data_size,
          SUM(
              CASE WHEN u.segmap != 4
              THEN size - curunreservedpgs(u.dbid, u.lstart, u.unreservedpgs)
              END
          ) / 1048576. * @@maxpagesize AS data_used,
          SUM(
              CASE WHEN u.segmap = 4
              THEN u.size/1048576.*@@maxpagesize
              END
          ) AS log_size,
          SUM(
              CASE WHEN u.segmap = 4
              THEN u.size/1048576.*@@maxpagesize
              END
          ) - 
          lct_admin("logsegment_freepages", d.dbid) / 1048576. * @@maxpagesize AS log_used
      FROM
          master..sysdatabases d, master..sysusages u
      WHERE
          u.dbid = d.dbid AND d.status != 256
      GROUP BY
          d.dbid
      ORDER BY
          db_name(d.dbid)
    };
    $self->get_db_tables([
        ['databases', $sql, 'Classes::ASE::Component::DatabaseSubsystem::Database', $allfilter, $columns],
    ]);
    @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
  } elsif ($self->mode =~ /server::database::online/) {
    my $columns = ['name', 'state', 'state_desc', 'collation_name'];
    $sql = q{
      SELECT name, state, state_desc, collation_name FROM master.sys.databases
    };
    $self->get_db_tables([
        ['databases', $sql, 'Classes::ASE::Component::DatabaseSubsystem::Database', $allfilter, $columns],
    ]);
    @{$self->{databases}} =  reverse sort {$a->{name} cmp $b->{name}} @{$self->{databases}};
  } elsif ($self->mode =~ /server::database::.*backupage/) {
    my $columns = ['name', 'id'];
    $sql = q{
      SELECT name, dbid FROM master..sysdatabases
    };
    $self->get_db_tables([
        ['databases', $sql, 'Classes::ASE::Component::DatabaseSubsystem::DatabaseStub', $allfilter, $columns],
    ]);
    foreach (@{$self->{databases}}) {
      bless $_, 'Classes::ASE::Component::DatabaseSubsystem::Database';
      $_->finish();
    }
  } else {
    $self->no_such_mode();
  }
}


package Classes::ASE::Component::DatabaseSubsystem::DatabaseStub;
our @ISA = qw(Classes::ASE::Component::DatabaseSubsystem::Database);
use strict;

sub finish {
  my $self = shift;
  my $sql = sprintf q{
      DBCC TRACEON(3604)
      DBCC DBTABLE("%s")
  }, $self->{name};
  my @dbccresult = $self->fetchall_array($sql);
  foreach (@dbccresult) {
    #dbt_backup_start: 0x1686303d8 (dtdays=40599, dttime=7316475)    Feb 27 2011  6:46:28:250AM
    if (/dbt_backup_start: \w+\s+\(dtdays=0, dttime=0\) \(uninitialized\)/) {
      # never backed up
      last;
    } elsif (/dbt_backup_start: \w+\s+\(dtdays=\d+, dttime=\d+\)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+):(\d+):(\d+):\d+([AP])/) {
      require Time::Local;
      my %months = ("Jan" => 0, "Feb" => 1, "Mar" => 2, "Apr" => 3, "May" => 4, "Jun" => 5, "Jul" => 6, "Aug" => 7, "Sep" => 8, "Oct" => 9, "Nov" => 10, "Dec" => 11);
      $self->{backup_age} = (time - Time::Local::timelocal($6, $5, $4 + ($7 eq "A" ? 0 : 12), $2, $months{$1}, $3 - 1900)) / 3600;
      $self->{backup_duration} = 0;
      last;
    }
  }
  # to keep compatibility with mssql. recovery_model=3=simple will be skipped later
  $self->{recovery_model} = 0;
}

package Classes::ASE::Component::DatabaseSubsystem::Database;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  if ($self->mode =~ /server::database::databasefree$/) {
    $self->{log_max_size} = 0 if ! defined $self->{log_max_size};
    $self->{log_used_size} = 0 if ! defined $self->{log_used_size};
    $self->{rows_max_size} *= 1024*1024;
    $self->{rows_used_size} *= 1024*1024;
    $self->{log_max_size} *= 1024*1024;
    $self->{log_used_size} *= 1024*1024;
    $self->{rows_used_pct} = 100 * $self->{rows_used_size} / $self->{rows_max_size};
    $self->{log_used_pct} = $self->{log_used_size} ? 100 * $self->{log_used_size} / $self->{log_max_size} : 0;
    $self->{rows_free_size} = $self->{rows_max_size} - $self->{rows_used_size};
    $self->{log_free_size} = $self->{log_max_size} - $self->{log_used_size};
  }
}

sub is_backup_node {
  my $self = shift;
  # to be done
  return 0;
}

sub is_online {
  my $self = shift;
  return 0 if $self->{messages}->{critical} && grep /is offline/, @{$self->{messages}->{critical}};
  # 0x0010 offline
  # 0x0020 offline until recovery completes
  return $self->{state} & 0x0030 ? 0 : 1;
}

sub is_problematic {
  my $self = shift;
  if ($self->{messages}->{critical}) {
    my $error = join(", ", @{$self->{messages}->{critical}});
    if ($error =~ /Message String: ([\w ]+)/) {
      return $1;
    } else {
      return $error;
    }
  } else {
    return 0;
  }
}

sub is_readable {
  my $self = shift;
  return ($self->{messages}->{critical} && grep /is not able to access the database/i, @{$self->{messages}->{critical}}) ? 0 : 1;
}

sub is_temp {
  my $self = shift;
  return $self->{name} eq "tempdb" ? 1 : 0;
}


sub check {
  my $self = shift;
  if ($self->mode =~ /server::database::(listdatabases)$/) {
    printf "%s\n", $self->{name};
  } elsif ($self->mode =~ /server::database::(databasefree)$/) {
    $self->override_opt("units", "%") if ! $self->opts->units;
    if (! $self->is_online) {
      # offlineok hat vorrang
      $self->override_opt("mitigation", $self->opts->offlineok ? 0 : $self->opts->mitigation ? $self->opts->mitigation : 1);
      $self->add_message($self->opts->mitigation,
          sprintf("database %s is not online", $self->{name})
      );
    } elsif (! $self->is_readable) {
      $self->add_message($self->opts->mitigation ? $self->opts->mitigation : 1,
          sprintf("insufficient privileges to access %s", $self->{name})
      );
    } elsif ($self->is_problematic) {
      $self->add_message($self->opts->mitigation ? $self->opts->mitigation : 1,
          sprintf("error accessing %s: %s", $self->{name}, $self->is_problematic)
      );
    } else {
      foreach my $type (qw(rows log)) {
        next if ! defined $self->{$type."_max_size"}; # not every db has a separate log
        my $metric_pct = ($type eq "rows") ?
            'db_'.lc $self->{name}.'_free_pct' : 'db_'.lc $self->{name}.'_log_free_pct';
        my $metric_units = ($type eq "rows") ? 
            'db_'.lc $self->{name}.'_free' : 'db_'.lc $self->{name}.'_log_free';
        my $factor = 1048576; # MB
        my $warning_units;
        my $critical_units;
        my $warning_pct;
        my $critical_pct;
        if ($self->opts->units ne "%") {
          if (uc $self->opts->units eq "GB") {
            $factor = 1024 * 1024 * 1024;
          } elsif (uc $self->opts->units eq "MB") {
            $factor = 1024 * 1024;
          } elsif (uc $self->opts->units eq "KB") {
            $factor = 1024;
          }
        }
        my $free_percent = 100 - $self->{$type."_used_pct"};
        my $free_size = $self->{$type."_max_size"} - $self->{$type."_used_size"};
        my $free_units = $free_size / $factor;
        if ($self->opts->units eq "%") {
          $self->set_thresholds(metric => $metric_pct, warning => "10:", critical => "5:");
          ($warning_pct, $critical_pct) = ($self->get_thresholds(metric => $metric_pct));
          ($warning_units, $critical_units) = map { 
              $_ =~ s/://g; (($_ * $self->{$type."_max_size"} / 100) / $factor).":";
          } map { my $tmp = $_; $tmp; } ($warning_pct, $critical_pct); # sonst schnippelt der von den originalen den : weg
          $self->set_thresholds(metric => $metric_units, warning => $warning_units, critical => $critical_units);
          $self->add_message($self->check_thresholds(metric => $metric_pct, value => $free_percent),
              sprintf("database %s has %.2f%s free %sspace left", $self->{name}, $free_percent, $self->opts->units, ($type eq "log" ? "log " : "")));
        } else {
          $self->set_thresholds(metric => $metric_units, warning => "5:", critical => "10:");
          ($warning_units, $critical_units) = ($self->get_thresholds(metric => $metric_units));
          ($warning_pct, $critical_pct) = map { 
              $_ =~ s/://g; (100 * ($_ * $factor) / $self->{$type."_max_size"}).":";
          } map { my $tmp = $_; $tmp; } ($warning_units, $critical_units);
          $self->set_thresholds(metric => $metric_pct, warning => $warning_pct, critical => $critical_pct);
          $self->add_message($self->check_thresholds(metric => $metric_units, value => $free_units),
              sprintf("database %s has %.2f%s free %sspace left", $self->{name}, $free_units, $self->opts->units, ($type eq "log" ? "log " : "")));
        }
        $self->add_perfdata(
            label => $metric_pct,
            value => $free_percent,
            places => 2,
            uom => '%',
            warning => $warning_pct,
            critical => $critical_pct,
        );
        $self->add_perfdata(
            label => $metric_units,
            value => $free_size / $factor,
            uom => $self->opts->units eq "%" ? "MB" : $self->opts->units,
            places => 2,
            warning => $warning_units,
            critical => $critical_units,
            min => 0,
            max => $self->{$type."_max_size"} / $factor,
        );
      }
    }
  } elsif ($self->mode =~ /server::database::online/) {
    if ($self->is_online) {
      if ($self->{collation_name}) {
        $self->add_ok(
          sprintf "%s is %s and accepting connections", $self->{name}, $self->{state_desc});
      } else {
        $self->add_warning(sprintf "%s is %s but not accepting connections",
            $self->{name}, $self->{state_desc});
      }
    } elsif ($self->{state_desc} =~ /^recover/i) {
      $self->add_warning(sprintf "%s is %s", $self->{name}, $self->{state_desc});
    } else {
      $self->add_critical(sprintf "%s is %s", $self->{name}, $self->{state_desc});
    }
  } elsif ($self->mode =~ /server::database::.*backupage/) {
    if (! $self->is_backup_node) {
      $self->add_ok(sprintf "this is not the preferred replica for backups of %s", $self->{name});
      return;
    }
    my $log = "";
    if ($self->mode =~ /server::database::logbackupage/) {
      $log = "log of ";
    }
    if ($self->mode =~ /server::database::logbackupage/ && $self->{recovery_model} == 3) {
      $self->add_ok(sprintf "%s has no logs", $self->{name});
    } else {
      $self->set_thresholds(metric => $self->{name}.'_bck_age', warning => 48, critical => 72);
      if (! defined $self->{backup_age}) {
        $self->add_message(defined $self->opts->mitigation() ? $self->opts->mitigation() : 2,
            sprintf "%s%s was never backed up", $log, $self->{name});
        $self->{backup_age} = 0;
        $self->{backup_duration} = 0;
      } else {
        $self->add_message(
            $self->check_thresholds(metric => $self->{name}.'_bck_age', value => $self->{backup_age}),
            sprintf "%s%s was backed up %dh ago", $log, $self->{name}, $self->{backup_age});
      }
      $self->add_perfdata(
          label => $self->{name}.'_bck_age',
          value => $self->{backup_age},
      );
      $self->add_perfdata(
          label => $self->{name}.'_bck_time',
          value => $self->{backup_duration},
      );
    }
  }
}


package Classes::ASE::Sqlrelay;
our @ISA = qw(Classes::ASE Classes::Sybase::Sqlrelay);
use strict;
package Classes::ASE::Sqsh;
our @ISA = qw(Classes::ASE Classes::Sybase::Sqsh);
use strict;
package Classes::ASE::DBI;
our @ISA = qw(Classes::ASE Classes::Sybase::DBI);
use strict;
package Classes::ASE;
our @ISA = qw(Classes::Sybase);

use strict;
use Time::HiRes;
use IO::File;
use File::Copy 'cp';
use Data::Dumper;
our $AUTOLOAD;


sub init {
  my $self = shift;
  $self->set_variable("dbuser", $self->fetchrow_array(
      q{ SELECT SUSER_NAME() }
  ));
  $self->set_variable("maxpagesize", $self->fetchrow_array(
      q{ SELECT @@MAXPAGESIZE }
  ));
  if ($self->mode =~ /^server::connectedusers/) {
    my $connectedusers = $self->fetchrow_array(q{
        SELECT
          COUNT(*)
        FROM
          master..sysprocesses
        WHERE
          hostprocess IS NOT NULL AND program_name != 'JS Agent'
      });
    if (! defined $connectedusers) {
      $self->add_unknown("unable to count connected users");
    } else {
      $self->set_thresholds(warning => 50, critical => 80);
      $self->add_message($self->check_thresholds($connectedusers),
          sprintf "%d connected users", $connectedusers);
      $self->add_perfdata(
          label => "connected_users",
          value => $connectedusers
      );
    }
  } elsif ($self->mode =~ /^server::database/) {
    $self->analyze_and_check_database_subsystem("Classes::ASE::Component::DatabaseSubsystem");
    $self->reduce_messages_short();
  } else {
    $self->no_such_mode();
  }
}

sub has_threshold_table {
  my $self = shift;
  if (! exists $self->{has_threshold_table}) {
    my $find_sql;
    if ($self->version_is_minimum("9.x")) {
      $find_sql = q{
          SELECT name FROM sys.objects
          WHERE name = 'check_ase_health_thresholds'
      };
    } else {
      $find_sql = q{
          SELECT name FROM sysobjects
          WHERE name = 'check_ase_health_thresholds'
      };
    }
    if ($self->{handle}->fetchrow_array($find_sql)) {
      $self->{has_threshold_table} = 'check_ase_health_thresholds';
    } else {
      $self->{has_threshold_table} = undef;
    }
  }
  return $self->{has_threshold_table};
}


package Classes::APS::Component::ComponentSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::aps::component::failed/) {
    my $columns = ['node_name', 'name', 'instance_id',
        'property_name', 'property_value', 'update_time'];
    my $sql = q{
        SELECT
            NodeName,
            ComponentName,
            ComponentInstanceId,
            ComponentPropertyName,
            ComponentPropertyValue,
            UpdateTime
        FROM
            SQL_ADMIN.[dbo].status_components_dc
        WHERE
            ComponentPropertyValue NOT IN ('OK','UNKNOWN')
        ORDER BY
            ComponentName desc";
    };
    $self->get_db_tables([
        ['components', $sql, 'Classes::APS::Component::ComponentSubsystem::Component', sub { my $o = shift; $self->filter_name($o->{name}); }, $columns],
    ]);
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking components');
  if ($self->mode =~ /server::aps::component::failed/) {
    if (@{$self->{components}}) {
      $self->add_critical(
        sprintf '%d failed components', scalar(@{$self->{components}})
      );
      $self->SUPER::check();
    } else {
      $self->add_ok("no failed components");
    }
  } else {
    $self->SUPER::check();
  }
}

package Classes::APS::Component::ComponentSubsystem::Component;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  my $columns = ['node_name', 'name', 'instance_id',
      'property_name', 'property_value', 'update_time'];
  $self->{message} = join(",", map { $self->{$_} } @{$columns});
}

sub check {
  my $self = shift;
  if ($self->{property_value} !~ /^(OK|UNKNOWN)$/) {
    $self->add_critical($self->{message});
  }
}

package Classes::APS::Disk::DiskSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::aps::disk::free/) {
    $self->override_opt("units", "%") if ! $self->opts->units;
    my $columns = ['node_name', 'name', 'size_mb',
        'free_space_mb', 'space_utilized_mb', 'free_space_pct'];
    my $sql = q{
        SELECT
            NodeName,
            VolumeName,
            VolumeSizeMB,
            FreeSpaceMB,
            SpaceUtilized,
            FreeSpaceMBPct
        FROM
            SQL_ADMIN.[dbo].disk_space
        ORDER BY
            NodeName, VolumeName DESC";
    };
    $self->get_db_tables([
        ['disks', $sql, 'Classes::APS::Disk::DiskSubsystem::Disk', sub { my $o = shift; $self->filter_name($o->{name}); }, $columns],
    ]);
  }
}


package Classes::APS::Disk::DiskSubsystem::Disk;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{name} = $self->{node_name}.'_'.$self->{name};
  $self->{name} = lc $self->{name};
  my $factor = 1; # MB
  if ($self->opts->units ne "%") {
    if (uc $self->opts->units eq "GB") {
      $factor = 1024;
    } elsif (uc $self->opts->units eq "MB") {
      $factor = 1;
    } elsif (uc $self->opts->units eq "KB") {
      $factor = 1 / 1024;
    }
  }
  $self->{size} = $self->{size_mb} / $factor;
  $self->{free_space} = $self->{free_space_mb} / $factor;
  $self->{space_utilized} = $self->{space_utilized_mb} / $factor;
}

sub check {
  my $self = shift;
  my $warning_units;
  my $critical_units;
  my $warning_pct;
  my $critical_pct;
  my $metric_units = $self->{name}.'_free';
  my $metric_pct = $self->{name}.'_free_pct';
  if ($self->opts->units eq "%") {
    $self->set_thresholds(metric => $metric_pct, warning => "10:", critical => "5:");
    ($warning_pct, $critical_pct) = ($self->get_thresholds(metric => $metric_pct));
    ($warning_units, $critical_units) = map {
        $_ =~ s/://g; ($_ * $self->{size} / 100).":";
    } map { my $tmp = $_; $tmp; } ($warning_pct, $critical_pct); # sonst schnippelt der von den originalen den : weg
    $self->set_thresholds(metric => $metric_units, warning => $warning_units, critical => $critical_units);
    $self->add_message($self->check_thresholds(metric => $metric_pct, value => $self->{free_space_pct}),
        sprintf("disk %s has %.2f%s free space left", $self->{name}, $self->{free_space_pct}, $self->opts->units));
  } else {
    $self->set_thresholds(metric => $metric_units, warning => "5:", critical => "10:");
    ($warning_units, $critical_units) = ($self->get_thresholds(metric => $metric_units));
    ($warning_pct, $critical_pct) = map {
        $_ =~ s/://g; (100 * $_ / $self->{size}).":";
    } map { my $tmp = $_; $tmp; } ($warning_units, $critical_units);
    $self->set_thresholds(metric => $metric_pct, warning => $warning_pct, critical => $critical_pct);
    $self->add_message($self->check_thresholds(metric => $metric_units, value => $self->{free_space}),
        sprintf("disk %s has %.2f%s free space left", $self->{name}, $self->{free_space}, $self->opts->units));
  }
  $self->add_perfdata(
      label => $metric_pct,
      value => $self->{free_space_pct},
      places => 2,
      uom => '%',
      warning => $warning_pct,
      critical => $critical_pct,
  );
  $self->add_perfdata(
      label => $metric_units,
      value => $self->{free_space},
      uom => $self->opts->units eq "%" ? "MB" : $self->opts->units,
      places => 2,
      warning => $warning_units,
      critical => $critical_units,
      min => 0,
      max => $self->{size},
  );
}

package Classes::APS::Component::AlertSubsystem;
our @ISA = qw(Monitoring::GLPlugin::DB::Item);
use strict;

sub init {
  my $self = shift;
  my $sql = undef;
  if ($self->mode =~ /server::aps::alert::active/) {
    my $columns = ['node_name', 'component_name', 'component_instance_id',
        'name', 'state', 'severity', 'type', 'status', 'create_time'];
    my $sql = q{
        SELECT 
            NodeName, 
            ComponentName, 
            ComponentInstanceId,
            AlertName,
            AlertState,
            AlertSeverity,
            AlertType,
            AlertStatus,
            CreateTime
        FROM
            SQL_ADMIN.[dbo].current_alerts_dc
        -- WHERE
        --     AlertSeverity <> 'Informational'
        ORDER BY
            CreateTime DESC
    };
    $self->get_db_tables([
        ['alerts', $sql, 'Classes::APS::Component::AlertSubsystem::Alert', sub { my $o = shift; $self->filter_name($o->{name}); }, $columns],
    ]);
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking alerts');
  if ($self->mode =~ /server::aps::alert::active/) {
    $self->set_thresholds(
        metric => 'active_alerts',
        warning => 0,
        critical => 0,
    );
    my @active_alerts = grep { $_->{severity} ne "Informational" } @{$self->{alerts}};
    if (scalar(@active_alerts)) {
      $self->add_message(
          $self->check_thresholds(metric => 'active_alerts', value => scalar(@active_alerts)),
          sprintf '%d active alerts', scalar(@{$self->{alerts}})
      );
      foreach (@active_alerts) {
        $self->add_ok($_->{message});
      }
    } else {
      $self->add_ok("no active alerts");
    }
  } else {
    $self->SUPER::check();
  }
}

package Classes::APS::Component::AlertSubsystem::Alert;
our @ISA = qw(Monitoring::GLPlugin::DB::TableItem);
use strict;

sub finish {
  my $self = shift;
  my $columns = ['node_name', 'component_name', 'component_instance_id',
      'name', 'state', 'severity', 'type', 'status', 'create_time'];
  $self->{message} = join(",", map { $self->{$_} } @{$columns});
}

sub check {
  my $self = shift;
  if ($self->{severity} ne "Informational") {
    $self->add_critical($self->{message});
  }
}
package Classes::APS::Sqlrelay;
our @ISA = qw(Classes::APS Classes::Sybase::Sqlrelay);
use strict;
package Classes::APS::Sqsh;
our @ISA = qw(Classes::APS Classes::Sybase::Sqsh);
use strict;
package Classes::APS::DBI;
our @ISA = qw(Classes::APS Classes::Sybase::DBI);
use strict;
package Classes::APS;
our @ISA = qw(Classes::Sybase);

use strict;
use Time::HiRes;
use IO::File;
use File::Copy 'cp';
use Data::Dumper;
our $AUTOLOAD;


sub init {
  my $self = shift;
  $self->set_variable("dbuser", $self->fetchrow_array(
      q{ SELECT SYSTEM_USER }
  ));
  if ($self->mode =~ /^server::aps::component/) {
    $self->analyze_and_check_component_subsystem("Classes::APS::Component::ComponentSubsystem");
  } elsif ($self->mode =~ /^server::aps::alert/) {
    $self->analyze_and_check_alert_subsystem("Classes::APS::Component::AlertSubsystem");
  } elsif ($self->mode =~ /^server::aps::disk/) {
    $self->analyze_and_check_alert_subsystem("Classes::APS::Component::DiskSubsystem");
  } else {
    $self->no_such_mode();
  }
}

sub has_threshold_table {
  my $self = shift;
  if (! exists $self->{has_threshold_table}) {
    my $find_sql;
    if ($self->version_is_minimum("9.x")) {
      $find_sql = q{
          SELECT name FROM sys.objects
          WHERE name = 'check_mssql_health_thresholds'
      };
    } else {
      $find_sql = q{
          SELECT name FROM sysobjects
          WHERE name = 'check_mssql_health_thresholds'
      };
    }
    if ($self->{handle}->fetchrow_array($find_sql)) {
      $self->{has_threshold_table} = 'check_mssql_health_thresholds';
    } else {
      $self->{has_threshold_table} = undef;
    }
  }
  return $self->{has_threshold_table};
}

package Classes::Sybase::SqlRelay;
our @ISA = qw(Classes::Sybase Monitoring::GLPlugin::DB::DBI);
use strict;
use File::Basename;

sub check_connect {
  my $self = shift;
  my $stderrvar;
  my $dbi_options = { RaiseError => 1, AutoCommit => $self->opts->commit, PrintError => 1 };
  my $dsn = "DBI:SQLRelay:";
  $dsn .= sprintf ";host=%s", $self->opts->hostname;
  $dsn .= sprintf ";port=%s", $self->opts->port;
  $dsn .= sprintf ";socket=%s", $self->opts->socket;
  if ($self->opts->currentdb) {
    if (index($self->opts->currentdb,"-") != -1) {
      $dsn .= sprintf ";database=\"%s\"", $self->opts->currentdb;
    } else {
      $dsn .= sprintf ";database=%s", $self->opts->currentdb;
    }
  }
  $self->set_variable("dsn", $dsn);
  eval {
    require DBI;
    $self->set_timeout_alarm($self->opts->timeout - 1, sub {
      die "alrm";
    });  
    *SAVEERR = *STDERR;
    open OUT ,'>',\$stderrvar;
    *STDERR = *OUT;
    $self->{tic} = Time::HiRes::time();
    if ($self->{handle} = DBI->connect(
        $dsn,
        $self->opts->username,
        $self->opts->password,
        $dbi_options)) {
      $Monitoring::GLPlugin::DB::session = $self->{handle};
    }
    $self->{tac} = Time::HiRes::time();
    *STDERR = *SAVEERR;
  };
  if ($@) {
    if ($@ =~ /alrm/) {
      $self->add_critical(
          sprintf "connection could not be established within %s seconds",
          $self->opts->timeout);
    } else {
      $self->add_critical($@);
    }
  } elsif (! $self->{handle}) {
    $self->add_critical("no connection");
  } else {
    $self->set_timeout_alarm($self->opts->timeout - ($self->{tac} - $self->{tic}));
  }
}

package Classes::Sybase::Sqsh;
our @ISA = qw(Classes::Sybase);
use strict;
use File::Basename;

sub create_cmd_line {
  my $self = shift;
  my @args = ();
  if ($self->opts->server) {
    push (@args, sprintf "-S '%s'", $self->opts->server);
  } elsif ($self->opts->hostname) {
    push (@args, sprintf "-S '%s:%d'", $self->opts->hostname, $self->opts->port || 1433);
  } else {
    $self->add_critical("-S oder -H waere nicht schlecht");
  }
  push (@args, sprintf "-U '%s'", $self->opts->username);
  push (@args, sprintf "-P '%s'",
      $self->decode_rfc3986($self->opts->password));
  push (@args, sprintf "-i '%s'",
      $Monitoring::GLPlugin::DB::sql_commandfile);
  push (@args, sprintf "-o '%s'",
      $Monitoring::GLPlugin::DB::sql_resultfile);
  if ($self->opts->currentdb) {
    push (@args, sprintf "-D '%s'", $self->opts->currentdb);
  }
  push (@args, sprintf "-h -s '|' -m bcp");
  $Monitoring::GLPlugin::DB::session =
      sprintf '"%s" %s', $self->{extcmd}, join(" ", @args);
}

sub check_connect {
  my $self = shift;
  my $stderrvar;
  if (! $self->find_extcmd("sqsh", "SQL_HOME")) {
    $self->add_unknown("sqsh command was not found");
    return;
  }
  $self->create_extcmd_files();
  $self->create_cmd_line();
  eval {
    $self->set_timeout_alarm($self->opts->timeout - 1, sub {
      die "alrm";
    });
    *SAVEERR = *STDERR;
    open OUT ,'>',\$stderrvar;
    *STDERR = *OUT;
    $self->{tic} = Time::HiRes::time();
    my $answer = $self->fetchrow_array(q{
        SELECT 'schnorch'
    });
    die unless defined $answer and $answer eq 'schnorch';
    $self->{tac} = Time::HiRes::time();
    *STDERR = *SAVEERR;
  };
  if ($@) {
    if ($@ =~ /alrm/) {
      $self->add_critical(
          sprintf "connection could not be established within %s seconds",
          $self->opts->timeout);
    } else {
      $self->add_critical($@);
    }
  } elsif ($stderrvar && $stderrvar =~ /can't change context to database/) {
    $self->add_critical($stderrvar);
  } else {
    $self->set_timeout_alarm($self->opts->timeout - ($self->{tac} - $self->{tic}));
  }
}

sub write_extcmd_file {
  my $self = shift;
  my $sql = shift;
  open CMDCMD, "> $Monitoring::GLPlugin::DB::sql_commandfile";
  printf CMDCMD "%s\n", $sql;
  printf CMDCMD "go\n";
  close CMDCMD;
}

sub fetchrow_array {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my @row = ();
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    @row = map { $self->convert_scientific_numbers($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }         # strip leading space from numbers
        map { s/\s+$//g; $_ }                     # strip trailing space
        split(/\|/, (map { s/^\|//; $_; } grep {! /^\s*$/ } split(/\n/, $output)
)[0]);
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@row));
  }
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  }
  return $row[0] unless wantarray;
  return @row;
}

sub fetchall_array {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my $rows = [];
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "SQL (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    my @rows = map { [
        map { $self->convert_scientific_numbers($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }
        map { s/\s+$//g; $_ }
        split /\|/
    ] } grep { ! /^\d+ rows selected/ }
        grep { ! /^\d+ [Zz]eilen ausgew / }
        grep { ! /^Elapsed: / }
        grep { ! /^\s*$/ } map { s/^\|//; $_; } split(/\n/, $output);
    $rows = \@rows;
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  }
  return @{$rows};
}

sub execute {
  my $self = shift;
  my $sql = shift;
  my @arguments = @_;
  my $rows = [];
  my $stderrvar = "";
  foreach (@arguments) {
    # replace the ? by the parameters
    if (/^\d+$/) {
      $sql =~ s/\?/$_/;
    } else {
      $sql =~ s/\?/'$_'/;
    }
  }
  $self->set_variable("verbosity", 2);
  $self->debug(sprintf "EXEC (? resolved):\n%s\nARGS:\n%s\n",
      $sql, Data::Dumper::Dumper(\@arguments));
  $self->write_extcmd_file($sql);
  *SAVEERR = *STDERR;
  open OUT ,'>',\$stderrvar;
  *STDERR = *OUT;
  $self->debug($Monitoring::GLPlugin::DB::session);
  my $exit_output = `$Monitoring::GLPlugin::DB::session`;
  *STDERR = *SAVEERR;
  if ($?) {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar) if $stderrvar;
    $self->add_warning($output);
  } else {
    my $output = do { local (@ARGV, $/) = $Monitoring::GLPlugin::DB::sql_resultfile; my $x = <>; close ARGV; $x } || '';
    my @rows = map { [
        map { $self->convert_scientific_numbers($_) }
        map { s/^\s+([\.\d]+)$/$1/g; $_ }
        map { s/\s+$//g; $_ }
        split /\|/
    ] } grep { ! /^\d+ rows selected/ }
        grep { ! /^\d+ [Zz]eilen ausgew / }
        grep { ! /^Elapsed: / }
        grep { ! /^\s*$/ } map { s/^\|//; $_; } split(/\n/, $output);
    $rows = \@rows;
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  }
  return @{$rows};
}

sub decode_rfc3986 {
  my $self = shift;
  my $password = shift;
  eval {
    no warnings 'all';
    $password = $Monitoring::GLPlugin::plugin->{opts}->decode_rfc3986($password);
  };
  # we call '...%s/%s@...' inside backticks where the second %s is the password
  # abc'xcv -> ''abc'\''xcv''
  # abc'`xcv -> ''abc'\''\`xcv''
  if ($password && $password =~ /'/) {
    $password = "'".join("\\'", map { "'".$_."'"; } split("'", $password))."'";
  }
  return $password;
}

sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs();
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::create_cmd_line'} = \&{"Classes::Sybase::Sqsh::create_cmd_line"};
    *{'Monitoring::GLPlugin::DB::write_extcmd_file'} = \&{"Classes::Sybase::Sqsh::write_extcmd_file"};
    *{'Monitoring::GLPlugin::DB::decode_rfc3986'} = \&{"Classes::Sybase::Sqsh::decode_rfc3986"};
    *{'Monitoring::GLPlugin::DB::fetchall_array'} = \&{"Classes::Sybase::Sqsh::fetchall_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_array'} = \&{"Classes::Sybase::Sqsh::fetchrow_array"};
    *{'Monitoring::GLPlugin::DB::execute'} = \&{"Classes::Sybase::Sqsh::execute"};
  }
}

package Classes::Sybase::DBI;
our @ISA = qw(Classes::Sybase Monitoring::GLPlugin::DB::DBI);
use strict;
use File::Basename;

sub check_connect {
  my ($self) = @_;
  my $stderrvar;
  my $dbi_options = { RaiseError => 1, AutoCommit => $self->opts->commit, PrintError => 1 };
  my $dsn = "DBI:Sybase:";
  if ($self->opts->hostname) {
    $dsn .= sprintf ";host=%s", $self->opts->hostname;
    $dsn .= sprintf ";port=%s", $self->opts->port;
  } else {
    $dsn .= sprintf ";server=%s", $self->opts->server;
  }
  if ($self->opts->currentdb) {
    if (index($self->opts->currentdb,"-") != -1) {
      # once the database name had to be put in quotes....
      $dsn .= sprintf ";database=%s", $self->opts->currentdb;
    } else {
      $dsn .= sprintf ";database=%s", $self->opts->currentdb;
    }
  }
  if (basename($0) =~ /_sybase_/) {
    $dbi_options->{syb_chained_txn} = 1;
    $dsn .= sprintf ";tdsLevel=CS_TDS_42";
  }
  $self->set_variable("dsn", $dsn);
  eval {
    require DBI;
    $self->set_timeout_alarm($self->opts->timeout - 1, sub {
      die "alrm";
    });
    *SAVEERR = *STDERR;
    open OUT ,'>',\$stderrvar;
    *STDERR = *OUT;
    $self->{tic} = Time::HiRes::time();
    if ($self->{handle} = DBI->connect(
        $dsn,
        $self->opts->username,
        $self->opts->password,
        $dbi_options)) {
      $Monitoring::GLPlugin::DB::session = $self->{handle};
    }
    $self->{tac} = Time::HiRes::time();
    $Monitoring::GLPlugin::DB::session->{syb_flush_finish} = 1;
    *STDERR = *SAVEERR;
  };
  if ($@) {
    if ($@ =~ /alrm/) {
      $self->add_critical(
          sprintf "connection could not be established within %s seconds",
          $self->opts->timeout);
    } else {
      $self->add_critical($@);
    }
  } elsif ($stderrvar && $stderrvar =~ /can't change context to database/) {
    $self->add_critical($stderrvar);
  } elsif (! $self->{handle}) {
    $self->add_critical("no connection");
  } else {
    $self->set_timeout_alarm($self->opts->timeout - ($self->{tac} - $self->{tic}));
  }
}

sub fetchrow_array {
  my ($self, $sql, @arguments) = @_;
  my @row = ();
  my $errvar = "";
  my $stderrvar = "";
  $self->set_variable("verbosity", 2);
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    if ($self->get_variable("dsn") =~ /tdsLevel/) {
      # better install a handler here. otherwise the plugin output is
      # unreadable when errors occur
      $Monitoring::GLPlugin::DB::session->{syb_err_handler} = sub {
        my($err, $sev, $state, $line, $server,
            $proc, $msg, $sql, $err_type) = @_;
        $errvar = join("\n", (split(/\n/, $errvar), $msg));
        return 0;
      };
    }
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments) || die DBI::errstr();
    } else {
      $sth->execute() || die DBI::errstr();
    }
    if (lc $sql =~ /^\s*(exec |sp_)/ || $sql =~ /^\s*exec sp/im) {
      # flatten the result sets
      do {
        while (my $aref = $sth->fetchrow_arrayref()) {
          push(@row, @{$aref});
        }
      } while ($sth->{syb_more_results});
    } else {
      @row = $sth->fetchrow_array();
    }
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper(\@row));
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar || $errvar) {
    $errvar = join("\n", (split(/\n/, $errvar), $stderrvar));
    $self->debug(sprintf "stderr %s", $errvar) ;
    $self->add_warning($errvar);
  }
  return $row[0] unless wantarray;
  return @row;
}

sub fetchall_array {
  my ($self, $sql, @arguments) = @_;
  my $rows = undef;
  my $errvar = "";
  my $stderrvar = "";
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "SQL:\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    if ($sql =~ /^\s*dbcc /im) {
      # dbcc schreibt auf stdout. Die Ausgabe muss daher
      # mit einem eigenen Handler aufgefangen werden.
      $Monitoring::GLPlugin::DB::session->{syb_err_handler} = sub {
        my($err, $sev, $state, $line, $server,
            $proc, $msg, $sql, $err_type) = @_;
        push(@{$rows}, $msg);
        return 0;
      };
    }
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments);
    } else {
      $sth->execute();
    }
    if ($sql !~ /^\s*dbcc /im) {
      $rows = $sth->fetchall_arrayref();
    }
    $sth->finish();
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $rows = [];
  } elsif ($stderrvar || $errvar) {
    $errvar = join("\n", (split(/\n/, $errvar), $stderrvar));
    $self->debug(sprintf "stderr %s", $errvar) ;
    $self->add_warning($errvar);
  }
  return @{$rows};
}

sub exec_sp_1hash {
  my ($self, $sql, @arguments) = @_;
  my $rows = undef;
  my $stderrvar;
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "EXEC\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    if (scalar(@arguments)) {
      $sth->execute(@arguments);
    } else {
      $sth->execute();
    }
    do {
      while (my $href = $sth->fetchrow_hashref()) {
        foreach (keys %{$href}) {
          push(@{$rows}, [ $_, $href->{$_} ]);
        }
      }
    } while ($sth->{syb_more_results});
    $self->debug(sprintf "RESULT:\n%s\n",
        Data::Dumper::Dumper($rows));
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
    $rows = [];
  } elsif ($stderrvar) {
    $self->debug(sprintf "stderr %s", $stderrvar) ;
    $self->add_warning($stderrvar);
    $rows = [];
  }
  return @{$rows};
}

sub execute {
  my ($self, $sql, @arguments) = @_;
  my $errvar = "";
  my $stderrvar = "";
  $Monitoring::GLPlugin::DB::session->{syb_err_handler} = sub {
    # exec sometimes a status code which, if not caught by this handler,
    # is output to stderr. So even if the procedure was run correctly
    # there may be a warning
    my($err, $sev, $state, $line, $server,
        $proc, $msg, $sql, $err_type) = @_;
    $errvar = join("\n", (split(/\n/, $errvar), $msg));
    return 0;
  };
  *SAVEERR = *STDERR;
  open ERR ,'>',\$stderrvar;
  *STDERR = *ERR;
  eval {
    $self->debug(sprintf "EXEC\n%s\nARGS:\n%s\n",
        $sql, Data::Dumper::Dumper(\@arguments));
    my $sth = $Monitoring::GLPlugin::DB::session->prepare($sql);
    $sth->execute();
    $sth->finish();
  };
  *STDERR = *SAVEERR;
  if ($@) {
    $self->debug(sprintf "bumm %s", $@);
    $self->add_critical($@);
  } elsif ($stderrvar || $errvar) {
    $errvar = join("\n", (split(/\n/, $errvar), $stderrvar));
    $self->debug(sprintf "stderr %s", $errvar) ;
    $self->add_warning($errvar);
  }
}


sub add_dbi_funcs {
  my $self = shift;
  $self->SUPER::add_dbi_funcs();
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::fetchall_array'} = \&{"Classes::Sybase::DBI::fetchall_array"};
    *{'Monitoring::GLPlugin::DB::fetchrow_array'} = \&{"Classes::Sybase::DBI::fetchrow_array"};
    *{'Monitoring::GLPlugin::DB::exec_sp_1hash'} = \&{"Classes::Sybase::DBI::exec_sp_1hash"};
    *{'Monitoring::GLPlugin::DB::execute'} = \&{"Classes::Sybase::DBI::execute"};
  }
}

package Classes::Sybase;
our @ISA = qw(Classes::Device);

use strict;
use Time::HiRes;
use IO::File;
use File::Copy 'cp';
use Data::Dumper;
our $AUTOLOAD;


sub check_version {
  my $self = shift;
  #$self->{version} = $self->{handle}->fetchrow_array(
  #    q{ SELECT SERVERPROPERTY('productversion') });
  # @@VERSION:
  # Variant1:
  # Adaptive Server Enterprise/15.5/EBF 18164 SMP ESD#2/P/x86_64/Enterprise Linux/asear155/2514/64-bit/FBO/Wed Aug 25 11:17:26 2010
  # Variant2:
  # Microsoft SQL Server 2005 - 9.00.1399.06 (Intel X86)
  #    Oct 14 2005 00:33:37
  #    Copyright (c) 1988-2005 Microsoft Corporation
  #    Enterprise Edition on Windows NT 5.2 (Build 3790: Service Pack 2)
  map {
      $self->set_variable("os", "Linux") if /Linux/;
      $self->set_variable("version", $1) if /Adaptive Server Enterprise\/([\d\.]+)/;
      $self->set_variable("os", $1) if /Windows (.*)/;
      $self->set_variable("version", $1) if /SQL Server.*\-\s*([\d\.]+)/;
      $self->set_variable("product", "ASE") if /Adaptive Server/;
      $self->set_variable("product", "MSSQL") if /SQL Server/;
      $self->set_variable("product", "APS") if /Parallel Data Warehouse/;
  } $self->fetchrow_array(q{ SELECT @@VERSION });
}

sub create_statefile {
  my $self = shift;
  my %params = @_;
  my $extension = "";
  $extension .= $params{name} ? '_'.$params{name} : '';
  if ($self->opts->can('hostname') && $self->opts->hostname) {
    $extension .= '_'.$self->opts->hostname;
    $extension .= '_'.$self->opts->port;
  }
  if ($self->opts->can('server') && $self->opts->server) {
    $extension .= '_'.$self->opts->server;
  }
  if ($self->opts->mode eq 'sql' && $self->opts->username) {
    $extension .= '_'.$self->opts->username;
  }
  $extension =~ s/\//_/g;
  $extension =~ s/\(/_/g;
  $extension =~ s/\)/_/g;
  $extension =~ s/\*/_/g;
  $extension =~ s/\s/_/g;
  return sprintf "%s/%s%s", $self->statefilesdir(),
      $self->opts->mode, lc $extension;
}

sub add_dbi_funcs {
  my $self = shift;
  {
    no strict 'refs';
    *{'Monitoring::GLPlugin::DB::CSF::create_statefile'} = \&{"Classes::Sybase::create_statefile"};
  }
}

package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin::DB);
use strict;


sub classify {
  my $self = shift;
  if ($self->opts->method eq "dbi") {
    bless $self, "Classes::Sybase::DBI";
    if ((! $self->opts->hostname && ! $self->opts->server) ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname or server, username and password');
    }
    if (! eval "require DBD::Sybase") {
      $self->add_critical('could not load perl module DBD::Sybase');
    }
  } elsif ($self->opts->method eq "sqsh") {
    bless $self, "Classes::Sybase::Sqsh";
    if ((! $self->opts->hostname && ! $self->opts->server) ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname or server, username and password');
    }
  } elsif ($self->opts->method eq "sqlcmd") {
    bless $self, "Classes::Sybase::Sqlcmd";
    if ((! $self->opts->hostname && ! $self->opts->server) ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname or server, username and password');
    }
  } elsif ($self->opts->method eq "sqlrelay") {
    bless $self, "Classes::Sybase::Sqlrelay";
    if ((! $self->opts->hostname && ! $self->opts->server) ||
        ! $self->opts->username || ! $self->opts->password) {
      $self->add_unknown('Please specify hostname or server, username and password');
    }
    if (! eval "require DBD::SQLRelay") {
      $self->add_critical('could not load perl module SQLRelay');
    }
  }
  if (! $self->check_messages()) {
    $self->check_connect();
    if (! $self->check_messages()) {
      $self->add_dbi_funcs();
      $self->check_version();
      my $class = ref($self);
      $class =~ s/::Sybase::/::MSSQL::/ if $self->get_variable("product") eq "MSSQL";
      $class =~ s/::Sybase::/::ASE::/ if $self->get_variable("product") eq "ASE";
      $class =~ s/::Sybase::/::APS::/ if $self->get_variable("product") eq "APS";
      bless $self, $class;
      $self->add_dbi_funcs();
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      }
    }
  }
}

package main;
#! /usr/bin/perl

use strict;

eval {
  if ( ! grep /BEGIN/, keys %Monitoring::GLPlugin::) {
    require Monitoring::GLPlugin;
    require Monitoring::GLPlugin::DB;
  }
};
if ($@) {
  printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
  printf "%s\n", $@;
  exit 3;
}

my $plugin = Classes::Device->new(
    shortname => '',
    usage => '%s [-v] [-t <timeout>] '.
        '--hostname=<db server hostname> [--port <port>] '.
        '--username=<username> --password=<password> '.
        '--mode=<mode> '.
        '...',
    version => '$Revision: 2.6.4.14 $',
    blurb => 'This plugin checks microsoft sql servers ',
    url => 'http://labs.consol.de/nagios/check_mss_health',
    timeout => 60,
);
$plugin->add_db_modes();
$plugin->add_mode(
    internal => 'server::cpubusy',
    spec => 'cpu-busy',
    alias => undef,
    help => 'Cpu busy in percent',
);
$plugin->add_mode(
    internal => 'server::iobusy',
    spec => 'io-busy',
    alias => undef,
    help => 'IO busy in percent',
);
$plugin->add_mode(
    internal => 'server::fullscans',
    spec => 'full-scans',
    alias => undef,
    help => 'Full table scans per second',
);
$plugin->add_mode(
    internal => 'server::connectedusers',
    spec => 'connected-users',
    alias => undef,
    help => 'Number of currently connected users',
);
$plugin->add_mode(
    internal => 'server::database::transactions',
    spec => 'transactions',
    alias => undef,
    help => 'Transactions per second (per database)',
);
$plugin->add_mode(
    internal => 'server::batchrequests',
    spec => 'batch-requests',
    alias => undef,
    help => 'Batch requests per second',
);
$plugin->add_mode(
    internal => 'server::latch::waits',
    spec => 'latches-waits',
    alias => undef,
    help => 'Number of latch requests that could not be granted immediately',
);
$plugin->add_mode(
    internal => 'server::latch::waittime',
    spec => 'latches-wait-time',
    alias => undef,
    help => 'Average time for a latch to wait before the request is met',
);
$plugin->add_mode(
    internal => 'server::memorypool::lock::waits',
    spec => 'locks-waits',
    alias => undef,
    help => 'The number of locks per second that had to wait',
);
$plugin->add_mode(
    internal => 'server::memorypool::lock::timeouts',
    spec => 'locks-timeouts',
    alias => undef,
    help => 'The number of locks per second that timed out',
);
$plugin->add_mode(
    internal => 'server::memorypool::lock::deadlocks',
    spec => 'locks-deadlocks',
    alias => undef,
    help => 'The number of deadlocks per second',
);
$plugin->add_mode(
    internal => 'server::sql::recompilations',
    spec => 'sql-recompilations',
    alias => undef,
    help => 'Re-Compilations per second',
);
$plugin->add_mode(
    internal => 'server::sql::initcompilations',
    spec => 'sql-initcompilations',
    alias => undef,
    help => 'Initial compilations per second',
);
$plugin->add_mode(
    internal => 'server::totalmemory',
    spec => 'total-server-memory',
    alias => undef,
    help => 'The amount of memory that SQL Server has allocated to it',
);
$plugin->add_mode(
    internal => 'server::memorypool::buffercache::hitratio',
    spec => 'mem-pool-data-buffer-hit-ratio',
    alias => ['buffer-cache-hit-ratio'],
    help => 'Data Buffer Cache Hit Ratio',
);
$plugin->add_mode(
    internal => 'server::memorypool::buffercache::lazywrites',
    spec => 'lazy-writes',
    alias => undef,
    help => 'Lazy writes per second',
);
$plugin->add_mode(
    internal => 'server::memorypool::buffercache::pagelifeexpectancy',
    spec => 'page-life-expectancy',
    alias => undef,
    help => 'Seconds a page is kept in memory before being flushed',
);
$plugin->add_mode(
    internal => 'server::memorypool::buffercache::freeliststalls',
    spec => 'free-list-stalls',
    alias => undef,
    help => 'Requests per second that had to wait for a free page',
);
$plugin->add_mode(
    internal => 'server::memorypool::buffercache::checkpointpages',
    spec => 'checkpoint-pages',
    alias => undef,
    help => 'Dirty pages flushed to disk per second. (usually by a checkpoint)',
);
$plugin->add_mode(
    internal => 'server::database::online',
    spec => 'database-online',
    alias => undef,
    help => 'Check if a database is online and accepting connections',
);
$plugin->add_mode(
    internal => 'server::database::free',
    spec => 'database-free',
    alias => undef,
    help => 'Free space in database',
);
$plugin->add_mode(
    internal => 'server::database::datafree',
    spec => 'database-data-free',
    alias => undef,
    help => 'Free (data) space in database',
);
$plugin->add_mode(
    internal => 'server::database::logfree',
    spec => 'database-log-free',
    alias => undef,
    help => 'Free (transaction log) space in database',
);
$plugin->add_mode(
    internal => 'server::database::free::details',
    spec => 'database-free-details',
    alias => undef,
    help => 'Free space in database and filegroups',
);
$plugin->add_mode(
    internal => 'server::database::datafree::details',
    spec => 'database-data-free-details',
    alias => undef,
    help => 'Free (data) space in database and filegroups',
);
$plugin->add_mode(
    internal => 'server::database::logfree::details',
    spec => 'database-log-free-details',
    alias => undef,
    help => 'Free (transaction log) space in database and filegroups',
);
$plugin->add_mode(
    internal => 'server::database::filegroup::free',
    spec => 'database-filegroup-free',
    alias => undef,
    help => 'Free space in database filegroups',
);
$plugin->add_mode(
    internal => 'server::database::file::free',
    spec => 'database-file-free',
    alias => undef,
    help => 'Free space in database files',
);
$plugin->add_mode(
    internal => 'server::database::size',
    spec => 'database-size',
    alias => undef,
    help => 'Size of a database',
);
$plugin->add_mode(
    internal => 'server::database::backupage',
    spec => 'database-backup-age',
    alias => ['backup-age'],
    help => 'Elapsed time (in hours) since a database was last backed up',
);
$plugin->add_mode(
    internal => 'server::database::logbackupage',
    spec => 'database-logbackup-age',
    alias => ['logbackup-age'],
    help => 'Elapsed time (in hours) since a database transaction log was last backed up',
);
$plugin->add_mode(
    internal => 'server::database::autogrowths::file',
    spec => 'database-file-auto-growths',
    alias => undef,
    help => 'The number of File Auto Grow events (either data or log) in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::autogrowths::logfile',
    spec => 'database-logfile-auto-growths',
    alias => undef,
    help => 'The number of Log File Auto Grow events in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::autogrowths::datafile',
    spec => 'database-datafile-auto-growths',
    alias => undef,
    help => 'The number of Data File Auto Grow events in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::autoshrinks::file',
    spec => 'database-file-auto-shrinks',
    alias => undef,
    help => 'The number of File Auto Shrink events (either data or log) in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::autoshrinks::logfile',
    spec => 'database-logfile-auto-shrinks',
    alias => undef,
    help => 'The number of Log File Auto Shrink events in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::autoshrinks::datafile',
    spec => 'database-datafile-auto-shrinks',
    alias => undef,
    help => 'The number of Data File Auto Shrink events in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::database::dbccshrinks::file',
    spec => 'database-file-dbcc-shrinks',
    alias => undef,
    help => 'The number of DBCC File Shrink events (either data or log) in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::availabilitygroup::status',
    spec => 'availability-group-health',
    alias => undef,
    help => 'Checks the health status of availability groups',
);
$plugin->add_mode(
    internal => 'server::jobs::failed',
    spec => 'failed-jobs',
    alias => undef,
    help => 'The jobs which did not exit successful in the last <n> minutes (use --lookback)',
);
$plugin->add_mode(
    internal => 'server::jobs::enabled',
    spec => 'jobs-enabled',
    alias => undef,
    help => 'The jobs which are not enabled (scheduled)',
);
$plugin->add_mode(
    internal => 'server::database::createuser',
    spec => 'create-monitoring-user',
    alias => undef,
    help => 'convenience function which creates a monitoring user',
);
$plugin->add_mode(
    internal => 'server::database::deleteuser',
    spec => 'delete-monitoring-user',
    alias => undef,
    help => 'convenience function which deletes a monitoring user',
);
$plugin->add_mode(
    internal => 'server::database::list',
    spec => 'list-databases',
    alias => undef,
    help => 'convenience function which lists all databases',
);
$plugin->add_mode(
    internal => 'server::database::file::list',
    spec => 'list-database-files',
    alias => undef,
    help => 'convenience function which lists all datafiles',
);
$plugin->add_mode(
    internal => 'server::database::filegroup::list',
    spec => 'list-database-filegroups',
    alias => undef,
    help => 'convenience function which lists all data file groups',
);
$plugin->add_mode(
    internal => 'server::memorypool::lock::listlocks',
    spec => 'list-locks',
    alias => undef,
    help => 'convenience function which lists all locks',
);
$plugin->add_mode(
    internal => 'server::jobs::listjobs',
    spec => 'list-jobs',
    alias => undef,
    help => 'convenience function which lists all jobs',
);
$plugin->add_mode(
    internal => 'server::aps::component::failed',
    spec => 'aps-failed-components',
    alias => undef,
    help => 'check faulty components (Microsoft Analytics Platform only)',
);
$plugin->add_mode(
    internal => 'server::aps::alert::active',
    spec => 'aps-alerts',
    alias => undef,
    help => 'check for severe alerts (Microsoft Analytics Platform only)',
);
$plugin->add_mode(
    internal => 'server::aps::disk::free',
    spec => 'aps-disk-free',
    alias => undef,
    help => 'check free disk space (Microsoft Analytics Platform only)',
);
$plugin->add_arg(
    spec => 'hostname=s',
    help => "--hostname
   the database server",
    required => 0,
);
$plugin->add_arg(
    spec => 'username=s',
    help => "--username
   the mssql user",
    required => 0,
    decode => "rfc3986",
);
$plugin->add_arg(
    spec => 'password=s',
    help => "--password
   the mssql user's password",
    required => 0,
    decode => "rfc3986",
);
$plugin->add_arg(
    spec => 'port=i',
    default => 1433,
    help => "--port
   the database server's port",
    required => 0,
);
$plugin->add_arg(
    spec => 'server=s',
    help => "--server
   use a section in freetds.conf instead of hostname/port",
    required => 0,
);
$plugin->add_arg(
    spec => 'currentdb=s',
    help => "--currentdb
   the name of a database which is used as the current database
   for the connection. (don't use this parameter unless you
   know what you're doing)",
    required => 0,
);
$plugin->add_arg(
    spec => 'offlineok',
    help => "--offlineok
   if mode database-free finds a database which is currently offline,
   a WARNING is issued. If you don't want this and if offline databases
   are perfectly ok for you, then add --offlineok. You will get OK instead.",
    required => 0,
);
$plugin->add_arg(
    spec => 'nooffline',
    help => "--nooffline
   skip the offline databases",
    required => 0,);

$plugin->add_db_args();
$plugin->add_default_args();

$plugin->getopts();
$plugin->classify();
$plugin->validate_args();


if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
} else {
#  $plugin->add_critical('wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin);
$plugin->nagios_exit($code, $message);


