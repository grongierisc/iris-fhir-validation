Class HS.FHIRPath.Datatype Extends HS.FHIRPath.Engine
{

Property fhirPathMap [ MultiDimensional ];

Method datatype(
	resourceType As %String,
	pParseTree As HS.FHIRPath.Node,
	Output contextPath As %List,
	Output fhirType As %String)
{
	do:..trace pParseTree.showTree()
	kill %fpdepth
	set contextPath =""
	kill fhirType
	$$$CollPushValue(INPUT, "", resourceType)
	Set INPUT(1,"t","mv") = 0

	Do ..DprocessNode(pParseTree, .INPUT, .OUTPUT)
	Set contextPath = OUTPUT(1,"p")
	Merge fhirType = OUTPUT(1,"t")
}

Method initDatatype() [ Internal ]
{
	// Mapping of operator names to handling codes
	for n="as" {
		Set ..fhirPathMap("op",n) = ">t"
	}
	// Operators getting their type from the left hand argument
	for n="and" {
		Set ..fhirPathMap("op",n) = "<"
	}
	// Boolean Operators
	for n= "!=","is" {
		Set ..fhirPathMap("op",n) = "boolean"
	}

	// Boolean Functions
	for n="exists","empty","contains","hasExtension" {
		Set ..fhirPathMap("fn",n) = "boolean"
	}
	// These methods have an output type that is taken from the first input element
	for n="where","single","first","last","tail","skip","take" {
		Set ..fhirPathMap("fn",n) = "<"
	}
}

Method DprocessNode(
	pNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	
	set type = pNode.type
	w:..trace ">>>> Enter Level: ", $I(%fpdepth),", type: ", type,", name: ",pNode.name,!
	zw:..trace INPUT
	
	
	if type = "OP" {
		do ..DprocessOP( pNode, .INPUT, .OUTPUT)
	} elseif type = "ID" {
		do ..DprocessID(pNode, .INPUT, .OUTPUT)
	} elseif (type = "FN") {
		Do ..DprocessFN(pNode, .INPUT, .OUTPUT)
	} elseif (type = "LIT") {
		Set literalType = pNode.literalType
		if literalType = "o" {
			$$$CollPushValue(OUTPUT, {}, "Element")
		} elseif literalType = "i" {
			if pNode.name = "$this" {
				$$$CollPushValue(OUTPUT, pNode.name, "*")
			} elseif pNode.name = "$index" {
				$$$CollPushValue(OUTPUT, pNode.name, "integer")
			} elseif pNode.name = "$total" {
				$$$CollPushValue(OUTPUT, pNode.name, "integer")
			}
		} else {
			$$$CollPushValue(OUTPUT, pNode.name, literalType)
		}
	}
	w:..trace "<<<< Exit Level: ", %fpdepth,!
	zw:..trace OUTPUT
	do $I(%fpdepth, -1)
}

Method DprocessID(
	pNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	Set propName = pNode.name
	Set prevPath = $Get(INPUT(1,"p"))
	Set INPUT(1,"p") = $LB(propName) _ prevPath
	if $IsObject(pNode.context)   {
		// Evaluate the context (if any)
		w:..trace ">>> processContextNode",!
		Do ..DprocessNode(pNode.context, .INPUT, .CONTEXT)
		w:..trace "<<< processContextNode: ",%fpdepth,!
		//Set CONTEXT(1) = INPUT(1,"p") _ $LB(propName)
	}
	else {
		// Use our input as the context
		merge CONTEXT = INPUT
	}
	zw:..trace CONTEXT
	Set isResource = ..schema.IsValidResourceType(propName)
	Set OUTPUT = 0
	for ix=1:1:CONTEXT {
		if isResource {
			// No change in datatype
			$$$CollPushFromColl(OUTPUT, CONTEXT, ix)
		} else {
			if CONTEXT(ix,"t") = "variant" {
				Set vix = 0
		
				while $ListNext(CONTEXT(ix,"t","vt"), vix, varTypeName) {
					set type = $$$GetPropertyFHIRType(..schema, varTypeName, propName)
					quit:type'=""
				}
			} elseif pNode.pushElement {
				set type = "Element"
				set CONTEXT(ix,"t") = type
			} else {
				set type = $$$GetPropertyFHIRType(..schema, $$$CollGetTypeAt(CONTEXT, ix), propName)
			}
			Set isArray = $$$IsPropertyArray(..schema, $$$CollGetTypeAt(CONTEXT, ix), propName)
			if isArray {
				Set OUTPUT(1,"t","mv") = 1
			} else {
				Set OUTPUT(1,"t","mv") = CONTEXT(ix,"t","mv")
			}
			Set OUTPUT(1,"t","ar") = isArray
			Set OUTPUT(1,"p") = CONTEXT(1,"p")
			$$$CollPushValue(OUTPUT, "", type)
			Set targetList = ""
			if $D($$$GetPropertyTargetList(..schema, $$$CollGetTypeAt(CONTEXT, ix), propName),targetList) {
				Set OUTPUT(1,"t","tl") = targetList
			}
			// Is this a variant?
			if type="x-multi" {
				Set OUTPUT(1,"t") = "variant"
				Set OUTPUT(1,"t","vt") = $$$GetPropertyFHIRTypeList(..schema, $$$CollGetTypeAt(CONTEXT, ix), propName)
			}
		}
	}
}

Method DprocessOP(
	opNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	Set leftNode = opNode.children.GetAt(1)
	if (opNode.name="as") || (opNode.name="as") {
		if leftNode.type = "ID" {
			Set leftNode.name = ..variantFieldName(leftNode.name, opNode.children.GetAt(2).name)
		}
	}
	Do ..DprocessNode(leftNode, .INPUT, .LEFT)
	zw:..trace LEFT
	
	Set OUTPUT = 0
#;	if opNode.isUnary {
#;	} else {
#;		Set rightNode = opNode.children.GetAt(2)
#;		Do ..DprocessNode(rightNode, .INPUT, .RIGHT)
#;		zw:..trace RIGHT 	
#;	}
	Set typeFlag = ..fhirPathMap("op", opNode.name)
	if typeFlag = "<" {
		$$$CollPushFromColl(OUTPUT, INPUT, 1)
		Set OUTPUT(OUTPUT,"t") = INPUT(1,"t")
	}
	elseif typeFlag = ">t" {
		$$$CollPushFromColl(OUTPUT, LEFT, 1)
	} else {
		$$$CollPushFromColl(OUTPUT, LEFT, 1)
		kill OUTPUT(OUTPUT,"t","vt")
		Set OUTPUT(OUTPUT,"t") = typeFlag
	}
	zw:..trace OUTPUT
}

Method DprocessFNAsOP(
	fnNode As HS.FHIRPath.Node,
	opName As %String,
	ByRef INPUT,
	Output OUTPUT)
{
	// Special Handling for compatibility functions that act as operators
	Set opNode = ##class(HS.FHIRPath.Node).%New("OP", opName)
	if fnNode.context = "" {
		$$$ThrowError($$$HSFHIRPathErrInvalidUnary, fnNode.name)
	}
	if fnNode.children.Count() '= 1 {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, fnNode.name)
	}
	Do opNode.children.Insert(fnNode.context)
	Do opNode.children.Insert(fnNode.children.GetAt(1))
	Do ..DprocessOP(opNode, .INPUT, .OUTPUT)
}

