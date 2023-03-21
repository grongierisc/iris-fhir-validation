Class SEMeeting2023.FHIRBundleValidator Extends HS.FHIRServer.Util.BundleValidator
{

ClassMethod ValidateBundle(pResourceObject As %DynamicObject, pFHIRVersion As %String)
{
	do ##super(pResourceObject, pFHIRVersion)

	do ##class(SEMeeting2023.FHIRValidation).validate(pResourceObject)
}

}
