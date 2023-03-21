Class SEMeeting2023.FHIRResourceValidator Extends HS.FHIRServer.Util.ResourceValidator
{

/// @API
/// ValidateResource validates a FHIR Resource.  If a validation error is found, a
/// compound %Status is thrown in a StatusException.  The compound %Status starts with a
/// $$$ValidationFailure code, followed by additional %Status objects for each detected
/// validation error.
/// Inputs:
/// <li>pJsonResource           : (required) %DynamicObject representation of the FHIR resource.
/// <li>Throws					: A StatusException containing a compound %Status representing all
///                             : validation errors.
Method ValidateResource(pResourceObject As %DynamicObject)
{
	do ##super(pResourceObject)
	
	// it's FHIRBundleValidator that takes care of validating Bundle entries
	//   so here we skip validation if this is the case
	
	if $get(%inTransactionFlag, $$$NO) '= $$$YES
	{
		do ##class(SEMeeting2023.FHIRValidation).validate(pResourceObject)
	}
}

}
