#!/bin/bash

echo "Sleeping until DB2 is Ready: ${SLEEP_TIME}" seconds
sleep "${SLEEP_TIME}"s
echo "Slept for ${SLEEP_TIME} seconds!"

echo "Building DayTrader Tables hitting: ${JPROTOCOL}://${JHOST}:${JPORT}/daytrader/config?action=buildDBTables ............"
curl -i -X GET "${JPROTOCOL}://${JHOST}:${JPORT}/daytrader/config?action=buildDBTables"

echo "Building DayTrader Database hitting: ${JPROTOCOL}://${JHOST}:${JPORT}/daytrader/config?action=buildDB ............"
curl -i -X GET "${JPROTOCOL}://${JHOST}:${JPORT}/daytrader/config?action=buildDB"

echo "Running JMeter with the following command: jmeter -n -t ${JMX_FILE} -l ${JTL_LOG_FILE} -JHOST=${JHOST} -JPORT=${JPORT} -JPROTOCOL=${JPROTOCOL} -JTHREADS=${JTHREADS} -JRAMP=${JRAMP} -JDURATION=${JDURATION} -JMAXTHINKTIME=${JMAXTHINKTIME} -JSTOCKS=${JSTOCKS} -JBOTUID=${JBOTUID} -JTOPUID=${JTOPUID} ......."
jmeter -n -t ${JMX_FILE} -l ${JTL_LOG_FILE} -JHOST=${JHOST} -JPORT=${JPORT} -JPROTOCOL=${JPROTOCOL} -JTHREADS=${JTHREADS} -JRAMP=${JRAMP} -JDURATION=${JDURATION} -JMAXTHINKTIME=${JMAXTHINKTIME} -JSTOCKS=${JSTOCKS} -JBOTUID=${JBOTUID} -JTOPUID=${JTOPUID}