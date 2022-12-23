#!/bin/bash
chmod -fR 777 iris1A 
chmod -fR 777 iris1D 

# primaries
echo "Staring a primary"
docker-compose up -d ap1a
docker-compose exec -T ap1a bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring a DR"
docker-compose up -d ap1d
docker-compose exec -T ap1d bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

# webgw
docker-compose up -d webgw1

# wait until primary is ready
sleep 3
# defer populate data until mirror cluste is all set.
echo "Populating data"
#docker-compose exec -T ap1a bash -c "/ISC/utiles/populate-data.sh"

docker-compose ps
