# cpf mergeの記法がわかるまでの暫定措置で使用したコード。既に未使用。
exit
iris session $ISC_PACKAGE_INSTANCENAME -U %SYS << END
Set DBName="REM_MIRRRODB" \
s p("ClusterMountMode")=0 \
s p("Directory")=":mirror:MIRRORSET:MIRRORDB" \
s p("Server")="IRIS-0" \
set Status=##Class(Config.Databases).Create(DBName,.p) \
halt
END

