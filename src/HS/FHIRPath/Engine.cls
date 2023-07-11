Include (HS.FHIRMeta, HS.FHIRPath)

Class HS.FHIRPath.Engine Extends %RegisteredObject
{

Property trace As %Boolean;

Property context As %DynamicObject;

Property schema As HS.FHIRMeta.API;

Property opMap [ MultiDimensional ];

Property fhirToJson [ MultiDimensional ];

Property fhirToDateType [ MultiDimensional ];

/// FNSCOPE("$this")
/// FNSCOPE("$index")
/// FNSCOPE("$total")
Property FNSCOPE [ MultiDimensional ];

Property env As HS.FHIRPath.Environment;

Method initEngine() [ Internal ]
{
	for t="string","id","markdown" {
		Set ..fhirToJson(t) = "s"
	}
	for t="integer","decimal","positiveInt","unsignedInt" {
		Set ..fhirToJson(t) = "n"
	}
	
	for t="date","time","datetime" {
		Set ..fhirToDateType(t) = "d"
	}
	
	
	//#define fixPrimitive(%t) $Select(((%t="string") || (%t="id") || (%t="markdown")):"s", ((%t="integer") || (%t="decimal") || (%t="positiveInt") || (%t="unsignedInt")):"n", 1:%t)
}

/* This should probably be a public API in FHIRMeta.API */
Method fhirTypeToJsonType(fhirType As %String) As %String [ CodeMode = expression ]
{
$G(@..schema.PtiGbl@(fhirType), "o")
}

Method fhirTypeToMathType(fhirType As %String) As %String
{
	if '$D(..fhirToDateType(fhirType), mathType) {
		Set mathType = ..fhirTypeToJsonType(fhirType)
		if (mathType = "o") {
			Set mathType = $Select(..schema.IsA(fhirType, "Quantity"):"q", 1:"")
		} 
	}
	return mathType
}

Method fhirTypeToStringType(
	value,
	fhirType As %String) As %String
{
	Set jsonType = ..fhirTypeToJsonType(fhirType)
	if (jsonType '= "o") {
		return value
	}
	if ..schema.IsA(fhirType, "Quantity") {
		return value.value	
	}
	return ""
}

Method interpretToJson(
	pResourceObj As %DynamicObject,
	pParseTree As HS.FHIRPath.Node,
	env As HS.FHIRPath.Environment = "") As %DynamicArray
{
	do ..interpret(pResourceObj, pParseTree, .OUTPUT)
	return ..CollectionToJsonArray(.OUTPUT)
}

Method interpret(
	pResourceObj As %DynamicObject,
	pParseTree As HS.FHIRPath.Node,
	Output OUTPUT,
	env As HS.FHIRPath.Environment = "")
{
	$$$CollPushValue(INPUT, pResourceObj, pResourceObj.resourceType)
	do ..interpretArray(.INPUT, pParseTree, .OUTPUT, env)
}

Method interpretArray(
	ByRef INPUT,
	pParseTree As HS.FHIRPath.Node,
	Output OUTPUT,
	env As HS.FHIRPath.Environment = "")
{
	kill OUTPUT
	set ..env  = ##class(HS.FHIRPath.Environment).%New()
	if $IsObject(env) {
		do ..env.MergeFromEnv(env)
	}
	// Now add the "always present" environment variables"
	for ord=1:1:INPUT {
		do ..env.AddValue("context", INPUT(ord), INPUT(ord,"t"))	
	}
	do ..env.AddValue("ucum", "http://unitsofmeasure.org", "string")	
	
	if ..trace {
		w !
		do pParseTree.showTree()
	}
	Do ..processNode(pParseTree, .INPUT, .OUTPUT)
}

Method processNode(
	pNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	set type = pNode.type
	w:..trace ">>>> Enter Level: ", $I(%fpdepth),", type: ", type,", name: ",pNode.name,!
	zw:..trace INPUT
	
	
	if type = "OP" {
		do ..processOP( pNode, .INPUT, .OUTPUT)
	} elseif type = "ID" {
		do ..processID(pNode, .INPUT, .OUTPUT)
	} elseif (type = "FN") {
		Do ..processFN(pNode, .INPUT, .OUTPUT)
	} elseif (type = "LIT") {
		Set literalType = pNode.literalType
		if literalType = "o" {
			$$$CollPushValue(OUTPUT, {}, "Element")
		} elseif literalType = "inv" {
			if $D(..FNSCOPE(pNode.name), value) {
				if pNode.name = "$this" {
					$$$CollPushValue(OUTPUT, value, ..FNSCOPE(pNode.name,"t"))
				} else {
					$$$CollPushNumber(OUTPUT, value)
				}
			}
		} elseif literalType = "env" {
			// Environment Variable
			do ..env.MergeValueTo(pNode.name, .OUTPUT)
		} elseif literalType = "boolean" {
			$$$CollPushBoolean(OUTPUT, pNode.name="true")
			
		} else {
			$$$CollPushValue(OUTPUT, pNode.name, literalType)
		}
	}
	w:..trace "<<<< Exit Level: ", %fpdepth,", type: ", type,", name: ",pNode.name,!
	zw:..trace OUTPUT
	do:..trace $I(%fpdepth, -1)
}