Method DprocessFN(
	fnNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	Set opName = $Case(fnNode.name,"is":"is", "union":"|", "as":"as", :"")
	if opName '= "" {
		Do ..DprocessFNAsOP(fnNode, opName, .INPUT, .OUTPUT)
		Return
	}
	if $IsObject(fnNode.context)   {
		// Evaluate the context (if any)
		Do ..DprocessNode(fnNode.context, .INPUT, .CONTEXT)
	}
	else {
		// Use our input as the context
		Set CONTEXT = 0
		merge CONTEXT = INPUT
	}
	zw:..trace CONTEXT
	Set OUTPUT = 0
	if fnNode.name = "subscriptGeneric" {
		// Handle subscripting
		Do ..DprocessNode(fnNode.children.GetAt(1), .CONTEXT, .SUBSCRIPT)
		$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
		return	
	}
	if fnNode.name = "extension" {
		Set OUTPUT = 1
		Set prevPath = $Get(INPUT(1,"p"))
		Set OUTPUT(OUTPUT,"t") = "Extension"
		Set OUTPUT(OUTPUT,"t","ar") = 1
		Set OUTPUT(OUTPUT,"t","mv") = 1
		Set OUTPUT(OUTPUT,"p") = prevPath _ $lb("extension")
		return
	}
	if fnNode.name = "ofType" {
		Set type = fnNode.children.GetAt(1).name
		$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
		Set OUTPUT(OUTPUT,"t") = type
		kill OUTPUT(OUTPUT,"t","vt")
		return
	}
	Set typeFlag = $Get(..fhirPathMap("fn", fnNode.name))
	if typeFlag="<" {
		$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
		if fnNode.name = "where" {
			// Where results in its context type if the expression is (resolve() is <Type>)
			// Then we capture the resolution (which is applied to a Reference or canonical)
			Set weNode = fnNode.children.GetAt(1)
			Set weLeft = weNode.children.GetAt(1)
			if (weLeft.type = "FN") && (weLeft.name = "resolve") {
				Set OUTPUT(OUTPUT,"t","r") = weNode.children.GetAt(2).name
			}
		}
	} elseif typeFlag '= "" {
		$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
		kill OUTPUT(OUTPUT,"t","vt")
		Set OUTPUT(OUTPUT,"t") = typeFlag
	}
}

}
