Class Suchi.FHIRBundleValidator Extends HS.FHIRServer.Util.BundleValidator
{

ClassMethod ValidateBundle(pResourceObject As %DynamicObject, pFHIRVersion As %String)
{
	do ##super(pResourceObject, pFHIRVersion)

	do ##class(Suchi.FHIRValidation).validate(pResourceObject)
}

}
