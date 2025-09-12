# Documentation in English is work in progress
Documentation in English is still work in progress and outdated somehow.
# About
This is a No VIP mirror configuration.
(VIP dosen't work in container anyway.)

# How to setup.
I'm using Dmitriy's web gateway container.
https://community.intersystems.com/post/apache-and-containerised-iris

You have to build it after overwrting webgateway-entrypoint.sh and webgateway.conf provided by my repo in order to make it 
- mirror aware
- recognize /api/

```
$ git clone --recursive https://github.com/IRISMeister/simplemirror.git
$ cd simplemirror
$ cp ./webgateway* iris-webgateway-example/
$ docker compose -f iris-webgateway-example/docker compose.yml build
$ place ./iris.key (valid iris license key for container)
$ ./start-single-bridge.sh   (mimics typical cloud env where you have only one NIC)
or
$ ./start.sh
```

# Web endpoints

web g/w portal
```
http://irishost:8080/csp/bin/Systems/Module.cxw      (webgw1)
http://irishost:8081/csp/bin/Systems/Module.cxw      (webgw2)
http://irishost/csp/bin/Systems/Module.cxw           (via NGINX to webgw1 or webgw2)-> Don't use this
```

system management portal
```
http://irishost:8080/ap1a/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, AP1A)
http://irishost:8080/ap1b/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, AP1B)
http://irishost:8080/ap2a/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, AP2A)
http://irishost:8080/ap2b/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, AP2B)
http://irishost:8081/ap1a/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, AP1A)
http://irishost:8081/ap1b/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, AP1B)
http://irishost:8081/ap2a/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, AP2A)
http://irishost:8081/ap2b/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, AP2B)
http://irishost:8080/ap1/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, primary member of AP1 cluster, Don't use this)
http://irishost:8081/ap1/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, primary member of AP1 cluster, Don't use this)
http://irishost:8080/ap2/csp/sys/%25CSP.Portal.Home.zen  (via webgw1, primary member of AP2 cluster, Don't use this)
http://irishost:8081/ap2/csp/sys/%25CSP.Portal.Home.zen  (via webgw2, primary member of AP2 cluster, Don't use this)
```


IRIS provided REST APIs
```
http://irishost:8080/ap1a/api/mgmnt/ -u SuperUser:SYS  (via webgw1, AP1A)
http://irishost:8080/ap1b/api/mgmnt/ -u SuperUser:SYS  (via webgw1, AP1B)
http://irishost:8080/ap2a/api/mgmnt/ -u SuperUser:SYS  (via webgw1, AP2A)
http://irishost:8080/ap2b/api/mgmnt/ -u SuperUser:SYS  (via webgw1, AP2B)
http://irishost:8081/ap1a/api/mgmnt/ -u SuperUser:SYS  (via webgw2, AP1A)
http://irishost:8081/ap1b/api/mgmnt/ -u SuperUser:SYS  (via webgw2, AP1B)
http://irishost:8081/ap2a/api/mgmnt/ -u SuperUser:SYS  (via webgw2, AP2A)
http://irishost:8081/ap2b/api/mgmnt/ -u SuperUser:SYS  (via webgw2, AP2B)
http://irishost:8080/ap1/api/mgmnt/ -u SuperUser:SYS  (via webgw1, primary member of AP1 cluster)
http://irishost:8081/ap1/api/mgmnt/ -u SuperUser:SYS  (via webgw2, primary member of AP1 cluster)
http://irishost:8080/ap2/api/mgmnt/ -u SuperUser:SYS  (via webgw1, primary member of AP2 cluster)
http://irishost:8081/ap2/api/mgmnt/ -u SuperUser:SYS  (via webgw2, primary member of AP2 cluster)
http://irishost/ap1/api/mgmnt/ -u SuperUser:SYS       (via NGINX, primary member of AP1 cluster)
http://irishost/ap2/api/mgmnt/ -u SuperUser:SYS       (via NGINX, primary member of AP2 cluster)
```

Health Check for NGINX(LB) (with mirror aware webgw, you probably don't need this)
```
http://irishost:8080/ap1a/csp/mirror_status.cxw    (via webgw1, ap1a)
http://irishost:8080/ap1b/csp/mirror_status.cxw    (via webgw1, ap1b)
http://irishost:8080/ap2a/csp/mirror_status.cxw    (via webgw1, ap2a)
http://irishost:8080/ap2b/csp/mirror_status.cxw    (via webgw1, ap2b)
http://irishost:8081/ap1a/csp/mirror_status.cxw    (via webgw2, ap1a)
http://irishost:8081/ap1b/csp/mirror_status.cxw    (via webgw2, ap1b)
http://irishost:8081/ap2a/csp/mirror_status.cxw    (via webgw2, ap2a)
http://irishost:8081/ap2b/csp/mirror_status.cxw    (via webgw2, ap2b)
```

App end point
```
http://irishost/ap1/csp/mirrorns/api/get -s | jq
http://irishost/ap2/csp/mirrorns/api/get -s | jq
```

# HealthCheck endpoints and their behaivor. These are what LB will see.
Only NGINX Plus (not free) has Active Health Checks ability. So it's passive (meaning not using mirror_status.cxw).

## app1a:Primary, app1b:Backup 
```
$ curl -m 5 http://irishost:8080/ap1a/csp//mirror_status.cxw -v
$ curl -m 5 http://irishost:8081/ap1a/csp//mirror_status.cxw -v
< HTTP/1.1 200 OK
SUCCESS
$ curl -m 5 http://irishost:8080/ap1b/csp//mirror_status.cxw -v
$ curl -m 5 http://irishost:8081/ap1b/csp//mirror_status.cxw -v
< HTTP/1.1 503 Service Unavailable
FALIED
```

## app1a:down, app1b:Primary
```
$ docker compose -f docker compose-single-ni.yml exec ap1a iris stop iris quietly
$ curl -m 5 http://irishost:8080/ap1b/csp/mirror_status.cxw -v
< HTTP/1.1 200 OK
SUCCESS
```

## app1a:down, app1b:down
```
$ docker compose -f docker compose-single-ni.yml exec ap1b iris stop iris quietly
$ curl -m 5 http://irishost:8080/ap1a/csp//mirror_status.cxw -v
```
curl timeouts... LB shold handle this.

## app1a:Primary, app1b:down
```
$ docker compose -f docker compose-single-ni.yml exec ap1a iris start iris quietly
$ curl -m 5 http://irishost:8080/ap1a/csp//mirror_status.cxw -v
< HTTP/1.1 200 OK
SUCCESS
$ curl -m 5 http://irishost:8080/ap1b/csp//mirror_status.cxw -v
```
curl timeouts... LB shold handle this.

Let's abuse to see nothing wrong happens.
```
$ curl -m 5 http://irishost:8080/ap1a/csp//mirror_status.cxw?[1-20]
$ curl -m 5 http://irishost:8080/ap1b/csp//mirror_status.cxw?[1-20]
```

If you see lots of [Status=Server] on webgw management portal, disable it.
```
[SYSTEM]
REGISTRY_METHODS=Disabled
https://wrc.intersystems.com/wrc/ProblemViewTabs.csp?OBJID=903951
```

# App REST tests
## app1a:Primary, app1b:Backup 
```
$ curl http://irishost/ap1/csp/mirrorns/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "SuperUser",
  "Status": "OK",
  "TimeStamp": "02/24/2021 21:11:04",
  "ImageBuilt": ""
}
```

## app1a:down, app1b:Primary
```
$ docker compose -f docker compose-single-ni.yml exec ap1a iris stop iris quietly
$ curl http://irishost/ap1/csp/mirrorns/api/get -s | jq
{
  "HostName": "ap1b",
  "UserName": "SuperUser",
  "Status": "OK",
  "TimeStamp": "02/24/2021 21:12:57",
  "ImageBuilt": ""
}
```

## app1a:down, app1b:down
```
$ docker compose -f docker compose-single-ni.yml exec ap1b iris stop iris quietly
$ curl http://irishost/ap1/csp/mirrorns/api/get 
```
Timeouts. Tooks a while.

## app1a:Primary, app1b:down
```
$ docker compose -f docker compose-single-ni.yml exec ap1a iris start iris quietly
$ curl http://irishost/ap1/csp/mirrorns/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "SuperUser",
  "Status": "OK",
  "TimeStamp": "02/24/2021 21:31:13",
  "ImageBuilt": ""
}
```

## app1a:Primary, app1b:down, webgw1:down
```
$ docker compose stop webgw1
Stopping webgw ... done
$ curl http://irishost/ap1/csp/mirrorns/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "SuperUser",
  "Status": "OK",
  "TimeStamp": "02/24/2021 21:33:11",
  "ImageBuilt": ""
}
```

## My tests to see if Virtual IP is available in container or not  
... I guess not.
```
root@mirrorA:/home/irisowner# apt-get update
root@mirrorA:/home/irisowner# apt-get install -y arping
root@mirrorA:/home/irisowner# apt -y install network-manager

root@mirrorA:/home/irisowner# nmcli c m eth0 +ipv4.address 10.0.100.5/24
Error: Could not create NMClient object: Could not connect: No such file or directory.
root@mirrorA:/home/irisowner#
root@mirrorA:/home/irisowner# ip addr add 10.0.100.5/24 dev eth0
RTNETLINK answers: Operation not permitted
```

# Force some system events in Arbiter Controlled Mode 
https://docs.intersystems.com/irislatest/csp/docbook/Doc.View.cls?KEY=GHA_mirror_set#GHA_mirror_set_autofail_details_arbmode

If the connection between the primary and the backup is broken in arbiter controlled mode, each failover member responds based on the state of the arbiter connections as described in the following.
> Primary Loses Connection to Backup  
> If the primary loses its connection to an active backup, or exceeds the QoS timeout waiting for it to...   

This is 6th case of Mirror Responses to Lost Connections.
https://docs.intersystems.com/irislatest/csp/docbook/images/gha_mirror_response_lost_connections.png

```
$ docker network disconnect simplemirror_iris-tier mirrorB ; docker network disconnect simplemirror_arbiter-tier mirrorB
```
...mirrorA will be switche to "agent controlled mode"

```
$ docker compose exec mirrorB iris session iris -U %SYS MIRROR
%SYS>D ^MIRROR
1) Mirror Status
4) Status Monitor
Status of Mirror MIRRORSET at 10:15:59 on 12/24/2020
Incoming Journal Transfer Rate for This Member (over refresh interval)
 0.00 KB/s (11s interval)

Arbiter Connection Status:
     Arbiter Address:   10.0.100.10|2188
     Failover Mode:     Agent Controlled
     Connection Status: This member is not connected to the arbiter

                                       Journal Transfer
Member Name+Type            Status        Latency       Dejournal Latency
--------------------------  ---------  ---------------  --------------
MIRRORA
     Failover               Down       Disconnected on 12/24/2020 10:15:15.12
MIRRORB
     Failover               Waiting    Disconnected on 12/24/2020 10:15:15.12
```

> If the primary learns that the arbiter is still connected to the backup...

This is 4th case of Mirror Responses to Lost Connections.
```
$ docker network disconnect simplemirror_iris-tier mirrorA
```

> If the primary has lost its arbiter connection as well as its connection to the backup, it remains in the trouble state indefinitely so
> that the backup can safely take over.  If failover occurs, when the connection is restored the primary shuts down.

This is 7th case of Mirror Responses to Lost Connections.
!!! This is the only case which backup takes over automatically !!!

```
$ docker network disconnect simplemirror_iris-tier mirrorA ; docker network disconnect simplemirror_arbiter-tier mirrorA
```
...mirrorB will become Primary automatically.

```
$ docker network connect simplemirror_iris-tier mirrorA 
```
...eventually mirrorA will be force shutdown.
```
$ docker compose exec mirrorA iris list
        status:       down, last used Thu Dec 24 09:21:10 2020
```

## Interesting read
https://qiita.com/BooookStore/items/5862515209a31658f88c