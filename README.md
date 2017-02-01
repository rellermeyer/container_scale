# memory1-docker-benchmark

The benchmark builds and runs with 

# make run

The only value that could need adjustment is the (currently) hardcoded

HOST_IP

in the Makefile which needs to be set to the IP address of the docker bridge. 

# make clean 

removes generated files but leaves the images intact. 

# make distclean

restores the original state, including the removal of all generated and downloaded images and files. 
