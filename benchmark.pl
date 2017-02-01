#/usr/bin/perl

use strict;
use warnings;
use threads;
use threads::shared;
use File::Basename;
use Time::HiRes qw(usleep);

my $HOST_IP=shift;
my $WEB_PORT=shift;
my $NUM_CLIENTS=10;
my $NUM_NOISE_INSTANCES=20;
my $WORKLOAD_INSTANCES=1;
my $THINK_TIME=100;

my @files :shared = map(basename($_), glob('noise/httpd/images/*.jpg'));

my $running :shared;
my @ports :shared;
my @threads;

print "Starting workload\n";

# TODO: implement

print "Workload started\n";

print "Starting noise\n";

my @noise_ports;

for (my $i=0; $i<$NUM_NOISE_INSTANCES; $i++)
{
  !system("docker run -pd 80 --name noise$i --oom-kill-disable noise:httpd 1>/dev/null && echo 'noise$i'") || die ("Could not start noise instance\n");

  # find out the port
  my $port = `docker ps --filter name="noise$i" --format "{{.Ports}}"`;
  $port =~ /.*\:([0-9]*)->80\/tcp.*/;
  push @ports, $1;
}

print "Noise started\n";


print "Starting noise clients\n";

$running=1;
push @threads, threads->create(sub {
  my $p = @ports;
  my $f = @files;

  while($running) {
    my $port = $ports[int(rand($p))];
    my $file = $files[int(rand($f))];
    
    print "client: http://$HOST_IP:$port/$file\n";     
    system("wget -q -O /dev/null http://$HOST_IP:$port/$file");    

    usleep($THINK_TIME);
  }
  print "thread exits\n";
  
});

print "Noise clients started\n";

print "Starting measurement\n";

# initialize the database
system("curl http://$HOST_IP:$WEB_PORT/rest/api/loader/load?numCustomers=10000");

# run the workload client for measurement
system("docker run --rm -i -t -e APP_PORT_9080_TCP_ADDR=$HOST_IP -e APP_PORT_9080_TCP_PORT=$WEB_PORT -e LOOP_COUNT=100 --name acmeair_workload acmeair/workload");

print "Measurement complete\n";

$running=0;

print "Starting cleanup\n";

for (my $i=0; $i<$NUM_NOISE_INSTANCES; $i++)
{
  system("docker stop noise$i 1>/dev/null");
  system("docker rm noise$i");
}

# let all threads join
foreach my $thread (@threads) {
  $thread->join();
}
                           
print "Cleanup complete\n";                                                                                                                                                                                 
