Class Sushi.FHIROperationHandler Extends HS.FHIRServer.Storage.BuiltInOperations
{

/// Restart Operation
ClassMethod FHIRSystemOpRestart(
	pService As HS.FHIRServer.API.Service,
	pRequest As HS.FHIRServer.API.Data.Request,
	pResponse As HS.FHIRServer.API.Data.Response) As %Status
{
    Set sc = $$$OK

    // restart the server
    set strategy = pService.strategy
    set interactions = strategy.NewInteractionsInstance()
    d interactions.SetMetadata( strategy.GetMetadataResource() )

    // restart the gateway
    do $system.external.stopServer("%Java Server")
    
    Return sc
}

/// Add To Capability Statement
ClassMethod AddSupportedOperationsRestart(pMap As %DynamicObject) As %Status
{
    Set sc = $$$OK
    Do pMap.%Set("restart","http://hl7.org/fhir/OperationDefinition/System-restart")
    Return sc
}

ClassMethod AddSupportedOperations(pMap As %DynamicObject)
{
    do ##super(pMap)
    do ..AddSupportedOperationsRestart(pMap)
}

}
