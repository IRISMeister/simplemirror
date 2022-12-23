#!/bin/bash
chmod -fR 777 iris1A 
chmod -fR 777 iris1B 
chmod -fR 777 iris1D
chmod -fR 777 iris2A 
chmod -fR 777 iris2B 
chmod -fR 777 iris2R 

echo "Staring arbiter"
docker-compose up -d arbiter

# primaries
echo "Staring primaries"
docker-compose up -d ap1a ap2a
docker-compose exec -T ap1a bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"
docker-compose exec -T ap2a bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"
# join backups
echo "Staring backups"
docker-compose up -d ap1b ap2b
docker-compose exec -T ap1b bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"
docker-compose exec -T ap2b bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring a DR"
docker-compose up -d ap1d
docker-compose exec -T ap1d bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring a reporting"
docker-compose up -d ap2r
docker-compose exec -T ap2r bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

# webgws and LBs
docker-compose up -d webgw1 webgw2 nginx haproxy
# give them a moment

# defer populate data until mirror cluste is all set.
echo "Populating data"
#docker-compose exec -T ap1a bash -c "/ISC/utiles/populate-data.sh"
#docker-compose exec -T ap2a bash -c "/ISC/utiles/populate-data.sh"

docker-compose ps
