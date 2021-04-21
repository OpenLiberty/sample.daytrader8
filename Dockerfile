FROM open-liberty:full

COPY --chown=1001:0 src/main/liberty/config/server.xml /config/server.xml
COPY --chown=1001:0 src/main/liberty/config/bootstrap.properties /config/bootstrap.properties
COPY --chown=1001:0 target/io.openliberty.sample.daytrader8.war /config/apps/

#Derby
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/DerbyLibs/derby-10.14.2.0.jar /opt/ol/wlp/usr/shared/resources/DerbyLibs/derby-10.14.2.0.jar
COPY --chown=1001:0 target/liberty/wlp/usr/shared/resources/data /opt/ol/wlp/usr/shared/resources/data

ENV MAX_USERS=1000
ENV MAX_QUOTES=500

#RUN configure.sh
