#!/bin/bash
docker-compose up -d mirrorA
docker-compose -f docker-compose-single-ni.yml exec -T mirrorA bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 30"
docker-compose up -d mirrorB
docker-compose ps
