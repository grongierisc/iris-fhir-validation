Include HS.FHIRServer

Class Suchi.FHIRValidation [ Abstract ]
{

Parameter SkipIfNoProfileKEY = 1;

Parameter JavaGatewayPortKEY = 53272;

Parameter JavaGatewayServerKEY = "localhost";

Parameter IGListKEY = "/irisdev/app/src/fsh/ExampleIG/fsh-generated/resources/";

Parameter TerminologyServerKEY = "https://tx.fhir.org/r4/";

Parameter PatientProfileKEY;

ClassMethod readConfig(path) As %DynamicObject
{
	set moduleJson = ##class(%SYS.Python).Import("json")
	set moduleConfig = ##class(%SYS.Python).Import("configparser")

	set config = moduleConfig.ConfigParser()
	do config.read(path)

	set configJson = moduleJson.dumps(config."_sections")

	return {}.%FromJSON(configJson)
}

ClassMethod validate(theResource As %DynamicObject)
{
	// read configuration
	#dim config As %DynamicObject = ..readConfig("/irisdev/app/profile.ini")

	#dim skipIfNoProfile As %String = ..#SkipIfNoProfileKEY
	if config.%IsDefined("Config") && config.Config.%IsDefined("skipifnoprofilekey")
	{
		set skipIfNoProfile = config.Config.skipifnoprofilekey
	}

	#dim errorStatus As %Status = $$$OK

	#dim noProfile As %Boolean = ('theResource.%IsDefined("meta") || 'theResource.meta.%IsDefined("profile") || (theResource.meta.profile.%Size() = 0))
	
	// skipIfNoProfile: only validate if profile is specified
	if +skipIfNoProfile && noProfile
	{
		quit
	}
		
	#dim javaGatewayPort As %String = ..#JavaGatewayPortKEY
	#dim javaGatewayServer As %String = ..#JavaGatewayServerKEY
	#dim igList As %String = ..#IGListKEY
	if config.%IsDefined("Config") && config.Config.%IsDefined("iglist")
	{
		set igList = config.Config.iglistkey
	}
	#dim terminologyServer As %String = ..#TerminologyServerKEY
	if config.%IsDefined("Config") && config.Config.%IsDefined("terminologyserverkey")
	{
		set terminologyServer = config.Config.terminologyserverkey
	}
	#dim patientProfile As %String = ..#PatientProfileKEY
	if config.%IsDefined("Config") && config.Config.%IsDefined("patientprofilekey")
	{
		set patientProfile = config.Config.patientprofilekey
	}
	
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

		set validator = gw.new("Suchi.JavaValidatorFacade")

		set json = validator.validate( igList, file.Filename, terminologyServer, profileToValidateAgainst)
	}
	catch ex
	{
		set sc = ex.AsStatus()
		$$$FHIRAddError(errorStatus, sc)
	}

	Do ##class(%Library.Device).ReDirectIO(1)
	kill file  // the file gets deleted here as we've never %Save()d it!

	$$$ThrowOnError(errorStatus)

	// assemble error status in case of any severity=error issues
	#dim operationOutcome As %DynamicObject = {}.%FromJSON(json)

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
