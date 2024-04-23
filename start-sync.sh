#!/bin/bash
chmod -fR 777 iris1A 
chmod -fR 777 iris1B 

echo "Staring arbiter"
docker-compose up -d arbiter

# primaries
echo "Staring a primary"
docker-compose up -d ap1a
docker-compose exec -T ap1a bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

echo "Staring a backup"
docker-compose up -d ap1b
docker-compose exec -T ap1b bash -c "\$ISC_PACKAGE_INSTALLDIR/dev/Cloud/ICM/waitISC.sh '' 60"

# webgw
docker-compose up -d webgw1

# Backupがキャッチアップ状態になるまで待つ
for ((i=0; i < 30; i++)); do
    latency=$(docker compose exec ap1b iris session iris -U%SYS "##class(Mirror.Installer).DatabaseTimeLatency(\"AP1B/IRIS\")")
    echo $latency
    if [ -z "$latency" ]
    then
        continue
    fi
    # 初期に「キャッチアップ」になることがある模様。その後に再度「要チェック状態」になるので、この条件だけでは空振りする。
    if [ "$latency" == "キャッチアップ" ]
    then
        break
    fi
	echo "retrying..."
	sleep 10
done

# gmheap関連のエラーの有無の確認
# docker compose exec ap1b grep fail /usr/irissys/mgr/messages.log
# docker compose exec ap1b grep SHM /usr/irissys/mgr/messages.log

docker-compose ps
./endpoints.sh