Method processID(
	pNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	if $IsObject(pNode.context)   {
		// Evaluate the context (if any)
		Do ..processNode(pNode.context, .INPUT, .CONTEXT)
	}
	else {
		// Use our input as the context
		merge CONTEXT = INPUT
	}
	Set propName = pNode.name
	Set isTypeIdentifier = ..schema.IsFHIRType(propName) && ($E(propName,1) = $ZCVT($E(propName,1),"U"))
	
	Set OUTPUT = 0
	for ix=1:1:CONTEXT {
		Set inputValue = CONTEXT(ix)
		if isTypeIdentifier {
			// The ID is a non-primitive FHIRType, only keep objects of the specified type
			if ..schema.IsA(CONTEXT(ix,"t"), propName) {
				$$$CollPushFromColl(OUTPUT, CONTEXT, ix)
			}
		} else {
			Set inputType = $$$CollGetTypeAt(CONTEXT, ix)
			set type = $$$GetPropertyFHIRType(..schema, inputType, propName)
			// Do nothing if the property is unknown
			Continue:type=""
			if pNode.pushElement {
				set jtype = $$$GetPropertyJsonType(..schema, inputType, propName)
				if jtype = "alias" {
					// If the schema says 'alias' it means that the type is ResourceContainer,
					// so the type is the object's resourceType
					set jtype = "o"
					set type = inputValue.%Get(propName).resourceType
				}
				if (jtype '= "o") {
					// If a primitive "element-based" property, go get the Element
					set element = inputValue.%Get("_" _ propName)
					if $IsObject(element) {
						if element.%IsA("%DynamicArray") {
							Set iter = element.%GetIterator()
							while iter.%GetNext(.key, .elvalue) {
								$$$CollPushValue(OUTPUT, elvalue, "Element")
							}
						} else {
							$$$CollPushValue(OUTPUT, element, "Element")
						}
					}
					Continue
				}
			}
						
			if type '= "x-multi" {			
				If inputValue'="" {
					Do ..pushFieldValue(inputValue.%Get(propName), type, .OUTPUT)
				}
			} else {
				// try all possible types for this variant
				Set typeList = $$$GetPropertyFHIRTypeList(..schema, inputType, propName)
				set tlix = 0
				while $listnext(typeList, tlix, type) {
					set vpropName = ..variantFieldName(propName, type)
					set value = inputValue.%Get(vpropName)
					//w vpropName, " =|",value,"|",!
					if value '= "" {
						$$$CollPushValue(OUTPUT, value, type)
						Quit		
					}
				}
			}
		}
	}
}

Method processOP(
	opNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	Set opName = opNode.name
	if '$D(..opMap(opName), fnBase) {
		$$$ThrowError($$$HSFHIRPathErrNotYetImplemented, opName)	
	}
	
	Set leftNode = opNode.children.GetAt(1)
	Do ..processNode(leftNode, .INPUT, .LEFT)
	
	Set OUTPUT = 0
	if opNode.isUnary {
		do $Method($this, "IUOP" _ fnBase, .LEFT, .OUTPUT)	
	} else {
		Set rightNode = opNode.children.GetAt(2)
		if (opName="as") || (opName="is") {
			// Treat the node as a datatype
			$$$CollPushValue(RIGHT, rightNode.name, "")
		} else {
			Do ..processNode(rightNode, .INPUT, .RIGHT)
		}
		Set methodName = "IOP" _ fnBase
		zw:..trace LEFT
		zw:..trace RIGHT
		do $Method($this, methodName, .LEFT, .RIGHT, .OUTPUT)	
		zw:..trace OUTPUT
	}
}

Method processFNAsOP(
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
	Do ..processOP(opNode, .INPUT, .OUTPUT)
}

Method processFN(
	fnNode As HS.FHIRPath.Node,
	ByRef INPUT,
	Output OUTPUT)
{
	Set opName = $Case(fnNode.name,"is":"is", "union":"|", "as":"as", :"")
	if opName '= "" {
		Do ..processFNAsOP(fnNode, opName, .INPUT, .OUTPUT)
		Return
	}
	if $IsObject(fnNode.context)   {
		// Evaluate the context (if any)
		Do ..processNode(fnNode.context, .INPUT, .CONTEXT)
	}
	else {
		// Use our input as the context
		Set CONTEXT = 0
		merge CONTEXT = INPUT
	}
	
	Set OUTPUT = 0
	if fnNode.name = "subscriptGeneric" {
		// Handle subscripting
		Do ..processNode(fnNode.children.GetAt(1), .CONTEXT, .SUBSCRIPT)
		if (SUBSCRIPT=1) && $$$CollIsNumber(SUBSCRIPT, 1) {
			Set subscript = $$$CollGetValueAt(SUBSCRIPT, 1)
			if (subscript >=0) && (subscript < CONTEXT) {
				$$$CollPushFromColl(OUTPUT, CONTEXT, subscript+1)
			}
		} else {
			$$$ThrowError($$$HSFHIRPathErrInvalidSubscript, $Get(SUBSCRIPT(1)))
		}
	} else {
		$$$BeginContextLoop(SAVE)
		Set ..FNSCOPE("$index") = 0
		if $Get(CONTEXT,0) {
			Merge ..FNSCOPE("$this") = CONTEXT(1)
		}
		Set methodName = "IFN" _ fnNode.name
		Do $Method($this, methodName, .CONTEXT, fnNode.children, .OUTPUT)
		$$$EndContextLoop(SAVE)

	}
}

