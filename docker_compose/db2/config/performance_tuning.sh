#!/usr/bin/env bash

# Need to run the script as the DB2 Owner
if [[ "$(whoami)" != "${DB2INSTANCE}" ]]; then
  # Steals environment variables from the DB2 Owner
  export "$(sudo -Hiu "${DB2INSTANCE}" env | grep "DB2_HOME=")"
  export PATH=${PATH}:${DB2_HOME}/bin:${DB2_HOME}/adm

  # Call this same script but as DB2 Owner
  echo "Running the script as ${DB2INSTANCE}"
  sudo -Eu "${DB2INSTANCE}" bash "$0" "$@"
  exit
fi

# Exporting New Path to Call DB2 Binaries
export PATH=${PATH}:${DB2_HOME}/bin:${DB2_HOME}/adm

echo "Tuning DB2 Instance: ${DBNAME}"

echo "Setting General DB2 Configurations"
db2 update dbm cfg using notifylevel 0
db2 update dbm cfg using diaglevel 1
db2 update dbm cfg using NUM_POOLAGENTS "${NUM_POOLAGENTS:-500}" automatic MAX_COORDAGENTS "${MAX_COORDAGENTS:-500}" automatic MAX_CONNECTIONS "${MAX_CONNECTIONS:-500}" automatic
db2 -v update db cfg for "${DBNAME}" using MAXLOCKS "${MAXLOCKS:-100}" LOCKLIST "${LOCKLIST:-100000}"

echo "Setting DB2 Configurations for ${DBNAME}"
db2 connect to "${DBNAME}"
db2 update db cfg for "${DBNAME}" using maxappls "${MAXAPPLS:-500}" automatic
db2 update db cfg for "${DBNAME}" using logfilsiz "${LOGFILSIZ:-8000}"
db2 update db cfg for "${DBNAME}" using logprimary "${LOGPRIMARY:-32}"
db2 update db cfg for "${DBNAME}" using dft_queryopt "${DFT_QUERYOPT:-0}"
db2 update db cfg for "${DBNAME}" using softmax "${SOFTMAX:-3000}"
db2 update db cfg for "${DBNAME}" using chngpgs_thresh "${CHNGPGS_THRESH:-99}"
db2 -v alter bufferpool IBMDEFAULTBP size "${BUFFERPOOL_SIZE:--1}"
db2 -v connect reset
db2 -v update db cfg for "${DBNAME}" using BUFFPAGE "${BUFFPAGE:-262144}"

echo "Setting DB2 Variables"
db2set DB2_APM_PERFORMANCE="${DB2_APM_PERFORMANCE:-ON}"
db2set DB2_KEEPTABLELOCK="${DB2_KEEPTABLELOCK:-CONNECTION}"
db2set DB2_USE_ALTERNATE_PAGE_CLEANING="${DB2_USE_ALTERNATE_PAGE_CLEANING:-ON}"
db2set DB2_MINIMIZE_LISTPREFETCH="${DB2_MINIMIZE_LISTPREFETCH:-YES}"
db2set DB2_LOGGER_NON_BUFFERED_IO="${DB2_LOGGER_NON_BUFFERED_IO:-OFF}"

echo "Reloading DB2"
db2 connect reset
db2 terminate
db2stop force
db2start

echo "Connecting to DB2 and Issuing REORGCHK"
db2 connect to "${DBNAME}"
db2 reorgchk update statistics

echo "Tuning Completed! Restarting DB2....."
db2 connect reset
db2 terminate
db2stop force
db2start

echo "Restart Complete!"