# ContainerScale Benchmark


This is a benchmark to determine the scalability and maximum density of a Docker-based container system. 
It was used to measure the impact of novel memory extension techniques. 
In order to push the benchmark to the limit a generous amount of swap space should be avaiable. 

# make

builds the benchmark. It requires a working Docker installation and plenty of disk space.

# make clean 

removes generated files but leaves the images intact. 

# make distclean

restores the original state except for the generated and downloaded images. 

# make imageclean

removes even the images. 

# benchmark.pl

runs the simple scalability benchmark with one measured workload and an increasing number of noise workloads. 
The goal of the benchmark is to determine the impact of the noise on the measured workload (acmeair). 


