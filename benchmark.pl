#/usr/bin/perl

use strict;
use warnings;
use threads;
use threads::shared;
use File::Basename;
use Time::HiRes qw(usleep);

my $HOST_IP=shift;
my $WEB_PORT=shift;
#my $NUM_CLIENTS=1;
my $MAX_NOISE_INSTANCES=100;
#my $WORKLOAD_INSTANCES=1;
my $THINK_TIME=100;

my @files :shared = map(basename($_), glob('noise/httpd/images/*.jpg'));

my $running :shared;
my @ports :shared;

my @noise_ports;

print STDERR "Starting workload\n";

# TODO: move from Makefile

# initialize the database
system("curl -s -o /dev/null http://$HOST_IP:$WEB_PORT/rest/api/loader/load?numCustomers=10000 >&2"); 

print STDERR "Workload started\n";

my $i=0;

for (my $num_noise_instances=1; $num_noise_instances<=$MAX_NOISE_INSTANCES; $num_noise_instances++) 
{
  my @threads;

  print STDERR "Starting (more) noise\n";
  !system("docker run -pd 80 --name noise$i --oom-kill-disable noise:httpd 1>/dev/null && echo 'noise$i' >&2") || die ("Could not start noise instance\n");

  # find out the port
  my $port = `docker ps --filter name="noise$i" --format "{{.Ports}}"`;
  $port =~ /.*\:([0-9]*)->80\/tcp.*/;
  $port = $1;
  push @ports, $port;

  # fetch all files to warm up the httpd server and make it use memory
  foreach file (@files) {
    system("wget -q -O /dev/null http://$HOST_IP:$port/$file");
  }

  $i++;

  print STDERR "Noise started\n";

  print STDERR "Starting noise clients\n";

  $running=1;
  push @threads, threads->create(sub {
    my $p = @ports;
    my $f = @files;

    while($running) {
      my $port = $ports[int(rand($p))];
      my $file = $files[int(rand($f))];
    
      #print "client: http://$HOST_IP:$port/$file\n";     
      system("wget -q -O /dev/null http://$HOST_IP:$port/$file");    

      usleep($THINK_TIME);
    }
    print STDERR "client thread exits\n";
  });

  print STDERR "Noise clients started\n";

  print STDERR "Starting measurement\n";

  # run the workload client for measurement
  open my $pipe, "docker run --rm -i -t -e APP_PORT_9080_TCP_ADDR=$HOST_IP -e APP_PORT_9080_TCP_PORT=$WEB_PORT -e LOOP_COUNT=100 --name acmeair_workload acmeair/workload |"; 
  while (my $line = <$pipe>) {
    chomp ($line);
    if ($line =~ /^summary =\s*(\d+) in\s*(\d*\.?\d+)s =\s*(\d*\.?\d+)\/s Avg:\s*(\d+) Min:\s*(\d+) Max:\s*(\d+) Err:\s*(\d+).*$/) {
      my $requests=$1;
      my $time=$2;
      my $throughput=$3;
      my $avg=$4;
      my $min=$5;
      my $max=$6;
      my $err=$7;
      if ($err != 0) {
        print "MEASUREMENT INVALID, WORKLOAD ENCOUNTERED $err ERRORS\n";
      } else {
        print "$num_noise_instances\t$throughput\n";
      }
    }
  }

  print STDERR "Measurement complete\n";

  $running=0;

  # let all threads join
  foreach my $thread (@threads) {
    $thread->join();
  }
                           
}

print STDERR "Starting cleanup\n";

for (my $i=0; $i<$MAX_NOISE_INSTANCES; $i++)
{
  system("docker stop noise$i >/dev/null");
  system("docker rm noise$i >&2");
}

print STDERR "Cleanup complete\n";                                                                                                                                                                              
