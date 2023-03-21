Class Suchi.FHIRValidationInteractions Extends (HS.FHIRServer.Storage.Json.Interactions, HS.HC.FHIRSQL.FHIR.Interactions)
{

/* NB: After modifying this class, make sure to reset the endpoint using this command:

	do ##class(HS.FHIRServer.Service).InvalidateInstances((##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint("/fhir-validation")).InstanceKey)  kill ^FSLOG

*/
Parameter ResourceValidatorClass = "Suchi.FHIRResourceValidator";

Parameter BatchHandlerClass As %String = "Suchi.FHIRBundleProcessor";

Method Update(pResourceObj As %DynamicObject) As %String
{
	/// remove indices for existing record
	Do ..UpdateObjects(pResourceObj.resourceType,pResourceObj.id,0)
	Quit ##super(pResourceObj)
}

Method JSONPatch(pPatchOperations As %DynamicArray, pResourceObj As %DynamicObject) As %Boolean
{
	/// remove indices for existing record
	Do ..UpdateObjects(pResourceObj.resourceType,pResourceObj.id,0)
	Quit ##super(pPatchOperations,pResourceObj)
}

Parameter FHIRSQLINTERACTIONS = 1;

Method OnAfterRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pFHIRResponse As HS.FHIRServer.API.Data.Response)
{
	Do ..FHIRSQLOnAfterRequest(pFHIRService,pFHIRRequest,pFHIRResponse)
}

/// %inTransactionFlag is a global variable indicating that we are processing a Bundle
///   if set, FHIRResourceValidator skips validation of Bundle entries
Method StartTransactionBundle(pBundleTransactionId As %Integer)
{
	do ##super(pBundleTransactionId)
	set %inTransactionFlag = $$$YES
}

Method EndTransactionBundle()
{
	kill %inTransactionFlag
	do ##super()
}

}
