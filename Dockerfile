FROM intersystemsdc/irishealth-community:preview as builder

RUN \
	--mount=type=bind,src=.,dst=/irisdev/app \
	--mount=type=bind,src=./iris.script,dst=/tmp/iris.script \
	iris start IRIS && \
	iris session IRIS < /tmp/iris.script && \
	iris stop iris quietly

FROM intersystemsdc/irishealth-community:preview as final

COPY . /irisdev/app

ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} https://github.com/grongierisc/iris-docker-multi-stage-script/releases/latest/download/copy-data.py /irisdev/app/copy-data.py

RUN --mount=type=bind,source=/,target=/builder/root,from=builder \
    cp -f /builder/root/usr/irissys/iris.cpf /usr/irissys/iris.cpf && \
    python3 /irisdev/app/copy-data.py -c /usr/irissys/iris.cpf -d /builder/root/ 

USER root

# Update package and install sudo
RUN apt-get update && apt-get install -y \
	git \
	nano \
	openjdk-11-jdk \
	sudo && \
	/bin/echo -e ${ISC_PACKAGE_MGRUSER}\\tALL=\(ALL\)\\tNOPASSWD: ALL >> /etc/sudoers && \
	sudo -u ${ISC_PACKAGE_MGRUSER} sudo echo enabled passwordless sudo-ing for ${ISC_PACKAGE_MGRUSER}

USER ${ISC_PACKAGE_MGRUSER}

# build the java wrapper
RUN mkdir -p /tmp/java/Suchi
RUN mkdir -p /tmp/java/lib && \
	cd /tmp/java/lib && \
	wget https://github.com/grongierisc/iris-fhir-validation/releases/download/v0.0.1/validator_cli.jar 
COPY src/java/Suchi /tmp/java/Suchi

RUN cd /tmp/java/Suchi && \
	mkdir -p /tmp/java/lib && \
	javac JavaValidatorFacade.java -classpath ../lib/validator_cli.jar -d . 

# Python stuff
ENV IRISUSERNAME "SuperUser"
ENV IRISPASSWORD "SYS"
ENV IRISNAMESPACE "FHIRSERVER"
ENV IRISINSTALLDIR $ISC_PACKAGE_INSTALLDIR
ENV LD_LIBRARY_PATH=$IRISINSTALLDIR/bin:$LD_LIBRARY_PATH