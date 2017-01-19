ACME_AIR_NODE_SHA:=11fa31ab5cd21ca184f760680e8aecc52ef4286a
ACME_AIR_NODE_GIT:=https://github.com/acmeair/acmeair-nodejs.git

ACME_AIR_GIT:=https://github.com/acmeair/acmeair.git

NOECHO:=@
GIT:=git
PATCH:=patch
CURL:=curl
DO:=/bin/sh -c true
CD:=cd
RM:=rm

EXISTS:=0
NOT_EXIST:=1

.PHONY: clean
.PHONY: depclean
.PHONY: acmeair_nodejs
.PHONY: acmeair_authservice
.PHONY: mongo

if_image = $(shell docker images | grep "$(1)" 1>/dev/null; if [ $$? -eq $(2) ] ; then $(3); fi)
if_container = $(shell docker ps -a | grep "$(1)" 1>/dev/null; if [ $$? -eq $(2) ] ; then $(3); fi)
if_running = $(shell docker inspect $(1) 2>&1 | grep "\"Running\": true" 1>/dev/null; if [ $$? -eq 0 ] ; then $(2); fi)

AUTH_PORT = $(shell docker ps --filter name="acmeair_authservice" --format "{{.Ports}}" | sed -r "s/.*\:([0-9]*)->9443\/tcp.*/\1/")
WEB_PORT = $(shell docker ps --filter name="acmeair_web" --format "{{.Ports}}" | sed -r "s/.*\:([0-9]*)->9080\/tcp.*/\1/")
HOST_IP:=172.17.0.1

all: acme_download mongo

acmeair-nodejs: 
	$(NOECHO) $(GIT) clone $(ACME_AIR_NODE_GIT) acmeair-nodejs
	$(NOECHO) $(CD) acmeair-nodejs; $(GIT) checkout $(ACME_AIR_NODE_SHA) 2>/dev/null
	$(CD) acmeair-nodejs; $(PATCH) -p1 < ../json_simple_url.patch

acmeair: acmeair-nodejs
	$(NOECHO) $(CD) acmeair-nodejs; docker build -t acmeair/web .


workload: acmeair-nodejs
	$(NOECHO) $(CD) acmeair-nodejs; docker build -t acmeair/workload document/workload

mongo:	
	$(NOECHO) $(DO) $(call if_container,mongo_001,$(NOT_EXIST),docker run --name mongo_001 -d -P mongo) 

acmeair_authservice: mongo acmeair
	$(NOECHO) $(DO) $(call if_container,acmeair_authservice,$(NOT_EXIST),docker run -d -P --name acmeair_authservice -e APP_NAME=authservice_app.js --link mongo_001:mongo acmeair/web)

acmeair_web: acmeair_authservice 
	$(NOECHO) $(DO) $(call if_container,acmeair_web,$(NOT_EXIST),docker run -d -P --name acmeair_web -e AUTH_SERVICE=$(HOST_IP):$(AUTH_PORT) --link mongo_001:mongo acmeair/web)
	echo "WEB PORT: $(WEB_PORT)"

noise:
	


run: acmeair_web workload
	$(NOECHO) $(DO) $(call if_container,acmeair_workload,$(EXISTS),docker rm acmeair_workload)
	sleep 2
	$(CURL) http://$(HOST_IP):$(WEB_PORT)/rest/api/loader/load?numCustomers=10000
	docker run -i -t -e APP_PORT_9080_TCP_ADDR=$(HOST_IP) -e APP_PORT_9080_TCP_PORT=$(WEB_PORT) -e LOOP_COUNT=100 --name acmeair_workload acmeair/workload

clean:
	$(NOECHO) $(DO) $(call if_running,mongo_001,docker stop mongo_001)
	$(NOECHO) $(DO) $(call if_container,mongo_001,$(EXISTS),docker rm mongo_001)
	$(NOECHO) $(DO) $(call if_running,acmeair_authservice,docker stop acmeair_authservice)
	$(NOECHO) $(DO) $(call if_container,acmeair_authservice,$(EXISTS),docker rm acmeair_authservice)
	$(NOECHO) $(DO) $(call if_running,acmeair_web,docker stop acmeair_web)
	$(NOECHO) $(DO) $(call if_container,acmeair_web,$(EXISTS),docker rm acmeair_web)
	$(NOECHO) $(DO) $(call if_running,acmeair_workload,docker stop acmeair_workload)
	$(NOECHO) $(DO) $(call if_container,acmeair_workload,$(EXISTS),docker rm acmeair_workload)

depclean: clean
	$(NOECHO) $(DO) $(call if_image,acmeair/web,$(EXISTS),docker rmi acmeair/web)
	$(NOECHO) $(DO) $(call if_image,docker.io/mongo,$(EXISTS),docker rmi docker.io/mongo)
	$(NOECHO) $(DO) $(call if_image,acmeair/workload,$(EXISTS),docker rmi acmeair/workload) 
	$(RM) -rf acmeair-nodejs	
