package ContainerScale::Aux;
use strict;
use warnings;

use Exporter;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(evaluate_values percentile create_acmeair_instance remove_acmeair_instance);
@EXPORT_OK   = qw(evaluate_values percentile create_acmeair_instance remove_acmeair_instance);

sub evaluate_values (@) {
        my $n = @_;
        my $avg = sum(@_)/$n;
        my $min = min(@_);
        my $max = max(@_);
        my $std_dev = ($min == $max) ? 0 : sqrt(sum(map {($_ - $avg) ** 2} @_) / $n);
        return ($avg, $std_dev, $min, $max);
}

sub percentile($$) {
  my $filename = shift;
  my $percentile = shift;
  my @data;
  my $stat = Statistics::Descriptive::Full->new();

  open (my $file, $filename) or die "Could not open $filename\n";

  while (my $line = <$file>) {
    chomp $line;
    if ($line =~ /^\<httpSample t=\"(\d+)\".*$/) {
      push @data, $1;
    }
  }

  close ($file);

  $stat->add_data(@data);
  $stat->sort_data();
  return $stat->percentile($percentile);
}

sub create_acmeair_instance ($$) {
  my $host_ip = shift;
  my $instance = shift;
  system("docker run --name mongo_$instance -d -P mongo 2>/dev/null >&2");
  system("docker run -d -P --name acmeair_authservice_$instance -e APP_NAME=authservice_app.js --link mongo_$instance:mongo acmeair/web 2>/dev/null >&2");
  my $auth_port = `docker port acmeair_authservice_$instance 9443 | cut -d ":" -f 2`;
  chomp $auth_port;
 
  system("docker run -d -P --name acmeair_web_$instance -e AUTH_SERVICE=$host_ip:$auth_port --link mongo_$instance:mongo acmeair/web 2>/dev/null >&2");

  my $port = `docker port acmeair_web_$instance 9080 | cut -d ":" -f 2`;
  chomp $port;
  return $port;
}

sub remove_acmeair_instance($) {
  #return;
  my $instance = shift;
  system("docker rm -f acmeair_web_$instance");
  system("docker rm -f acmeair_authservice_$instance");
  system("docker rm -f mongo_$instance");
}

1;
