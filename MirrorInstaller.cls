Include (%occInclude, %syConfig)

Class Mirror.Installer
{

ClassMethod setup(systemname) As %Status
{
  if $system.Mirror.IsMember() {
		write !,"This system is already configured as a mirror member"
 	}else{
    write !,"Setup for host: "_systemname,!
    
    // Enable mirror: 
    do ..enableMirrorService()

    set mirrorRole=$SYSTEM.Util.GetEnviron("MIRRORROLE")
    if mirrorRole="PRIMARY" {
      do ..createMirror(systemname)
    } else {
      // Allow some time to create mirror in primary
      //h 3
      set primaryAgentAddress=$SYSTEM.Util.GetEnviron("primaryAgentAddress_ip")  //"10.0.1.2"
     
      Set membertype=""
      If mirrorRole="DR" { Set membertype=0}
      ElseIf mirrorRole="REPORTR" { Set membertype=1}
      ElseIf mirrorRole="REPORTRW" { Set membertype=2}
      // "":sync member, 0:async (DR) member, 1:Read-Only Reporting, 2:Read-Write Reporting
      do ..join(membertype,systemname,primaryAgentAddress)
    }

    // Create DB and add it to mirror
    do ..createMirrorDB(mirrorRole)

    // Add global mappings for BI from MIRRORNS to USER
    If (mirrorRole="REPORTR")!(mirrorRole="REPORTRW") {
      Kill props Set props("Database")="MIRRORDB",sc=##Class(Config.MapGlobals).Create("USER","HoleFoods.*",.props)
      Kill props Set props("Database")="MIRRORDB",sc=##Class(Config.MapGlobals).Create("USER","OBJ.DSTIME",.props)
    }
  }
  quit $$$OK
}

ClassMethod createMirror(systemname) As %Status
{
  set mirrorName="MIRRORSET"
  // Create mirror:
  set MirrorInfo("UseSSL") = 0
  set MirrorInfo("ArbiterNode") = $SYSTEM.Util.GetEnviron("ARBITER_ip")_"|2188" // "10.0.100.10|2188"
  set MirrorInfo("MirrorAddress") = $SYSTEM.Util.GetEnviron("MirrorAddress_ip") //"10.0.1.2"
  set MirrorInfo("ECPAddress") = $SYSTEM.Util.GetEnviron("ECPAddress_ip") // "10.0.100.2"
  ;set MirrorInfo("CompressionForFailoverMembers") = 1 // no compression 
  ;set MirrorInfo("CompressionForAsyncMembers") = 1 // no compression 
  set MirrorInfo("AllowParallelDejournaling") = 2  // all members
  
  set sc = ##class(SYS.Mirror).CreateNewMirrorSet(mirrorName, systemname, .MirrorInfo)
  write !,"Creating mirror "_mirrorName_"..."
  if 'sc do $system.OBJ.DisplayError(sc)  
  quit sc
}

ClassMethod join(membertype, systemname, agentAddress) As %Status
{
  set mirrorName="MIRRORSET"
  set instanceName="IRIS"
  
  // Join as failover:
  If $SYSTEM.Util.GetEnviron("MirrorAddress_ip")'="" {
    set LocalInfo("MirrorAddress") = $SYSTEM.Util.GetEnviron("MirrorAddress_ip") // "10.0.1.3"
  }
  If $SYSTEM.Util.GetEnviron("ECPAddress_ip")'="" {
    set LocalInfo("ECPAddress") = $SYSTEM.Util.GetEnviron("ECPAddress_ip") // "10.0.100.3"
  }
  If (membertype="") {
    s sc=##class(SYS.Mirror).JoinMirrorAsFailoverMember(mirrorName,systemname,instanceName,agentAddress,,.LocalInfo)
  }
  Else {
    s sc=##class(SYS.Mirror).JoinMirrorAsAsyncMember(mirrorName,systemname,instanceName,agentAddress,,membertype,.LocalInfo)  
  }
  write !,"Jonining mirror "_mirrorName_"..."
  if 'sc do $system.OBJ.DisplayError(sc)
  quit sc
}

ClassMethod enableMirrorService() As %Status
{
  do ##class(Security.Services).Get("%Service_Mirror", .svcProps)
  set svcProps("Enabled") = 1
  do ##class(Security.Services).Modify("%Service_Mirror", .svcProps)
  write !,"Enabling mirror service..."
}

