WS_HOST=localhost
WS_PORT=8181
CLI_VERSION=2.1.0
CLI_PLATFORM=darwin_386

# requires make 3.82
.ONESHELL :
SHELL = bash

check : cli/dp2
	set -e
	docker build -t benetech-pipeline .
	CONTAINER_ID=$$( docker run -d -p 0.0.0.0:${WS_PORT}:8181 benetech-pipeline )
	sleep 5
	while ! curl ${WS_HOST}:${WS_PORT}/ws/alive >/dev/null 2>/dev/null; do
	    echo "Waiting for web service to be up..." >&2
	    sleep 2
	done
	curl ${WS_HOST}:${WS_PORT}/ws/alive 2>/dev/null | grep 'localfs="false"' >/dev/null
	DTBOOK=samples/minimal.xml
	mkdir tmp
	DATA="tmp/$$(basename $$DTBOOK).zip"
	zip -r "$$DATA" "$$DTBOOK"
	cli/dp2 --host http://${WS_HOST} --port ${WS_PORT} \
	        dtbook-to-epub3 --data "$$DATA" --persistent --source "$$DTBOOK" --output tmp
	sleep 1
	JOB_ID=$$( cli/dp2 --host http://${WS_HOST} --port ${WS_PORT} jobs 2>&1 | tail -n 1 | awk '{print $$1}' )
	cli/dp2 --host http://${WS_HOST} --port ${WS_PORT} status $$JOB_ID 2>&1
	docker stop $$CONTAINER_ID >/dev/null
	docker rm $$CONTAINER_ID >/dev/null
	rm -r tmp

clean :
	rm -rf tmp
	docker rm $$(docker stop $$(docker ps -a -q --filter ancestor=benetech-pipeline --format="{{.ID}}"))

cli/dp2 :
	set -e
	mkdir cli
	cd cli
	mvn org.apache.maven.plugins:maven-dependency-plugin:3.0.0:copy \
	    -Dartifact=org.daisy.pipeline:cli:${CLI_VERSION}:zip:${CLI_PLATFORM} \
	    -DoutputDirectory=.
	unzip cli-${CLI_VERSION}-${CLI_PLATFORM}.zip
	echo "client_key: clientid" >> config.yml
	echo "client_secret: supersecret" >> config.yml