ClassMethod pushFieldValue(
	value,
	type As %String,
	ByRef INTO)
{
	if value '= "" {
		if $IsObject(value) && value.%IsA("%DynamicArray") {
			do ..JsonArrayToCollection(value, type, .INTO)
		} else {
			$$$CollPushValue(INTO, value, $Select(type="Resource":value.resourceType, 1:type))
		}
	}
}

Method CollectionToJsonArray(ByRef input) As %DynamicArray
{
	#dim array as %DynamicArray = ##class(%DynamicArray).%New()
	set ix=""
	for {
		Set ix = $Order(input(ix), 1, value)
		Quit:ix=""
		
		Set type = $Get(input(ix,"t"))
		if type="boolean" {
			Do array.%Push(value,"boolean")
		} else {
			Set jtype = ""
			if jtype'="" {
				set jtype = ..fhirTypeToJsonType(type)
			}
			if jtype="n" {
				Do array.%Push(value,"number")
			} else {
				Do array.%Push(value)
			}
		}
	}
	return array
}

/// This method is factored out so that in the future, we can allow a plugin resolver for references.
/// For each item in the collection, if it is a string that is a uri (or canonical or url), locate the target of the reference, and add it to the resulting collection.
/// If the item does not resolve to a resource, the item is ignored and nothing is added to the output collection.
/// The items in the collection may also represent a Reference, in which case the Reference.reference is resolved.
Method resolveToResource(
	ByRef INPUT,
	ByRef OUTPUT)
{
	for ix = 1:1:INPUT {
		set inputType = INPUT(ix,"t")
		set inputValue = INPUT(ix)
		Set ref = $Case(inputType, "Reference":INPUT(ix).reference,"canonical":INPUT(ix), :"")
		if ref '= "" {
			// FHIRPath currently does not support references to contained resources
			// Conditional references should also be ignored, they will be resolved within a bundle transaction
			if (($Extract(ref) '= "#") && (ref '[ "?")) {
				Set inputType  = $Piece(ref,"/",*-1)
				if ..schema.IsA(inputType, "Resource") {
					// Create a dummy resource -- eventually we will add a plugin resolver for references.
					set inputValue = { "resourceType":(inputType), "id":($Piece(ref,"/",*)) }
					$$$CollPushValue(OUTPUT, inputValue, inputType)
				}
			}
		} else {
			/// This should be a resource
			if ..schema.IsA(inputType, "Resource") {
				$$$CollPushFromColl(OUTPUT, INPUT, ix)
			}
		}
	}
}

ClassMethod JsonArrayToCollection(
	array As %DynamicArray,
	type As %String,
	ByRef INTO)
{
	Set iter = array.%GetIterator()
	while iter.%GetNext(.key, .value) {
		$$$CollPushValue(INTO, value, $Select(type="Resource":value.resourceType, 1:type))
	}
}

ClassMethod variantFieldName(
	variantName As %String,
	fhirType As %String) As %String [ CodeMode = expression ]
{
variantName _ $ZCVT($E(fhirType),"U") _ $E(fhirType,2,*)
}

ClassMethod compareJSON(
	obj1 As %DynamicAbstractObject,
	obj2 As %DynamicAbstractObject,
	isArray As %Boolean = 0) As %Boolean
{
	if obj1.%Size() '= obj2.%Size() {
		return 0
	}
	Set iter = obj1.%GetIterator()
	while iter.%GetNext(.key, .value) {
		// If an object, remember the key set
		Set:'isArray KEYS(key) = ""
		// Compare the element types
		Set type = obj1.%GetTypeOf(key)
		if type '= obj2.%GetTypeOf(key) {
			// Different types, not equal
			return 0
		}
		
		if type = "object" {
			set compare = ..compareJSON(obj1.%Get(key), obj2.%Get(key), 0)
		} elseif type = "array" {
			set compare = ..compareJSON(obj1.%Get(key), obj2.%Get(key), 1)
		} else {
			set compare = obj1.%Get(key) = obj2.%Get(key)
		}
		if 'compare {
			return 0
		}
	}
	if 'isArray {
		// Final check: any keys in obj2 that we haven't seen
		Set iter = obj2.%GetIterator()
		while iter.%GetNext(.key, .value) {
			if '$D(KEYS(key)) {
				return 0
			}
		}			
	}
	return 1
}

}
