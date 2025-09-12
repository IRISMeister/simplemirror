Include %occInclude

Class Mirror.Populate
{

/// Runs on primary only.
ClassMethod PopulateMirrorDB() As %Status
{
  Set tSC='$$$OK
	Try {
    Set tSC=..CreateProduction()
    $$$ThrowOnError(tSC)
    Set tSC=..BISetup()
    $$$ThrowOnError(tSC)

    New $NAMESPACE
    Set $NAMESPACE="mirrorns" ; ToDo: parameterize it.
    Do ##class(Ens.Director).StartProduction()

	} Catch(e) {
		Set tSC=e.AsStatus()
	}
  Return tSC
}

ClassMethod CreateProduction(ByRef tVars) As %Status
{
  New $NAMESPACE
	Set tSC='$$$OK
	Try {
		If '$D(tVars("SRCDIR")) { Set tVars("SRCDIR")="/project" }
		If '$D(tVars("NAMESPACE")) { Set tVars("NAMESPACE")="MIRRORNS" }

    Set $NAMESPACE=tVars("NAMESPACE")
    $$$THROWONERROR(tSC,$SYSTEM.OBJ.ImportDir(tVars("SRCDIR"),"","ck",.e,1))
	} Catch(e) {
		Set tSC=e.AsStatus()
	}
	
  Return tSC
}

ClassMethod BISetup(ns = "mirrorns") As %Status
{
	Set tSC='$$$OK
	Try {

	Set oldns=$NAMESPACE
	New $NAMESPACE

	#; Don't import Cube related classes here because this db is on a primary server
	Set $NAMESPACE=ns
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Region.cls","ck") 
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Country.cls","ck") 
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Outlet.cls","ck") 
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Product.cls","ck") 
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Transaction.cls","ck") 
  // will report compile error but it works
  w "++You can ignore compile erros here++",!
  Set tSC=$SYSTEM.OBJ.Load("/home/irisowner/Samples-BI/src/cls/HoleFoods/Utils.cls","ck") 
  Do ##class(HoleFoods.Utils).BuildData(1000,0,1)
  w "--You can ignore compile erros here--",!

	Set $NAMESPACE=oldns

	} Catch(e) {
		Set tSC=e.AsStatus()
	}
  	Return tSC
}

}
