#!/usr/bin/perl -Ilib

use strict;
use warnings;
use threads;
use threads::shared;
use File::Basename;
use Time::HiRes qw(usleep);
use List::Util qw(sum min max);
use Statistics::Descriptive;

use ContainerScale::Aux qw(:DEFAULT);

my $HOST_IP="172.17.0.1";
my $MAX_NOISE_INSTANCES=50;
my $INCREMENT=2;
my $NOISE_CLIENTS=10;
my $CLIENT_THREADS=25;
my $THINK_TIME=150;
my $REPETITIONS=1;

$SIG{INT}  = \&signal_handler;
$SIG{TERM} = \&signal_handler;

sub signal_handler {
    die "benchmark terminates due to signal $!";
}

my @files :shared = map(basename($_), glob('noise/httpd/images/*.jpg'));

my $running :shared;
my @ports :shared;

my @noise_ports;

# cleaning up stale noise instances if any exist
system("docker ps -a --filter 'name=noise*' --format {{.Names}} | xargs docker rm -f >&2");

print STDERR "Starting workload\n";

my $WEB_PORT=create_acmeair_instance($HOST_IP, "001");

# initialize the database
my $res;
do {
  sleep 2;
  $res = `curl -s http://$HOST_IP:$WEB_PORT/rest/api/loader/load?numCustomers=10000`;
  print "$res\n";
} until ($res =~ /Database Finished Loading/ || $res =~/Already loaded/);

sleep 2;

print "http://9.3.45.218:$WEB_PORT/flights.html\n";

print STDERR "Workload started\n";

# make one run to warm system up
system("docker run --rm -i -t -e APP_PORT_9080_TCP_ADDR=$HOST_IP -e APP_PORT_9080_TCP_PORT=$WEB_PORT -e LOOP_COUNT=100 -e NUM_THREAD=$CLIENT_THREADS --name acmeair_workload acmeair/workload >&2 2>/dev/null");

# benchmark loop
my $i=0;

for (my $num_noise_instances=1; $num_noise_instances<=$MAX_NOISE_INSTANCES; $num_noise_instances+=$INCREMENT) 
{
  my @threads;

  system("echo 3 > /proc/sys/vm/drop_caches");

  for (my $c=$i; $c<$num_noise_instances; $c++) {
    print STDERR "Starting (more) noise\n";
    !system("docker run -p 80 -d --name noise$i --privileged --oom-kill-disable noise:httpd 1>/dev/null && echo 'noise$i' >&2") || die ("Could not start noise instance\n");

    # find out the port
    my $port = `docker ps --filter name="noise$i" --format "{{.Ports}}"`;
    $port =~ /.*\:([0-9]*)->80\/tcp.*/;
    $port = $1;
    push @ports, $port;

    $i++;
  }

  print STDERR "Noise started\n";

  print STDERR "Starting noise clients\n";

  $running=1;
  push @threads, threads->create(sub {
    my $p = @ports;
    my $f = @files;

    while($running) {
      my $port = $ports[int(rand($p))];
      my $file = $files[int(rand($f))];
    
      #print "client: http://$HOST_IP:$port/images/$file\n";     
      system("wget -q -O /dev/null http://$HOST_IP:$port/images/$file");    

      usleep($THINK_TIME);
    }
    print STDERR "client thread exits\n";
  });

  print STDERR "Noise clients started\n";

  print STDERR "Starting measurement\n";

  # run the workload client for measurement
  my $requests;
  my $time;
  my $throughput;
  my $avg;
  my $min;
  my $max;
  my $perc90;
  my $perc95;
  my $perc99;
  my $err=1;

  open my $pipe, "docker run -i -t -e APP_PORT_9080_TCP_ADDR=$HOST_IP -e APP_PORT_9080_TCP_PORT=$WEB_PORT -e LOOP_COUNT=200 -e NUM_THREAD=$CLIENT_THREADS --name acmeair_workload acmeair/workload |"; 
  while (my $line = <$pipe>) {
    chomp ($line);
    print STDERR "$line\n";
    if ($line =~ /^summary =\s*(\d+) in\s*(\d*\.?\d+)s =\s*(\d*\.?\d+)\/s Avg:\s*(\d+) Min:\s*(\d+) Max:\s*(\d+) Err:\s*(\d+).*$/) {
      $requests=$1;
      $time=$2;
      $throughput=$3;
      $avg=$4;
      $min=$5;
      $max=$6;
      $err=$7;
    }
  }

  if ($err > 0) {
    die "MEASUREMENT INVALID, WORKLOAD ENCOUNTERED $err ERRORS\n";
  }

  # fetch data file
  system("docker cp acmeair_workload:/var/workload/acmeair-nodejs/logs/AcmeAir1.jtl AcmeAir1.jtl");
  system("docker rm acmeair_workload");

  $perc90 = percentile("AcmeAir1.jtl", 90);
  $perc95 = percentile("AcmeAir1.jtl", 95);
  $perc99 = percentile("AcmeAir1.jtl", 99);

  system("rm -f AcmeAir1.jtl");

  print "$num_noise_instances\t$throughput\t$avg\t$min\t$max\t$perc90\t$perc95\t$perc99\n";

  $running=0;

  # let all threads join
  foreach my $thread (@threads) {
    $thread->join();
  }
                           
}

END {
  print STDERR "Starting cleanup\n";

  system("docker ps -a --filter 'name=noise*' --format {{.Names}} | xargs docker rm -f 2>/dev/null >&2");

  remove_acmeair_instance("001");

  print STDERR "Cleanup complete\n";
}                                                                                                                                                                             
