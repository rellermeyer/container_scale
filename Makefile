ACME_AIR_NODE_SHA:=11fa31ab5cd21ca184f760680e8aecc52ef4286a
ACME_AIR_NODE_GIT:=https://github.com/acmeair/acmeair-nodejs.git

ACME_AIR_GIT:=https://github.com/acmeair/acmeair.git

NOECHO:=@
GIT:=git
PATCH:=patch
CURL:=curl
DO:=/bin/true
CD:=cd
RM:=rm
WGET:=wget

EXISTS:=0
NOT_EXIST:=1

.PHONY: clean
.PHONY: depclean
.PHONY: noiseclean
.PHONY: imageclean
.PHONY: acmeair
.PHONY: mongo
.PHONY: noise
.PHONY: workload

if_image = $(shell docker images | grep "$(1)" 1>/dev/null; if [ $$? -eq $(2) ] ; then $(3) ; fi)
if_container = $(shell docker ps -a | grep "$(1)" 1>/dev/null; if [ $$? -eq $(2) ] ; then $(3); fi)
if_running = $(shell docker inspect $(1) 2>&1 | grep "\"Running\": true" 1>/dev/null; if [ $$? -eq 0 ] ; then $(2); fi)

all: mongo acmeair workload noise

acmeair-nodejs: 
	$(NOECHO) $(GIT) clone $(ACME_AIR_NODE_GIT) acmeair-nodejs
	$(NOECHO) $(CD) acmeair-nodejs; $(GIT) checkout $(ACME_AIR_NODE_SHA) 2>/dev/null
	$(CD) acmeair-nodejs; $(PATCH) -p1 < ../json_simple_url.patch

acmeair: acmeair-nodejs
	$(NOECHO) $(DO) $(call if_image,acmeair/web,$(NOT_EXIST),$(CD) acmeair-nodejs;docker build -q -t acmeair/web .)


workload: acmeair-nodejs
	$(NOECHO) $(DO) $(call if_image,acmeair/workload,$(NOT_EXIST),$(CD) acmeair-nodejs;docker build -q -t acmeair/workload document/workload)

mongo:	
	docker pull mongo
	#$(NOECHO) $(DO) $(call if_container,mongo_001,$(NOT_EXIST),docker run --name mongo_001 -d -P mongo) 

noise/httpd/images:
	$(WGET) -P noise/httpd/images https://upload.wikimedia.org/wikipedia/commons/f/ff/Pizigani_1367_Chart_10MB.jpg 
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/uploads/2015/02/Airbus_Pleiades_50cm_8bit_RGB_Yogyakarta.jpg
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/uploads/2015/02/DigitalGlobe_WorldView2_50cm_8bit_Pansharpened_RGB_DRA_Rome_Italy_2009DEC10_8bits_sub_r_1.jpg
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/themes/effigis_2014/img/RapidEye_RapidEye_5m_RGB_Altotting_Germany_Agriculture_and_Forestry_2009MAY17_8bits_sub_r_2.jpg
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/uploads/2015/02/Iunctus_SPOT5_5m_8bit_RGB_DRA_torngat_mountains_national_park_8bits_1.jpg
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/uploads/2015/02/GeoEye_Ikonos_1m_8bit_RGB_DRA_Oil_2005NOV25_8bits_r_1.jpg
	$(WGET) -P noise/httpd/images http://effigis.com/wp-content/themes/effigis_2014/img/GeoEye_GeoEye1_50cm_8bit_RGB_DRA_Mining_2009FEB14_8bits_sub_r_15.jpg
	for i in `seq 1 500`; do dd if=/dev/urandom of=noise/httpd/images/test_smallest$$i.jpg bs=4096 count=640; done
	for i in `seq 1 100`; do dd if=/dev/urandom of=noise/httpd/images/test_small$$i.jpg bs=4096 count=2560; done
	for i in `seq 1 80`; do dd if=/dev/urandom of=noise/httpd/images/test_medium$$i.jpg bs=4096 count=6400; done

noise: noise/httpd/images
#	$(NOECHO) $(DO) $(call if_image,noise:httpd,$(NOT_EXIST),docker build -t noise:httpd noise/httpd)
	$(NOECHO) docker build -t noise:httpd noise/httpd

noiseclean:
	$(NOECHO) $(DO) $(call if_image,noise:httpd,$(EXISTS),docker rmi noise:httpd)
	$(NOECHO) $(RM) -rf noise/httpd/images

clean:
	$(NOECHO) $(DO) $(call if_running,mongo_001,docker stop mongo_001)
	$(NOECHO) $(DO) $(call if_container,mongo_001,$(EXISTS),docker rm mongo_001)
	$(NOECHO) $(DO) $(call if_running,acmeair_authservice,docker stop acmeair_authservice)
	$(NOECHO) $(DO) $(call if_container,acmeair_authservice,$(EXISTS),docker rm acmeair_authservice)
	$(NOECHO) $(DO) $(call if_running,acmeair_web,docker stop acmeair_web)
	$(NOECHO) $(DO) $(call if_container,acmeair_web,$(EXISTS),docker rm acmeair_web)
	$(NOECHO) $(DO) $(call if_running,acmeair_workload,docker stop acmeair_workload)
	$(NOECHO) $(DO) $(call if_container,acmeair_workload,$(EXISTS),docker rm acmeair_workload)

distclean: clean
	$(NOECHO) $(DO) $(call if_image,acmeair/web,$(EXISTS),docker rmi acmeair/web)
	$(NOECHO) $(DO) $(call if_image,docker.io/mongo,$(EXISTS),docker rmi docker.io/mongo)
	$(NOECHO) $(DO) $(call if_image,acmeair/workload,$(EXISTS),docker rmi acmeair/workload)
	$(NOECHO) $(DO) $(call if_image,noise:httpd,$(EXISTS),docker rmi noise:httpd)
	$(NOECHO) $(RM) -rf acmeair-nodejs

imageclean: distclean
	$(NOECHO) $(RM) -rf noise/httpd/images