ClassMethod createMirrorDB(role, mirNSName = "MIRRORNS", mirDBName = "MIRRORDB") As %Status
{
  //#define LOTSOFDB 1
  #define DBCOUNT 256
  Set tSC='$$$OK
  Try {
    set dir="/DB/"
    set mirrorName="MIRRORSET"
    set dirName=mirDBName
    
    write !, "Creating databases and NS "_mirNSName,!
    
    // If no, create it inside of container
    If '##class(%Library.File).Exists(dir) {
      Set dir="/home/irisowner/"
    }

    // Create directory for db
    do ##class(%Library.File).CreateNewDir(dir,dirName)
    // Add DB to config
    set Properties("Directory")=dir_dirName
    do ##class(Config.Databases).Create(mirDBName,.Properties)

    // wait until mirror's ready
    for i=1:1:30 {
      h 1
      set mirrorStatus=$LIST($SYSTEM.Mirror.GetMemberStatus(mirrorName))
      if mirrorStatus="Backup" Quit
      if mirrorStatus="Primary" Quit
      if mirrorStatus="Connected" Quit   // async member
    }
    if ((mirrorStatus'="Primary")&(mirrorStatus'="Backup")&(mirrorStatus'="Connected")) { 
      write "Mirror failed to be ready: Mirror Status:"_mirrorStatus,!
      Return '$$$OK
    }

    Set dbsize=64
    set tSC = ##class(SYS.Database).CreateDatabase(dir_dirName,dbsize,,,,,mirDBName,mirrorName)
    if 'tSC { 
      write !,"Database creation failed!"
      $$$ThrowOnError(tSC)
    }

    // Create namespace for mirrored database
    set ns("Globals")=mirDBName
    set ns("Routines")=mirDBName
    do ##class(Config.Namespaces).Create(mirNSName,.ns)
    set bool = ##class(Config.Namespaces).Exists(mirNSName,.obj,.status)
    if 'bool {
      write !, "NS creation failed."
      $$$ThrowOnError(status)
    }
    // Enables production
    Do ##class(%EnsembleMgr).EnableNamespace(mirNSName,0)

    Set tSC=..EnableWebApps()  //create a web app
    $$$ThrowOnError(tSC)

#ifdef LOTSOFDB
    For i=1:1:$$$DBCOUNT {
      write !, "Creating databases file #:"_i
      do ##class(%Library.File).CreateNewDir(dir,dirName_i)
      // Add DB to config
      set Properties("Directory")=dir_dirName_i
      do ##class(Config.Databases).Create(mirDBName_i,.Properties)
    }

    For i=1:1:$$$DBCOUNT {
      #; retry
      For j=1:1:10 {
        Set dbsize=1
        write !, "Creating databases definition :"_dir_dirName_i_" "_mirDBName_i
        set tSC = ##class(SYS.Database).CreateDatabase(dir_dirName_i,dbsize,,,,,mirDBName_i,mirrorName)
        if tSC=$$$OK quit
        if 'tSC { 
          write !,"Database definition creation failed!" zw tSC
          //$$$ThrowOnError(tSC)
        }
        if j=10 $$$ThrowOnError(tSC)
      }
    }

    For i=1:1:$$$DBCOUNT {
      #; retry
      For j=1:1:10 {
        write !, "Creating namespace #:"_mirNSName_i_" on "_mirDBName_i
        k props
        set props("Globals")=mirDBName_i
        set props("Routines")=mirDBName_i
        Set Flags=$$$CPFSave+$$$CPFWrite // 都度Activateすると大量のSMHを消費し、一時的に不足する可能性が増す
        Do ##class(Config.Namespaces).Create(mirNSName_i,.props,,Flags)
        set bool = ##class(Config.Namespaces).Exists(mirNSName_i,.obj,.status)
        if bool=$$$OK quit
        if 'bool {
          write !, "NS creation failed. #:"_i,!
          h 1
        }
        if j=10 {
          w ! zw status
          $$$ThrowOnError(status)
        }
      }
    }
    Set tSC=##class(Config.CPF).Activate()
    $$$ThrowOnError(tSC)
#endif    

	} Catch(e) {
		Set tSC=e.AsStatus()
    Do $system.OBJ.DisplayError(tSC)
	}

  Return tSC
}

ClassMethod DatabaseTimeLatency(member = "AP1B/IRIS") As %String
{
  New $NAMESPACE
  Set $NAMESPACE="%SYS"
  set mirname="MIRRORSET"
  Set DatabaseTimeLatency=""
	Set tRS = ##class(%Library.ResultSet).%New("SYS.Mirror:MemberStatusList")
	Do tRS.Execute(mirname)
	while tRS.Next() {
		s name=tRS.Data("MemberName")
    If name=member {
		  ;s jrntimelatency=tRS.Data("JournalTimeLatency")
      s DatabaseTimeLatency=tRS.Data("DatabaseTimeLatency")
      quit
    }
	}
  w DatabaseTimeLatency,!
  Return DatabaseTimeLatency
}

ClassMethod EnableWebApps(ns = "mirrorns") As %Status
{
  New $NAMESPACE
	Set tSC='$$$OK
	Try {

    Set oldns=$NAMESPACE
    Set $NAMESPACE="%SYS"

    Set webapp="/csp/"_ns_"/api/"
    Set tSC = ##Class(Security.Applications).Create(webapp)
    Kill props
    Set tSC = ##Class(Security.Applications).Get(webapp,.props)
    $$$ThrowOnError(tSC)
    Set props("DispatchClass")="MyApp.disp"
    Set props("Resource")=""
    Set props("MatchRoles")=":%All"
    Set props("NameSpace")=ns
    Kill props("Type")
    Set tSC = ##Class(Security.Applications).Modify(webapp,.props)
    $$$ThrowOnError(tSC)

    #; accept mutiple names as application path, such as "ap1, ap1a".
    #; See https://docs.intersystems.com/irislatest/csp/docbook/Doc.View.cls?KEY=GCGI_remote_csp#GCGI_change_server_name
    Do $System.CSP.SetConfig("CSPConfigName",$SYSTEM.Util.GetEnviron("CSPConfigName"))
	  Set $NAMESPACE=oldns
	} Catch(e) {
		Set tSC=e.AsStatus()
	}
	
  Return tSC
}

}
