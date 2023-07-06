Class Python.Interactions Extends HS.FHIRServer.Storage.Json.Interactions
{

// reload an endpoint's interactions from a python class

// do ##class(HS.FHIRServer.ServiceAdmin).DetachEndpointFromInstance("/fhir/custom")

Property PythonClass As %SYS.Python;

Property PythonModule As %String;

Property PythonPath As %String;

Property PythonClassname As %String;

ClassMethod SetPythonPath(pClasspaths)
{
    set sys = ##class(%SYS.Python).Import("sys")
    do sys.path.append(pClasspaths)
}

ClassMethod GetPythonInstance(
	pModule,
	pRemoteClassname) As %SYS.Python
{
    set importlib = ##class(%SYS.Python).Import("importlib")
    set builtins = ##class(%SYS.Python).Import("builtins")
    set module = importlib."import_module"(pModule)
	do importlib."reload"(module)
    set module = importlib."import_module"(pModule)
    set class = builtins.getattr(module, pRemoteClassname)
    return class."__new__"(class)
}

Method %OnNew(pStrategy As HS.FHIRServer.Storage.Json.InteractionsStrategy) As %Status
{
	// %OnNew is called when the object is created.
	// The pStrategy parameter is the strategy object that created this object.
	// The default implementation does nothing
	// Frist set the python path from an env var
	set ..PythonPath = $system.Util.GetEnviron("INTERACTION_PATH")
	// Then set the python class name from the env var
	set ..PythonClassname = $system.Util.GetEnviron("INTERACTION_CLASS")
	// Then set the python module name from the env var
	set ..PythonModule = $system.Util.GetEnviron("INTERACTION_MODULE")

	if (..PythonPath = "") || (..PythonClassname = "") || (..PythonModule = "") {
		//quit ##super(pStrategy)
		set ..PythonPath = "/irisdev/app/src/python/"
		set ..PythonClassname = "CustomInteraction"
		set ..PythonModule = "custom"
	}


	// Then set the python class
	do ..SetPythonPath(..PythonPath)
	set ..PythonClass = ##class(Python.Interactions).GetPythonInstance(..PythonModule, ..PythonClassname)

	quit ##super(pStrategy)
}

Method OnBeforeRequest(
	pFHIRService As HS.FHIRServer.API.Service,
	pFHIRRequest As HS.FHIRServer.API.Data.Request,
	pTimeout As %Integer)
{
	// OnBeforeRequest is called before each request is processed.
	if $ISOBJECT(..PythonClass) {
		do ..PythonClass."on_before_request"(pFHIRService, pFHIRRequest, pTimeout)
	}
}

Method OnAfterRequest(
	pFHIRService As HS.FHIRServer.API.Service,
	pFHIRRequest As HS.FHIRServer.API.Data.Request,
	pFHIRResponse As HS.FHIRServer.API.Data.Response)
{
	// OnAfterRequest is called after each request is processed.
	if $ISOBJECT(..PythonClass) {
		do ..PythonClass."on_after_request"(pFHIRService, pFHIRRequest, pFHIRResponse)
	}
}

Method PostProcessRead(pResourceObject As %DynamicObject) As %Boolean
{
	// PostProcessRead is called after a resource is read from the database.
	// Return 1 to indicate that the resource should be included in the response.
	// Return 0 to indicate that the resource should be excluded from the response.
	if $ISOBJECT(..PythonClass) {
		return ..PythonClass."post_process_read"(pResourceObject)
	}
	quit 1
}

Method PostProcessSearch(
	pRS As HS.FHIRServer.Util.SearchResult,
	pResourceType As %String) As %Status
{
	// PostProcessSearch is called after a search is performed.
	// Return $$$OK to indicate that the search was successful.
	// Return an error code to indicate that the search failed.
	if $ISOBJECT(..PythonClass) {
		return ..PythonClass."post_process_search"(pRS, pResourceType)
	}
	quit $$$OK
}

Method Read(
	pResourceType As %String,
	pResourceId As %String,
	pVersionId As %String = "") As %DynamicObject
{
	return ##super(pResourceType, pResourceId, pVersionId)
}

Method Add(
	pResourceObj As %DynamicObject,
	pResourceIdToAssign As %String = "",
	pHttpMethod = "POST") As %String
{
	return ##super(pResourceObj, pResourceIdToAssign, pHttpMethod)
}

/// Returns VersionId for the "deleted" version
Method Delete(
	pResourceType As %String,
	pResourceId As %String) As %String
{
	return ##super(pResourceType, pResourceId)
}

Method Update(pResourceObj As %DynamicObject) As %String
{
	return ##super(pResourceObj)
}

}
