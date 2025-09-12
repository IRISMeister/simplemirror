# DR非同期のミラーリングの切替え、切戻しについて

サーバのメインテナンス等による計画停止の場合とサーバの障害等による計画外停止の場合についての
手順を説明致します。

実行環境の開始にはstart-dr.shを使用します。これにより、Web Gateway、プライマリメンバ、DRメンバが起動します。
```
$ ./start-dr.sh
```

## DR非同期メンバへの計画的フェイルオーバーおよび切り戻しの手順
サーバのリソース変更やソフトウエア更新等による計画停止場合の手順になります。

1. 計画的フェイルオーバー前のチェック

	1.1 ミラーメンバの状態チェック

	クラス $system.Mirror(%system.Mirror) および クラスSYS.Mirror のクラスメソッドを使用します。
	各メンバの状態が正常な場合、以下の戻り値になります。

	フェイルオーバ・プリマリメンバの場合
	```
	$ docker compose exec ap1a iris session iris -U%SYS	 
	ノード: ap1a インスタンス: IRIS

	%SYS>w $system.Mirror.GetMemberType()
	Failover
	%SYS>w $system.Mirror.GetStatus()
	PRIMARY
	```
	
	DR非同期メンバの場合
	```
	$ docker compose exec ap1d iris session iris -U%SYS	 
	ノード: ap1d インスタンス: IRIS

	%SYS>w $system.Mirror.GetMemberType()
	Disaster Recovery
	%SYS>w $system.Mirror.GetStatus()
	CONNECTED
	%SYS>
	```

	ELBなどで使用する下記のエンドポイントの応答
	```
	$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw
	SUCCESS
	$ curl -m 5 http://irishost:8080/ap1d/csp/mirror_status.cxw
	FAILED
	```

   1.2 ファイルオーバ・バックアップメンバまたは非同期DRメンバでの遅延確認

	以下のクラスメソッドの戻り値が 1の場合はジャーナルファイル転送およびデジャーナルにて遅延はない状況です。
	```
	$ docker compose exec ap1d iris session iris -U%SYS	 
	ノード: ap1d インスタンス: IRIS

	%SYS>w ##class(SYS.Mirror).DistanceFromPrimaryJournalFiles()
	1
	%SYS>w ##class(SYS.Mirror).DistanceFromPrimaryDatabases()
	1
	```

2. DR非同期メンバをフェイルオーバー・メンバに昇格

```
$ docker compose exec ap1d iris session iris -U%SYS	 
ノード: ap1d インスタンス: IRIS
%SYS>w ##class(SYS.Mirror).Promote()
1
%SYS>w $system.Mirror.GetMemberType()
Failover
%SYS>w $system.Mirror.GetStatus()
BACKUP
```

3. プライマリメンバの停止
プライマリメンバのIRISインスタンス停止後、フェイルオーバにてバックアップメンバ(元DR非同期メンバ)がプライマリメンバになります。

```
$ docker compose exec ap1a iris stop iris quietly
$ docker compose exec ap1d iris session iris -U%SYS
ノード: ap1d インスタンス: IRIS

%SYS>w $system.Mirror.GetStatus()
PRIMARY
```

4. ELB(クライアント接続先の変更)、その他業務再開に必要な手順

ELBなどで使用する下記のエンドポイントの応答
```
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received <=停止中なのでtimeoutになる
$ curl -m 5 http://irishost:8080/ap1d/csp/mirror_status.cxw
SUCCESS
```

5. 元プライマリメンバの起動(これ以降切り戻し手順)

元プライマリメンバのIRISインスタンス起動後、バックアップメンバとして参入します。

```
$ docker compose exec ap1a iris start iris
$ docker compose exec ap1a iris session iris -U%SYS
ノード: ap1a インスタンス: IRIS
%SYS>w $system.Mirror.GetStatus()
BACKUP
```

6. 切り戻し前のチェック

(1.)の"計画的フェイルオーバー前のチェック”と同様のチェックを行います。

```
$ docker compose exec ap1a iris session iris -U%SYS	 
ノード: ap1a インスタンス: IRIS

%SYS>w $system.Mirror.GetMemberType()
Failover
%SYS>w $system.Mirror.GetStatus()
BACKUP

$ docker compose exec ap1d iris session iris -U%SYS	 
ノード: ap1d インスタンス: IRIS

%SYS>w $system.Mirror.GetMemberType()
Failover
%SYS>w $system.Mirror.GetStatus()
PRIMARY
```

