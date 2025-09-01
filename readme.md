# 目的
[オリジナル](https://github.com/mariosanchez23/simplemirror)を元に、クラウド、コンテナ内などVIPを使用しない(動作しない)環境でのミラー構成の例を作成しました。手元で(コストを気にせず)気軽にいろいろと試せる環境の作成を目的にしています。  
ミラーを使用するため、コミュニティエディションでは動作しません。[ミラーが有効なx64コンテナ用のライセンスキー](https://wrc.intersystems.com/wrc/coDistEvaluation.csp) をご用意ください。

# 導入方法
```
$ cp ミラーが有効なx64コンテナ用のライセンスキー ./iris.key
```

# 起動方法
```
$ ./start-all.sh
```
> docker-compose up で起動しないでください。起動手順にdocker-composeでは制御しきれない依存関係があります。
> また、特定のコンポーネントの起動・停止状態を可能とするために、意図的に依存性(depends_on)をはずしています。

多数のコンテナ(11個、うち6個がIRISインスタンス)が作成されるため、多数のCPU/メモリ消費とDISK I/Oが発生します。コンテナ実行環境によっては不測のエラーが発生するかもしれません。目的に応じてより軽量な環境を起動する事が出来ます。

|スクリプト|環境|
|:--|:--|
|start-all.sh|全て起動|
|start-dr.sh|プライマリ+非同期DR+WebServer１台|
|start-reporting.sh|プライマリ+非同期レポーティング+WebServer１台|
|start-sync-dr.sh|プライマリ+バックアップ+非同期DR+WebServer１台|
|start-sync-reporting.sh|プライマリ+バックアップ+非同期レポーティング+WebServer１台|
|start-sync.sh|プライマリ+バックアップ+WebServer１台|


# 停止方法
```
$ ./stop.sh
```

# うまく動作しない場合
起動中にIRIS内でエラーが発生した場合、各サービスの出力にエラーが記録されています。
```
$ docker-compose logs ap1a
$ docker-compose logs ap1b
```

# コンテナ群
起動すると、下記のコンテナ群を起動します。
|コンテナサービス名|コンテナイメージ|Web公開ポート|用途|AWSでの読み替え|
|:--|:--|:--|:--|:--|
|nginx|nginx|80|LB。Web gateway用のreverse proxyとして機能|外部LB|
|webgw1|ビルド|8080|Web gateway #1|EC2|
|webgw2|ビルド|8081|Web gateway #2|EC2|
|ap1a|iris|NA|ミラーセットAP1のメンバ|EC2|
|ap1b|iris|NA|ミラーセットAP1のメンバ|EC2|
|ap2a|iris|NA|ミラーセットAP2のメンバ|EC2|
|ap2b|iris|NA|ミラーセットAP2のメンバ|EC2|
|haproxy|ビルド|80|LB。IRIS SuperServer用のreverse proxyとして機能|内部LB|

- AP1,AP2はそれぞれHAミラークラスタを構成する単位です。AP1はap1a,ap1bコンテナで構成されます。同様にAP2はap2a,ap2bコンテナで構成されます。以後、ミラーセットAP1,ミラーセットAP2と称します。
- Web gateway #1と#2は負荷分散目的で、全く同じ構成を持ちます。
- NGINXは上記、Web gateway #1,#2をアップストリームに持つreverse proxyとして機能します。
- haproxyはIRISのSuperServerをアップストリームに持つreverse proxyとして構成され、ミラーのVirtual IPの代替えとして機能します。
- 各コンテナは、ポート番号が重複しないように、ポートを変更してホストO/Sにエンドポイントを公開しています。  
- IRISの構成には[cpfマージ](cpf/merge.cpf)を使用しています。ミラー構成のために、gmheapを増やしています。
- 各コンテナ要素をAWSの要素に置き換えて考えることができます。その場合、docker-composeはVPC環境、ホストO/SはVPCの外側に相当すると考えます。

![構成図](https://github.com/IRISMeister/doc-images/blob/main/simplemirror/diagram.png)

# Web endpoints
Webサーバが複数(専用Apache×2, IRIS同梱のApache×4, LB代わりのNGINXの計7台)存在するため、多数のエンドポイントが用意されますが、主たる用途を考慮すると使用に適したものは限定されます。

## Web gateway management portal
利便性のため、全てのポートをO/Sに公開しています。管理画面なので、AWS環境では、外部(LB)からのアクセスは無く、踏み台ホストからのアクセスが主になると想定しています。

|要素|エンドポイント|備考|
|:--|:--|:--|
|Web Gateway#1|http://irishost:8080/csp/bin/Systems/Module.cxw||
|Web Gateway#2|http://irishost:8081/csp/bin/Systems/Module.cxw||
|NGINX|http://irishost/csp/bin/Systems/Module.cxw|本用途に不向き|

## 管理ポータル
利便性のため、全てのポートをO/Sに公開しています。管理画面なので、AWS環境では、外部(LB)からのアクセスは無く、踏み台ホストからのアクセスが主になると想定しています。

|要素|エンドポイント|備考|
|:--|:--|:--|
|Web Gateway#1|http://irishost:8080/ap1a/csp/sys/%25CSP.Portal.Home.zen|AP1A|
|Web Gateway#1|http://irishost:8080/ap1b/csp/sys/%25CSP.Portal.Home.zen|AP1B|
|Web Gateway#1|http://irishost:8080/ap1d/csp/sys/%25CSP.Portal.Home.zen|AP1D|
|Web Gateway#1|http://irishost:8080/ap2a/csp/sys/%25CSP.Portal.Home.zen|AP2A|
|Web Gateway#1|http://irishost:8080/ap2b/csp/sys/%25CSP.Portal.Home.zen|AP2B|
|Web Gateway#1|http://irishost:8080/ap2r/csp/sys/%25CSP.Portal.Home.zen|AP2R|
|Web Gateway#2|http://irishost:8081/ap1a/csp/sys/%25CSP.Portal.Home.zen|AP1A|
|Web Gateway#2|http://irishost:8081/ap1b/csp/sys/%25CSP.Portal.Home.zen|AP1B|
|Web Gateway#2|http://irishost:8081/ap1d/csp/sys/%25CSP.Portal.Home.zen|AP1D|
|Web Gateway#2|http://irishost:8081/ap2a/csp/sys/%25CSP.Portal.Home.zen|AP2A|
|Web Gateway#2|http://irishost:8081/ap2b/csp/sys/%25CSP.Portal.Home.zen|AP2B|
|Web Gateway#2|http://irishost:8081/ap2r/csp/sys/%25CSP.Portal.Home.zen|AP2R|
|Web Gateway#1|http://irishost:8080/ap1/csp/sys/%25CSP.Portal.Home.zen |ミラーセットAP1のプライマリメンバ,本用途に不向き|
|Web Gateway#1|http://irishost:8080/ap2/csp/sys/%25CSP.Portal.Home.zen |ミラーセットAP2のプライマリメンバ,本用途に不向き|
|Web Gateway#2|http://irishost:8081/ap1/csp/sys/%25CSP.Portal.Home.zen |ミラーセットAP1のプライマリメンバ,本用途に不向き|
|Web Gateway#2|http://irishost:8081/ap2/csp/sys/%25CSP.Portal.Home.zen |ミラーセットAP2のプライマリメンバ,本用途に不向き|

## IRIS提供の管理用REST API

|要素|エンドポイント|備考|
|:--|:--|:--|
|Web Gateway#1|http://irishost:8080/ap1a/api/mgmnt/|AP1A|
|Web Gateway#1|http://irishost:8080/ap1b/api/mgmnt/|AP1B|
|Web Gateway#1|http://irishost:8080/ap1d/api/mgmnt/|AP1D|
|Web Gateway#1|http://irishost:8080/ap2a/api/mgmnt/|AP2A|
|Web Gateway#1|http://irishost:8080/ap2b/api/mgmnt/|AP2B|
|Web Gateway#1|http://irishost:8080/ap2r/api/mgmnt/|AP2R|
|Web Gateway#2|http://irishost:8081/ap1a/api/mgmnt/|AP1A|
|Web Gateway#2|http://irishost:8081/ap1b/api/mgmnt/|AP1B|
|Web Gateway#2|http://irishost:8081/ap1d/api/mgmnt/|AP1D|
|Web Gateway#2|http://irishost:8081/ap2a/api/mgmnt/|AP2A|
|Web Gateway#2|http://irishost:8081/ap2b/api/mgmnt/|AP2B|
|Web Gateway#2|http://irishost:8081/ap2r/api/mgmnt/|AP2R|
|Web Gateway#1|http://irishost:8080/ap1/api/mgmnt/ |ミラーセットAP1のプライマリメンバ,用途次第|
|Web Gateway#1|http://irishost:8080/ap2/api/mgmnt/ |ミラーセットAP2のプライマリメンバ,用途次第|
|Web Gateway#2|http://irishost:8081/ap1/api/mgmnt/ |ミラーセットAP1のプライマリメンバ,用途次第|
|Web Gateway#2|http://irishost:8081/ap2/api/mgmnt/|ミラーセットAP2のプライマリメンバ,用途次第|

- アクセス時には認証が必要です
```
$ curl http://irishost:8080/ap1a/api/mgmnt/ -u SuperUser:SYS -s | jq
```

## Health Check 
特定のミラーメンバのロール(プライマリか、それ以外か)を調べるためのエンドポイントです。

|要素|エンドポイント|備考|
|:--|:--|:--|
|Web Gateway#1|http://irishost:8080/ap1a/csp/mirror_status.cxw|AP1A|
|Web Gateway#1|http://irishost:8080/ap1b/csp/mirror_status.cxw|AP1B|
|Web Gateway#1|http://irishost:8080/ap2a/csp/mirror_status.cxw|AP2A|
|Web Gateway#1|http://irishost:8080/ap2b/csp/mirror_status.cxw|AP2B|
|Web Gateway#2|http://irishost:8081/ap1a/csp/mirror_status.cxw|AP1A|
|Web Gateway#2|http://irishost:8081/ap1b/csp/mirror_status.cxw|AP1B|
|Web Gateway#2|http://irishost:8081/ap2a/csp/mirror_status.cxw|AP2A|
|Web Gateway#2|http://irishost:8081/ap2b/csp/mirror_status.cxw|AP2B|

## ユーザ作成のRESTアプリケーション
下記のエンドポイントに、IRISホスト名などの情報をJSONで返却する簡単なRESTアプリケーションを用意してあります。

|要素|エンドポイント|備考|
|:--|:--|:--|
|NGINX|http://irishost/ap1/csp/user/api/get|ミラーセットAP1のプライマリメンバ|
|NGINX|http://irishost/ap2/csp/user/api/get|ミラーセットAP2のプライマリメンバ|
|Web Gateway#1|http://irishost:8080/ap1/csp/user/api/get|ミラーセットAP1のプライマリメンバ|
|Web Gateway#2|http://irishost:8080/ap2/csp/user/api/get|ミラーセットAP2のプライマリメンバ|

```
$ curl http://irishost:8080/ap1a/csp/user/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "UnknownUser",
  "Status": "OK",
  "TimeStamp": "02/08/2023 16:21:00"
}
```

# 動作確認
各ミラーの状態に置ける、Health CheckとRESTアプリケーションの応答は下記のようになります。  
注意) Active Health Checksは有償のNGINX Plusのみで提供されているので、動作はPassiveになります。
> つまり、本例のNGINXはmirror_status.cxwは使用していません。  
InterSystems API Managerには Active Health Check機能が含まれています。

## 事前準備
もし、この時点でなんらかのアクセスを行っている場合、状態をリセットするために、いったん全コンテナの停止・起動を実行します。
```
$ ./stop.sh
$ ./start.sh
```

## 状態 ap1a:プライマリ, ap1b:バックアップ 
起動直後の状態です。Health Checkの応答は以下の通りです。  
```
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw -v
$ curl -m 5 http://irishost:8081/ap1a/csp/mirror_status.cxw -v
< HTTP/1.1 200 OK
SUCCESS
$ curl -m 5 http://irishost:8080/ap1b/csp/mirror_status.cxw -v
$ curl -m 5 http://irishost:8081/ap1b/csp/mirror_status.cxw -v
< HTTP/1.1 503 Service Unavailable
FALIED
```
RESTアプリケーションコールで、リクエストがap1a(ミラーセットAP1のプライマリメンバ)、ap2a(ミラーセットAP2のプライマリメンバ)に到達していることが確認できます。
```
$ curl http://irishost/ap1/csp/user/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "UnknownUser",
  "Status": "OK",
  "TimeStamp": "02/09/2023 12:36:26"
}
$ curl http://irishost/ap2/csp/user/api/get -s | jq
{
  "HostName": "ap2a",
  "UserName": "UnknownUser",
  "Status": "OK",
  "TimeStamp": "02/09/2023 12:36:40"
}
```
NGINXのログは下記のようになっているはずです。10.0.100.11:80(Web Gateway #1),10.0.100.12:80(Web Gateway #2)が交互に使用されています。
```
$ docker-compose logs -f nginx
nginx      | 10.0.100.1 - - [09/Feb/2023:12:36:26 +0900] "GET /ap1/csp/user/api/get HTTP/1.1" 200 103 "-" "curl/7.81.0" "-" "10.0.100.12:80"
nginx      | 10.0.100.1 - - [09/Feb/2023:12:36:40 +0900] "GET /ap2/csp/user/api/get HTTP/1.1" 200 103 "-" "curl/7.81.0" "-" "10.0.100.11:80"
```

2台のWebgatewayに、全ミラー構成(2セット)を認識させるために、下記を再実行します。
```
$ curl http://irishost/ap1/csp/user/api/get?[1-2] -s | jq
$ curl http://irishost/ap2/csp/user/api/get?[1-2] -s | jq
```
この段階で、Web gateway management portalのSystem Status画面を確認します。
- http://irishost:8080/csp/bin/Systems/Module.cxw
- http://irishost:8081/csp/bin/Systems/Module.cxw

いずれも、下記の状態(MIRROR1,MIRROR2のPrimary/Failoverを認識している,n1~n4は数値)になっている事を確認します。ServerNameに下記以外のものが存在しても問題ありません。

|ServerNumber|ServerName|MirrorMember|MirrorStatus|
|:--|:--|:--|:--|
|n1|ap1|MIRRORSET:AP1A/IRIS|Primary|
|n2|ap1|MIRRORSET:AP1B/IRIS|Failover|
|n2|ap1|MIRRORSET:AP1D/IRIS|Async|
|n3|ap2|MIRRORSET:AP2A/IRIS|Primary|
|n4|ap2|MIRRORSET:AP2B/IRIS|Failover|

> この状態になっていない場合、以後の動作は記載と異なったものとなります。

## 状態 ap1a:停止, ap1b:プライマリ
ap1aのIRISを停止して、ap1bをプライマリに昇格させた後にHealth Checkの応答を確認します。  
ap1aが応答しなくなったため、curlでtimeout(5秒)が発生しました。  
> NGINXのActive Healthcheckが利用できる環境であれば、この接続は無効にマークされますが、前述の通り、本例はPassive Healthcheckでの動作ですので、この応答は利用していません。

```
$ docker-compose exec ap1a iris stop iris quietly
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw -v
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
$ curl -m 5 http://irishost:8080/ap1b/csp/mirror_status.cxw -v
< HTTP/1.1 200 OK
SUCCESS
```
Web gatewayが、ミラーの状態を認識して、プライマリメンバにリクエストを送信するため、アプリケーションへのAPIコールは、ap1b(プライマリに昇格した元バックアップメンバ)に到達します。。

```
$ curl http://irishost/ap1/csp/user/api/get -s | jq
{
  "HostName": "ap1b",
  "UserName": "UnknownUser",
  "Status": "OK",
  "TimeStamp": "02/09/2023 13:36:04"
}
```

## 状態 ap1a:停止, ap1b:停止
ap1ミラークラスタの全IRISメンバを停止状態にします。  
Health Checkに誰も応答しないので、下記はいずれもcurlでtimeout(5秒)が発生しました。
```
$ docker-compose exec ap1b iris stop iris quietly
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw -v
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
$ curl -m 5 http://irishost:8080/ap1b/csp/mirror_status.cxw -v
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
```

アプリケーションへのAPIコールも誰も応答しないので、curlでtimeout(5秒)が発生しました。
```
$ curl -m 5 http://irishost/ap1/csp/user/api/get
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
```

curlのタイムアウトを設定しない場合、各種設定値次第ですが、どこかでタイムアウトが発生します。今回のケースでは、NGINX->Web Gateway#2がタイムアウトしました。その後、NGINXがWeb gateway #1をトライしましたが、NGINX->Web Gateway#1もタイムアウトを起こしたので、最終的にNGINXからcurlにエラー(504 Gateway Time-out)が返っています。  
(Web gatewayのServer Response Timeoutと、NGINXのproxy_xxx_timeoutの関係で決まります)

```
$ curl http://irishost/ap1/csp/user/api/get
<html>
<head><title>504 Gateway Time-out</title></head>
<body>
<center><h1>504 Gateway Time-out</h1></center>
<hr><center>nginx/1.23.3</center>
</body>
</html>
```

その様子は、下記のログで確認できます。  
14:16:17にwebgw2にリクエストが来ますが、それが1分後にタイムアウトし、14:17:17にNGINXにその旨記録されています。NGINXはその後webgw1にリクエストしますが、それも1分後の14:18:17にタイムアウトし、NGINXにその旨が記録されています。

```
$ docker-compose logs -f webgw1
  ・
  ・
webgw      | 10.0.100.13 - - [09/Feb/2023:14:17:17 +0900] "GET /ap1/csp/user/api/get HTTP/1.0" 500 -

$ docker-compose logs -f webgw2
webgw2     | 10.0.100.13 - - [09/Feb/2023:14:16:17 +0900] "GET /ap1/csp/user/api/get HTTP/1.0" 500 -

$ docker-compose logs -f nginx
  ・
  ・
nginx      | 2023/02/09 14:17:17 [warn] 28#28: *7 upstream server temporarily disabled while reading response header from upstream, client: 10.0.100.1, server: nginx, request: "GET /ap1/csp/user/api/get HTTP/1.1", upstream: "http://10.0.100.12:80/ap1/csp/user/api/get", host: "irishost"
nginx      | 2023/02/09 14:17:17 [error] 28#28: *7 upstream timed out (110: Connection timed out) while reading response header from upstream, client: 10.0.100.1, server: nginx, request: "GET /ap1/csp/user/api/get HTTP/1.1", upstream: "http://10.0.100.12:80/ap1/csp/user/api/get", host: "irishost"
nginx      | 2023/02/09 14:18:17 [warn] 28#28: *7 upstream server temporarily disabled while reading response header from upstream, client: 10.0.100.1, server: nginx, request: "GET /ap1/csp/user/api/get HTTP/1.1", upstream: "http://10.0.100.11:80/ap1/csp/user/api/get", host: "irishost"
nginx      | 10.0.100.1 - - [09/Feb/2023:14:18:17 +0900] "GET /ap1/csp/user/api/get HTTP/1.1" 504 167 "-" "curl/7.81.0" "-" "10.0.100.12:80, 10.0.100.11:80"
nginx      | 2023/02/09 14:18:17 [error] 28#28: *7 upstream timed out (110: Connection timed out) while reading response header from upstream, client: 10.0.100.1, server: nginx, request: "GET /ap1/csp/user/api/get HTTP/1.1", upstream: "http://10.0.100.11:80/ap1/csp/user/api/get", host: "irishost"
```

## 状態 ap1a:プライマリ, ap1b:停止
ap1aを起動します。ap1aはプライマリになります。
ap1bは停止状態のままですので、curlでtimeout(5秒)が発生しました。
```
$ docker-compose exec ap1a iris start iris quietly
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw
SUCCESS
$ curl -m 5 http://irishost:8080/ap1b/csp/mirror_status.cxw
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
```
アプリケーションへのAPIコールは、ap1a(プライマリ)に到達していることが確認できます。

```
$ curl -m 5 http://irishost/ap1/csp/user/api/get -s | jq
{
  "HostName": "ap1a",
  "UserName": "UnknownUser",
  "Status": "OK",
  "TimeStamp": "02/09/2023 14:29:07"
}
```

# 連続で負荷をかけてみる
正常な状態に戻すために、いったん全コンテナの停止・起動を実行します。
```
$ ./stop.sh
$ ./start.sh
```

連続でリクエストを発生させても正常に動作することを確認します。
```
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw?[1-100]
```
全てSUCCESSが返るはずです。
```
$ curl -m 5 http://irishost/ap1/csp/user/api/get?[1-100]
```
全て"HostName": "ap1a"の応答が返るはずです。

Web gateway managementのSystem Statusで、どのような接続が作成されているかを確認する事ができます。  
また、下記で、Web gatewayを再起動して接続やカウンタをリセットする事ができます。
```
$ docker-compose restart webgw1
$ docker-compose restart webgw2
```

補足)
Web gateway management portalで[Status=Server]が[複数発生](https://www.intersystems.com/jp/support-learning/support/product-news-alerts/support-alert/alert-possible-resource-starvation-due-to-orphaned-processes/)していたので、無効化しました。
```
[SYSTEM]
REGISTRY_METHODS=Disabled
```

# BI機能を試す
ap2rは非同期のレポーティングメンバとして稼働しています。プライマリメンバ(ap2a)に対して発生したレコードの変更を、ap2rでキャッチアップし、組み込みBI機能分析することが可能です。

>起動時点で、2000件程度のレコートが同期されています。

下記コマンドで初期データをBIキューブに反映します。
```
$ docker-compose exec ap2r iris session iris '##class(%DeepSee.Utils).%SynchronizeCube("HOLEFOODS",1)'
1,883 fact(s) updated
Elapsed time: .983161s
```

下記コマンドで、件数が1,000になっていることを確認できます。
```
docker-compose exec ap2r iris session iris "##class(%DeepSee.Utils).%Shell()"
DeepSee Command Line Shell
----------------------------------------------------
Enter q to quit, ? for help.
>>select from HOLEFOODS

Result:              1,000
---------------------------------------------------------------------------
Elapsed time:       .112427s
>>
```

プライマリメンバで新たに10,000件のレコードを新規作成します。
```
$ docker-compose exec ap2a iris session iris -UMIRRORNS "##class(HoleFoods.Utils).AddData(10000)"
10,000 row(s) created
```

これらの差分を下記コマンドでBIキューブに反映します。
```
$ docker-compose exec ap2r iris session iris '##class(%DeepSee.Utils).%SynchronizeCube("HOLEFOODS",1)'
10,000 fact(s) updated
Elapsed time: 4.419442s
```

件数が上記で新規作成した件数だけ増加している事を確認します。
```
docker-compose exec ap2r iris session iris "##class(%DeepSee.Utils).%Shell()"
DeepSee Command Line Shell
----------------------------------------------------
Enter q to quit, ? for help.
>>select from HOLEFOODS

Result:              11,000
---------------------------------------------------------------------------
Elapsed time:       .112717s
>>
```


下記URLでレポーティングメンバ上のBI機能にアクセスできます。

http://irishost:8080/ap2r/csp/user/_DeepSee.UI.Analyzer.zen?$NAMESPACE=MIRRORNS&CUBE=HoleFoods.cube

# HAPROXY
各IRISのポート:1972に対してHAPROXYを設定してあります。これにより、HAPROXY経由でのアクセスは常にプライマリメンバへのアクセスになります。

|ミラークラスタ|バックエンド|フロントエンド|備考|
|:--|:--|:--|:--|
|ap1|ap1a:1972,ap1b:1972|irishost:1972||
|ap2|ap2a:1972,ap2b:1972|irishost:11972||

```
$ docker-compose logs -f haproxy
haproxy    | [WARNING] 056/112355 (9) : Server iris2/ap2a is UP, reason: External check passed, code: 0, check duration: 43ms. 1 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
haproxy    | [WARNING] 056/112356 (9) : Server iris1/ap1a is UP, reason: External check passed, code: 0, check duration: 52ms. 1 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
```

例えば、次のJDBC接続で、SQLクエリを実行できます。
```
jdbc:IRIS://irishost:1972/mirrorns  (ap1のプライマリメンバ)  
jdbc:IRIS://irishost:11972/mirrorns (ap2のプライマリメンバ)  
select * from User_Report.Record
```
# DR非同期のミラーリングの切替え、切戻しについて

[こちら](about_dr_failover.md)を参照ください。