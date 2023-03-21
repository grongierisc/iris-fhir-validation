Include HS.FHIRServer

Class SEMeeting2023.FHIRValidation [ Abstract ]
{

Parameter SkipIfNoProfileKEY = 1;

Parameter JavaGatewayPortKEY = 53272;

Parameter JavaGatewayServerKEY = "localhost";

Parameter IGListKEY = "/irisdev/app/src/fsh/CHUToulouseIG/fsh-generated/resources/";

Parameter TerminologyServerKEY = "https://tx.fhir.org/r4/";

Parameter PatientProfileKEY;

ClassMethod validate(theResource As %DynamicObject)
{
	#dim skipIfNoProfile As %String = ..#SkipIfNoProfileKEY
	
	#dim noProfile As %Boolean = ('theResource.%IsDefined("meta") || 'theResource.meta.%IsDefined("profile") || (theResource.meta.profile.%Size() = 0))
	
	// skipIfNoProfile: only validate if profile is specified
	if +skipIfNoProfile && noProfile
	{
		quit
	}
		
	#dim javaGatewayPort As %String = ..#JavaGatewayPortKEY
	#dim javaGatewayServer As %String = ..#JavaGatewayServerKEY
	#dim igList As %String = ..#IGListKEY
	#dim terminologyServer As %String = ..#TerminologyServerKEY
	#dim patientProfile As %String = ..#PatientProfileKEY
	
	#dim profileToValidateAgainst As %String = ""
	if noProfile 
			&& (theResource.resourceType = "Patient") 
			&& (patientProfile '= "")
	{
		set profileToValidateAgainst = patientProfile
	}	
	
	set gw = $system.external.getJavaGateway()

	// create temporary file with the resource
	#dim file As %Stream.FileCharacter = ##class(%Stream.FileCharacter).%New()
	set file.TranslateTable = "UTF8"
	do theResource.%ToJSON(file)
	do file.Flush()

	// run FHIR validator against the file
	#dim json As %String = ""
	try
	{
		Do ##class(%Library.Device).ReDirectIO(0)
		$$$FSLog("About to call Java validator...")
		set validator = gw.new("SEMeeting2023.JavaValidatorFacade")

		set json = validator.validate( igList, file.Filename, terminologyServer, profileToValidateAgainst)
		Do ##class(%Library.Device).ReDirectIO(1)
	}
	catch ex
	{
		set sc = $get(%objlasterror)  // exception with Java stack here!
		if (sc = "") set sc = ex.AsStatus()
	}
	kill file  // the file gets deleted here as we've never %Save()d it!

	


	// assemble error status in case of any severity=error issues
	#dim operationOutcome As %DynamicObject = {}.%FromJSON(json)

	#dim errorStatus As %Status = $$$OK
	#dim iter As %Iterator.Object = operationOutcome.issue.%GetIterator()
	#dim issue As %DynamicObject
	while iter.%GetNext(.key, .issue) 
	{
		if (issue.severity = "error")
		{
			#dim oneError As %Status = $$$ERROR($$$GeneralError, issue.details.text, $$$OutcomeWithPath(400, "error", issue.code, issue.expression.%Get(0)))
			$$$FHIRAddError(errorStatus, oneError)
		}
	}

	$$$ThrowOnError(errorStatus)
}

}