7. 現プライマリメンバの再起動

現プライマリメンバのIRISインスタンス再起動後、フェイルオーバにてメンバのロールが入れ替わります。
元プライマリメンバ(現バックアップメンバ)がプライマリメンバになり、現プライマリメンバがバックアップメンバになります。

```
$ docker compose exec ap1d iris restart iris
```

8. ELB(クライアント接続先の変更) 、その他業務再開に必要な手順

ELBなどで使用する下記のエンドポイントの応答
```
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw
SUCCESS
$ curl -m 5 http://irishost:8080/ap1d/csp/mirror_status.cxw
FAILED
```

9. バックアップメンバをDR非同期メンバに降格

```
$ docker compose exec ap1d iris session iris -U%SYS	 
ノード: ap1d インスタンス: IRIS

%SYS>w $system.Mirror.GetMemberType()
Failover
%SYS>w ##class(SYS.Mirror).Demote()
1
%SYS>w $system.Mirror.GetMemberType()
Disaster Recovery
%SYS>w $system.Mirror.GetStatus()
CONNECTED
```

## DR非同期メンバへの計画外フェイルオーバーおよび切り戻しの手順
プライマリメンバのシステムに障害が発生し、サーバへアクセス不可となった場合の手順になります。
(ドキュメントでは”追加ジャーナル・データなしの DR 昇格および手動フェイルオーバ”)

1. DR非同期メンバをフェイルオーバー・メンバに昇格

```
$ docker compose exec ap1a iris force iris
$ docker compose exec ap1d iris session iris -U%SYS	
%SYS>w ##class(SYS.Mirror).PromoteWithNoPartner()
1
%SYS>w $system.Mirror.GetMemberType()
Failover
%SYS>w $system.Mirror.GetStatus()
PRIMARY
```

2. ELB(クライアント接続先の変更) 、その他業務再開に必要な手順

ELBなどで使用する下記のエンドポイントの応答
```
$ curl -m 5 http://irishost:8080/ap1a/csp/mirror_status.cxw
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
$ curl -m 5 http://irishost:8080/ap1d/csp/mirror_status.cxw
SUCCESS
```

3. 元プライマリメンバの起動(これ以降切り戻し手順)

構成ファイルiris.cpfの[MirrorMember] セクションに ValidatedMember=0 を追加してインスタンスの起動を行います。

```
$ docker compose exec ap1a bash
irisowner@ap1a:~$ grep ValidatedMember /usr/irissys/iris.cpf
ValidatedMember=0
$ iris start iris
```

4. 元プライマリメンバがDR非同期メンバとして参入した場合の手順

	4.1 元プライマリメンバ(DR非同期メンバ)の昇格

	4.2 切り戻し前のチェック

	(1.) "計画的フェイルオーバー前のチェック”と同様のチェックを行いまます。

	4.3 現プライマリメンバの再起動

	現プライマリメンバのIRISインスタンス再起動後、フェイルオーバにてメンバのロールが入れ替わります。
	元プライマリメンバ(現バックアップメンバ)がプライマリメンバになり、現プライマリメンバがバックアップメンバになります。

	4.4 ELB(クライアント接続先の変更) 、その他業務再開に必要な手順
	
	4.5 バックアップメンバをDR非同期メンバに降格

5. 元プライマリメンバがDR非同期メンバとして参入できなかった場合の手順

	5.1 元プライマリメンバでミラー・メンバの再構築を行い、バックアップメンバとして参入します。
	[ミラー・メンバの再構築](https://docs.intersystems.com/iris20221/csp/docbookj/DocBook.UI.Page.cls?KEY=GHA_mirror_manage#GHA_mirror_rebuild)

	以降、4.2からと同じ手順。

## 関連ドキュメント

[昇格した DR 非同期への計画的フェイルオーバー](https://docs.intersystems.com/iris20221/csp/docbookj/DocBook.UI.Page.cls?KEY=GHA_mirror_set_member_change#GHA_mirror_set_member_change_plannedfailover_DR)
[災害復旧時の昇格した DR 非同期への手動フェイルオーバー](https://docs.intersystems.com/iris20221/csp/docbookj/DocBook.UI.Page.cls?KEY=GHA_mirror_set_member_change#GHA_mirror_set_member_change_manualfailover_DR)
[$system.Mirror クラス](https://docs.intersystems.com/iris20221/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=%25SYSTEM.Mirror)
[SYS.Mirror クラス](https://docs.intersystems.com/iris20221/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=SYS.Mirror)

