#!/bin/bash
chmod -fR 777 iris2A 
chmod -fR 777 iris2B 
chmod -fR 777 iris2R 
# primaries
echo "Staring a primary"
docker compose up -d ap2a
docker compose exec -T ap2a bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring backups"
docker compose up -d ap2b
docker compose exec -T ap2b bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring a reporting"
docker compose up -d ap2r
docker compose exec -T ap2r bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

# webgw
docker compose up -d webgw1

# wait until primary is ready
sleep 3
# defer populate data until mirror cluste is all set.
echo "Populating data"
docker compose exec -T ap2a bash -c "/ISC/utiles/populate-data.sh"

docker compose ps
./endpoints.sh
