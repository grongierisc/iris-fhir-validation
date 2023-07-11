Include HS.FHIRMeta

/// This class implements the interpreter runtime processing for
/// built-in operator and functions.  Dispatch is based on the name of the
/// function or operator so it is possible to implement support for a new function
/// by simply adding a method to this class.  Because operators are typically special characters,
/// the initializeOperatorToMethodMap method sets up a mapping from the operator name to a
/// valid identifier.  The final method name is prefixed by "IOP" or "IUOP" (for binary or unary)
/// handlers.  Handlers for built-in functions are prefixed by "IFN"
/// <p>
/// Internally, a collection is represented as a multi-dimensional array.  In the method
/// signatures, collections are named in ALL-UPPER-CASE for clarity.
/// <p> Signature for a Built-in Function handler<br>
/// <pre>Method IFN<functionName>(ByRef CONTEXT, args As %ListOfObjects, Output OUTPUT) 
///    CONTEXT      is the context collection for that the function is applied to.
///    arg          is a list of Node object representing the arguments to the function.
///                 The handler can evaluate these arguments by calling processNode with
///                 an appropriate context collection (typically the single input).
///    OUTPUT       is the result collection
///    
/// </pre>
/// <p>
/// During the evaluation of a function, the interpreter calls the handler once per value in
/// the context collection for the function.  The handler will accumulate the result into the 
/// OUTPUT collection.  
/// <p>
/// <p> Signature for a Binary Operator handler 
/// <pre>Method IOP<operatorBaseName>(ByRef LEFT, ByRef RIGHT, Output OUTPUT)
///    LEFT   is the left-side input operand collection
///    RIGHT  is the right-side input operand collection
///    OUTPUT is the result collection
/// </pre>
/// <p> Signature for a Binary Operator handler 
/// <pre>Method IOP<operatorBaseName>(ByRef LEFT, ByRef RIGHT, Output OUTPUT)
///    LEFT   is the left-side input operand collection
///    RIGHT  is the right-side input operand collection
///    OUTPUT is the result collection
/// </pre>
Class HS.FHIRPath.Runtime Extends HS.FHIRPath.Engine
{

Parameter asAllowsMultipleValues = 1;

/* Operators */
/// Initializes a mapping from an operator name to a base method name.
/// The implementation of the operator must prefix the base method name with
/// either IOP (for binary operators) or IUOP (for unary operators).  Note that
/// some operators have both implementations (e.g. '+' and '-')
Method initRuntime() [ Internal ]
{
	Set ..opMap("+") = "plus"
	Set ..opMap("-") = "minus"
	Set ..opMap("*") = "mul"
	Set ..opMap("/") = "div"
	Set ..opMap("=") = "equals"
	Set ..opMap("&") = "concat"
	Set ..opMap("!=") = "ne"
	Set ..opMap("|") = "union"
	Set ..opMap("Index") = "subscript"
	for n="as","is","and","or","xor","implies","in","contains" {
		Set ..opMap(n) = n	
	}
}

/* ----------- Collection Operators ----------------- */
Method IOPunion(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	// Merge the two collections into a single collection, eliminating any duplicate values
	// (using = (Equals) (=)) to determine equality). 
	// There is no expectation of order in the resulting collection.	
	Set OUTPUT = 0

	set boolValue = ""
	// Merge in LEFT values
	for ix=1:1:LEFT {
		if (LEFT(ix, "t") = "boolean") {
			if boolValue '= 1 {
				Set boolValue = LEFT(ix)
			}
		} elseif '$D(INDEX(LEFT(ix, "t"), LEFT(ix))) {
			Set INDEX(LEFT(ix, "t"), LEFT(ix)) = ""
			$$$CollPushFromColl(OUTPUT, LEFT, ix)
		}
	}
	// Merge in RIGHT values
	for ix=1:1:RIGHT {
		if (RIGHT(ix, "t") = "boolean") {
			if boolValue '= 1 {
				Set boolValue = RIGHT(ix)
			}
		} elseif '$D(INDEX(RIGHT(ix, "t"), RIGHT(ix))) {
			Set INDEX(RIGHT(ix, "t"), RIGHT(ix)) = ""
			$$$CollPushFromColl(OUTPUT, RIGHT, ix)
		}
	}
	if boolValue '= "" {
		$$$CollPushBoolean(OUTPUT, boolValue)
	}
}

Method IOPin(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	do ..IOPcontains(.RIGHT, .LEFT, .OUTPUT)
}

Method IOPcontains(
	ByRef COLL,
	ByRef SCALAR,
	ByRef OUTPUT) [ Private ]
{
	set OUTPUT=0
	if SCALAR = 0 {
		// Return empty if scalar is empty
		return
	}
	if SCALAR > 1 {
		// Error if SCALAR is not a singleton collection
		$$$ThrowError($$$HSFHIRPathErrInvalidInputForIn)	
	}
	set result = 0
	
	for ix=1:1:COLL {
		kill ELEM
		// Check each element
		$$$CollPushFromColl(ELEM, COLL, ix)
		// Apply Equals Semantics
		do ..IOPequals(.ELEM, .SCALAR, .OUT)
		if OUT(1) {
			// Found a matching element, we're done
			set result = 1
			Quit
		}
	}	
	$$$CollPushBoolean(OUTPUT, result)
}

Method verifyType(ByRef ARG) As %String
{
	Set typeStr = $Select(ARG=0:"", 1:ARG(1))
	Set outType = $$adjustType(typeStr)
	if (outType = "") {
		$$$ThrowError($$$HSFHIRPathErrInvalidFHIRType, typeStr)	
	}
	return outType
	
adjustType(t)
	// There is bad configuration data in the base FHIR packages that specify
	// a primitive data type starting with an upper-case letter in a FHIRPath expression
	// (e.g. 'String' instead of 'string' or 'DateTime' instead of 'dateTime')  This
	// code adjusts for that bad metadata.
	if t="" Quit t
	if ..schema.IsFHIRType(t) Quit t
	Set t1 = $ZConvert($E(t),"L") _ $E(t,2,*)
	if ..schema.IsFHIRType(t1) Quit t1
	Quit ""
}

Method IOPas(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	// If the left operand is a collection with a single item and the second operand 
	// is an identifier, this operator returns the value of the left operand if
	// it is of the type specified in the second operand, or a subclass thereof. 
	// If the identifier cannot be resolved to a valid type identifier, the evaluator will throw an error. 
	// If there is more than one item in the input collection, the evaluator will throw an error.
	// Otherwise, this operator returns the empty collection.
	Set OUTPUT = 0
	Set targetType = ..verifyType(.RIGHT)
	
	#if '..#asAllowsMultipleValues
		// Disabled until FHIR Metadata (or FHIRPath spec) is corrected
		if LEFT > 1 {
			$$$ThrowError($$$HSFHIRPathErrInvalidInputForAs)	
		}
		if LEFT = 1 {
			if ..schema.IsA(LEFT(1,"t"), targetType) {
				$$$CollPushFromColl(OUTPUT, LEFT, 1)
			}
		}
	#else
		// Violating the FHIRPath spec here for robustness purposes. Here's why:
		// The FHIR Spec states: "If there is more than one item in the input collection, the evaluator will throw an error." 
		// However several FHIR SearchParameters process have expressions like: 
		//    "Observation.component.value as CodeableConcept".	
		// Though component.value itself has only a single value, 'component' is an array so the left side will indeed have multiple
		// values.  The proper expression for these parameters would be:
		//    "Observation.component.value.ofType(CodeableConcept)"
		// Therefore: We are leaving this function lenient as to the size of the input collection.

		for ord=1:1:LEFT {
			if ..schema.IsA(LEFT(ord,"t"), targetType) {
				$$$CollPushFromColl(OUTPUT, LEFT, ord)
			}
		}
	
	#endif
}

Method IOPis(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set OUTPUT = 0
	Set targetType = RIGHT(1)
	if LEFT > 1 {
		$$$ThrowError($$$HSFHIRPathErrInvalidInputForAs)	
	}
	// False if empty input collection, otherwise type must match the target
	$$$CollPushBoolean(OUTPUT, (LEFT=1) && ..schema.IsA(LEFT(1,"t"), targetType))
}

/* ----------- Logical Operators ----------------- */
Method IOPand(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set v1 = ..ToSingletonBoolean(.LEFT, "and")
	Set v2 = ..ToSingletonBoolean(.RIGHT, "and")
	Kill OUTPUT
	set OUTPUT=0
	
	if (v1=0) || (v2=0) {
		$$$CollPushBoolean(OUTPUT, 0)
		return
	}
	elseif (v1=1) && (v2=1) {
		$$$CollPushBoolean(OUTPUT, 1)
		return
	} 
	// Otherwise return an empty collection
}

Method IOPimplies(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set v1 = ..ToSingletonBoolean(.LEFT, "or")
	Set v2 = ..ToSingletonBoolean(.RIGHT, "or")
	Kill OUTPUT
	set OUTPUT=0
	
	if (v1=1) {
		// If the left operand evaluates to true, this operator returns the boolean evaluation of the right operand. 
		if (v2 '= "" ) {
			$$$CollPushBoolean(OUTPUT, v2)
		}
	}
	elseif (v1=0) {
		// If the left operand evaluates to false, this operator returns true.
		$$$CollPushBoolean(OUTPUT, 1)
	} 
	// Otherwise, this operator returns true if the right operand evaluates to true, and the empty collection ({ }) otherwise.
	elseif (v2=1) {
		$$$CollPushBoolean(OUTPUT, 1)
	}
}

Method IOPor(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set v1 = ..ToSingletonBoolean(.LEFT, "or")
	Set v2 = ..ToSingletonBoolean(.RIGHT, "or")
	Kill OUTPUT
	set OUTPUT=0
	
	if (v1=1) || (v2=1) {
		$$$CollPushBoolean(OUTPUT, 1)
		return
	}
	elseif (v1=0) && (v2=0) {
		$$$CollPushBoolean(OUTPUT, 0)
		return
	} 
	// Otherwise return an empty collection
}

Method IOPxor(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set v1 = ..ToSingletonBoolean(.LEFT, "xor")
	Set v2 = ..ToSingletonBoolean(.RIGHT, "xor")
	Kill OUTPUT
	set OUTPUT=0
	
	if (v1="") || (v2="") {
		// Either empty returns empty
		return
	}
	$$$CollPushBoolean(OUTPUT, v1 '= v2)
}

ClassMethod ToSingletonBoolean(
	ByRef INPUT,
	methodName As %String) As %Boolean [ Private ]
{
	// This method evaluates a collection according to the "Singleton Evaluation of Collections" rules where the
	// expected input type is a boolean.  The rule is:
	// <pre>
	// IF the collection contains a single node AND the node's value can be converted to the expected input type THEN
	//  The collection evaluates to the value of that single node
	// ELSE IF the collection contains a single node AND the expected input type is Boolean THEN
	//  The collection evaluates to true
	// ELSE IF the collection is empty THEN
	//  The collection evaluates to an empty collection
	// ELSE
	//  The evaluation will end and signal an error to the calling environment
	// </pre>
	// @Return - 1 if a true value, 0 if a false value, "" if an empty collection
	if INPUT = 0 {
		// IF the collection is empty THEN The collection evaluates to an empty collection
		return ""
	}
	if INPUT = 1 {
		if INPUT(1, "t") = "boolean" {
			return INPUT(1)	
		} else {
			// IF the collection contains a single node AND the expected input type is Boolean THEN the collection evaluates to true
			return 1
		}
	}
	$$$ThrowError($$$HSFHIRPathErrSingletonBooleanRequired, methodName)
}

/* ----------- Equality Operators ----------------- */
Method IOPequals(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (LEFT=0) || (RIGHT=0) {
		// If either input is an empty collection, output is an empty collection
	} elseif (LEFT '= RIGHT) {
		// Return false if array lengths are unequal
		$$$CollPushBoolean(OUTPUT, 0)
		
	} else {
		// All values must be equal
		set result = 1
		for ord=1:1:LEFT {
			Set jt1 = ..fhirTypeToJsonType(LEFT(ord,"t"))
			Set jt2 = ..fhirTypeToJsonType(RIGHT(ord,"t"))
			if (jt1 = "o") || (jt2 = "o") {
				// One or more Object(s)
				if jt1 '= jt2  {
					// One Object, not equal
					set result = 0
				} else {
					// Compare them
					set result = ..compareJSON(LEFT(ord), RIGHT(ord))
				}
			} else {
				// Scalars
				Set result = LEFT(ord) = RIGHT(ord)
			}
			Quit:result=0
		}
		$$$CollPushBoolean(OUTPUT, result)
	}
}

Method IOPne(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT)
{
	Do ..IOPequals(.LEFT, .RIGHT, .OUTPUT)
	if OUTPUT = 1 {
		Set OUTPUT(1) = 1 - OUTPUT(1)	
	}
}

/* ----------- Math Operators ----------------- */
Method IOPplus(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT) [ ProcedureBlock = 0 ]
{
	Do ..MathOperation(.LEFT, .RIGHT, .OUTPUT, "+")
}

Method IOPminus(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT) [ ProcedureBlock = 0 ]
{
	Do ..MathOperation(.LEFT, .RIGHT, .OUTPUT, "-")
}

Method IOPmul(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT) [ ProcedureBlock = 0 ]
{
	Do ..MathOperation(.LEFT, .RIGHT, .OUTPUT, "*")
}

Method IOPdiv(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT) [ ProcedureBlock = 0 ]
{
	Do ..MathOperation(.LEFT, .RIGHT, .OUTPUT, "/")
}

Method MathOperation(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT,
	name As %String)
{
	Set OUTPUT = 0
	if ( (LEFT = 0) || (RIGHT = 0) ) {
		// the math operators will return an empty collection if one or both of the operands are empty.
		return
	}
	if ( (LEFT '= 1) || (RIGHT '= 1) ) {
		$$$ThrowError($$$HSFHIRPathErrSingletonCollectionRequired, name)	
	}
	Set leftType =  ..fhirTypeToMathType( LEFT(1,"t") )
	Set rightType =  ..fhirTypeToMathType( RIGHT(1,"t") )
	Set leftValue = LEFT(1)
	Set rightValue = RIGHT(1)
	Set leftCode = $S(leftType="q":leftValue.code,1:"")
	Set rightCode = $S(rightType="q":rightValue.code,1:"")
	
	if leftType '= rightType {
		// Coersce only mixed number and Quantity
		Set pair = leftType _ rightType
		if pair = "nq" {
			Set leftValue = { "value":(leftValue) }
			set leftType = "q"
			set leftCode = "1"
		} elseif pair = "qn" {
			Set rightValue = { "value":(rightValue) }
			Set rightCode = "1"
			Set rightType = "q"
		} else {
			$$$ThrowError($$$HSFHIRPathErrIncompatibleTypes, name, LEFT(1,"t"), RIGHT(1,"t"))	
		}
	}
	Do $Case(name _ leftType,
		"+n":addNumber(),
		"+s":addString(),
		"+d":noSupport(),
		"+q":addQuantity(),
		
		"-n":subNumber(),
		"-s":typeError(),
		"-d":noSupport(),
		"-q":subQuantity(),

		"*n":mulNumber(),
		"*s":typeError(),
		"*d":noSupport(),
		"*q":mulQuantity(),

		"/n":divNumber(),
		"/s":typeError(),
		"/d":noSupport(),
		"/q":divQuantity()
	)
	return
	
typeError()
	$$$ThrowError($$$HSFHIRPathErrIncompatibleTypes, name, LEFT(1,"t"), RIGHT(1,"t"))	
	Quit
noSupport()
	$$$ThrowError($$$HSFHIRPathErrIncompatibleTypes, name, LEFT(1,"t"), RIGHT(1,"t"))	
	Quit
	
addNumber()
	Set resultValue = leftValue + rightValue
	$$$CollPushValue(OUTPUT, resultValue, $S($Find(resultValue,"."):"decimal", 1:"integer"))
	Quit
addString()
	$$$CollPushValue(OUTPUT, leftValue _ rightValue, "string")
	Quit
addQuantity()
	if leftCode '= rightCode {
		$$$ThrowError($$$HSFHIRPathErrIncompatibleUnits, name, leftCode, rightCode)
	}
	Set q = { "value":(leftValue.value + rightValue.value) }
	if leftCode '= ""  Set q.code = leftCode
	$$$CollPushValue(OUTPUT, q, "Quantity")
	Quit
	
subNumber()
	Set resultValue = leftValue - rightValue
	$$$CollPushValue(OUTPUT, resultValue, $S($Find(resultValue,"."):"decimal", 1:"integer"))
	Quit
	
subQuantity()
	if leftCode '= rightCode {
		$$$ThrowError($$$HSFHIRPathErrIncompatibleUnits, name, leftCode, rightCode)
	}
	Set q = { "value":(leftValue.value + rightValue.value) }
	if leftCode '= ""  Set q.code = leftCode
	$$$CollPushValue(OUTPUT, q, "Quantity")
	Quit
	
mulNumber()
	Set resultValue = leftValue * rightValue
	$$$CollPushValue(OUTPUT, resultValue, $S($Find(resultValue,"."):"decimal", 1:"integer"))
	Quit
	
mulQuantity()
	if leftCode '= rightCode {
		$$$ThrowError($$$HSFHIRPathErrIncompatibleUnits, name, leftCode, rightCode)
	}
	Set q = { "value":(leftValue.value + rightValue.value) }
	if leftCode '= ""  Set q.code = leftCode
	$$$CollPushValue(OUTPUT, q, "Quantity")
	Quit
	
divNumber()
	if rightValue '= 0 {
		Set resultValue = leftValue / rightValue
		$$$CollPushValue(OUTPUT, resultValue, $S($Find(resultValue,"."):"decimal", 1:"integer"))
	}
	Quit
	
divQuantity()
	if leftCode '= rightCode {
		$$$ThrowError($$$HSFHIRPathErrIncompatibleUnits, name, leftCode, rightCode)
	}
	Set q = { "value":(leftValue.value + rightValue.value) }
	if leftCode '= ""  Set q.code = leftCode
	$$$CollPushValue(OUTPUT, q, "Quantity")
	Quit
}

Method mathArg(
	fhirValue,
	fhirType As %String,
	Output mathType,
	Output units) [ Private ]
{
	Set mathType = ..fhirTypeToMathType(fhirType)
	Set units = ""
	if (mathType = "q") {
		Set units = $Select(fhirValue.code'="":fhirValue.code, 1:fhirValue.unit)
		Set mathValue = fhirValue.value
		Set mathType = "n"
	} else {
		Set mathValue = fhirValue
	}
	return mathValue
}

/* ----------- String Operators ----------------- */
Method IOPconcat(
	ByRef LEFT,
	ByRef RIGHT,
	Output OUTPUT,
	name As %String)
{
	// For strings, will concatenate the strings, where an empty operand is taken to be the empty string.
	// This differs from + on two strings, which will result in an empty collection when one of the operands is empty. 
	// This operator is specifically included to simplify treating an empty collection as an empty string, a common use case in string manipulation.	
	Set OUTPUT = 0
	if ( (LEFT > 1) || (RIGHT > 1) ) {
		$$$ThrowError($$$HSFHIRPathErrSingletonCollectionRequired, name)	
	}
	Set leftVal =  $S(LEFT=0:"", 1:..fhirTypeToStringType(LEFT(1), LEFT(1,"t")))
	Set rightVal = $S(RIGHT=0:"", 1:..fhirTypeToStringType(RIGHT(1), RIGHT(1,"t")))
	$$$CollPushString(OUTPUT, leftVal _ rightVal)
}

/* ----------- Comparison Operators ----------------- */

/* Built-in Functions */
/// extension(<url>) === extension.where(url is <url>)
Method IFNunitConversion(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	#dim litNode as Node = args.GetAt(1)
	#dim unitNode as Node = args.GetAt(2)
	Set ucum = $Case(unitNode.name,
		"millisecond":"ms", "milliseconds":"ms",
		"minute":"min", "minutes":"min", 
		"week":"wk", "weeks":"wk",
		"year":"a",  "years":"a", 
		"month":"mo", "months":"mo",
		"day":"d", "days":"d",
		"second":"s", "seconds":"s",
		"hour":"h", "hours":"h"
	)
	Set value = litNode.name
	if ucum = "ms" {
		Set value = value / 1000
		Set ucum = "s"
	}
	Set quantity = { "system":"http://unitsofmeasure.org", "code":(ucum), "unit":(ucum), "value":(value) }
	Set OUTPUT=0
	$$$CollPushValue(OUTPUT, quantity, "Quantity")
}

/// extension(<url>) === extension.where(url is <url>)
Method IFNaggregate(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	Set argCount = args.Count()
	if (argCount = 0 || argCount > 2) {
		$$$ThrowError(, "aggregate", "1 or 2")	
	}
	
	if argCount = 2 {
		// Evaluate the initNode
		#dim initNode as Node = args.GetAt(2)
		Set INIT=0
		Do ..processNode(initNode, .NOCTX, .INIT)
		
		if (INIT '= 1) || '$$$CollIsNumber(INIT, 1) {
			$$$ThrowError($$$HSFHIRPathErrInvalidInitialAggregateValue)	
		}
		// Save Type
		Set ..FNSCOPE("$total") = INIT(1)
	}

	#dim valueNode as Node = args.GetAt(1)
	
	// Loop through the context values filtering against the argument expression
	for ix=1:1:CONTEXT {
		
		Set ..FNSCOPE("$index") = ix-1
		Merge ..FNSCOPE("$this") = CONTEXT(ix)

		Set VALUE = 0
		Set FNCTX = 0
		$$$CollPushFromColl(FNCTX, CONTEXT, ix)
		Do ..processNode(valueNode, .FNCTX, .VALUE)
		if (VALUE = 1) && $$$CollIsNumber(VALUE,1) {
			Set ..FNSCOPE("$total") = VALUE(1)
		}
	}
	$$$CollPushValue(OUTPUT, ..FNSCOPE("$total"), "decimal")
}

Method IFNiif(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 3) {
		$$$ThrowError($$$HSFHIRPathErrArgsRequired, "iif", 3)	
	}
	#dim testNode as Node = args.GetAt(1)
	kill NOCTX
	kill CONDITION
	// Evaluate the boolean expression that is the first argument, using
	// the provided value as the 1-element context
	Do ..processNode(testNode, .NOCTX, .CONDITION)
	#dim resultNode as Node = args.GetAt(1)
	if CONDITION && CONDITION(1) {
		// Evaluate the arg(2)
		Set resultNode= args.GetAt(2)
	} else {
		// Evaluate the arg(3)
		Set resultNode= args.GetAt(3)
	}
	Do ..processNode(resultNode, .CONTEXT, .OUTPUT)
}

Method IFNnot(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 0) {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "not")	
	}
	Set value = ..ToSingletonBoolean(.CONTEXT, "not")
	if value '= "" {
		$$$CollPushBoolean(OUTPUT, 1-value)
	}
}

Method IFNresolve(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 0) {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "resolve")	
	}
	Do ..resolveToResource(.CONTEXT, .OUTPUT)
}

Method IFNunion(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 1) {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "union")	
	}
	#dim argNode as Node = args.GetAt(1)
	kill NOCTX
	// Get the collection which is the argument to the function
	Do ..processNode(argNode, .CONTEXT, .RESULT)
	Do ..IOPunion(.CONTEXT, .RESULT, .OUTPUT)
}

/* Built-in Functions */
Method IFNwhere(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 1) {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "where")	
	}

	// Loop through the context values filtering against the argument expression
	for ix=1:1:CONTEXT {
		Set ..FNSCOPE("$index") = ix-1
		Merge ..FNSCOPE("$this") = CONTEXT(ix)
		// Check for a "resolve() is <type>" clause, handle separately
		#dim whereFnNode as Node = args.GetAt(1)
		kill FNCTX
		kill MATCHES
		$$$CollPushFromColl(FNCTX, CONTEXT, ix)
		// Evaluate the boolean expression that is the first argument, using
		// the provided value as the 1-element context
		Do ..processNode(whereFnNode, .FNCTX, .MATCHES)
		if MATCHES && MATCHES(1) {
			$$$CollPushFromColl(OUTPUT, CONTEXT, ix)
		}
	}
}

Method IFNofType(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 1) {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "extension")	
	}
	Set targetType = args.GetAt(1).name
	for ix=1:1:CONTEXT {
		if ..schema.IsA(CONTEXT(ix,"t"), targetType) {
			$$$CollPushFromColl(OUTPUT, CONTEXT, ix)
		}
	}
}

/// extension(<url>) === extension.where(url is <url>)
Method IFNextension(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count() '= 1) {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "extension")	
	}
	Set urlValue = args.GetAt(1).name

	// Loop through the context values filtering against the argument expression
	for ix=1:1:CONTEXT {
		Set extn = CONTEXT(ix).extension
		Continue:extn=""
		Set iter = extn.%GetIterator()
		while iter.%GetNext(.subsc, .extensionObj) {
			if extensionObj.url = urlValue {
				$$$CollPushValue(OUTPUT, extensionObj, "Extension")
			}
		}
	}
}

/// extension(<url>) === extension.where(url is <url>)
Method IFNhasExtension(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Do ..IFNextension(CONTEXT,args,.TOUTPUT)
	$$$CollPushBoolean(OUTPUT,TOUTPUT>0)
}

Method IFNempty(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if (args.Count()) {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "empty")	
	}
	$$$CollPushBoolean(OUTPUT,$Get(CONTEXT,0)=0)
	return 1
}

Method IFNexists(
	CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	if (args.Count() > 1) {
		$$$ThrowError($$$HSFHIRPathErrTooManyArgs1, "exists")	
	}

	if $Get(CONTEXT,0) = 0 {
		// Return false for an empty context collection
		$$$CollPushBoolean(OUTPUT,0)
		return
	} elseif args.Count() =0 {
		// Return true for a non-empty context and an empty filter
		$$$CollPushBoolean(OUTPUT,1)
		return
	}
	
	// Loop through the context values filtering against the argument expression
	// If any value matches the filter, return true.
	Set OUTPUT = 0
	Set exists = 0
	Set filterNode = args.GetAt(1)
	for ix=1:1:CONTEXT {
		Set ..FNSCOPE("$index") = ix-1
		Merge ..FNSCOPE("$this") = CONTEXT(ix)

		Set FNCTX = 0
		kill MATCHES
		$$$CollPushFromColl(FNCTX, CONTEXT, ix)
		// Evaluate the boolean filter expression against the CONTEXT element
		Do ..processNode(filterNode, .FNCTX, .MATCHES)
		if MATCHES(1) {
			set exists = 1
			Quit
		}
	}
	$$$CollPushBoolean(OUTPUT, exists)
}

/* 
	---------- String Manipulation Functions -------------- 
	The functions in this section operate on collections with a single item. 
	If there is more than one item, or an item that is not a String, 
	the evaluation of the expression will end and signal an error to the calling environment.
*/
Method checkStringFunction(
	fnName As %String,
	inputMin As %Integer,
	inputMax As %Integer,
	ByRef CONTEXT,
	args As %ListOfObjects) As %Boolean
{
	set argcount = args.Count()
	if inputMin = inputMax {
		// Single argument
		if argcount '= inputMin {
			if inputMin = 1 {
				$$$ThrowError($$$HSFHIRPathErrOneArgRequired, fnName)	
			} else {
				$$$ThrowError($$$HSFHIRPathErrArgsRequired, fnName, inputMin)	
			}
		}
	} elseif (argcount < inputMin) || (argcount > inputMax) {
		$$$ThrowError($$$HSFHIRPathErrArgRangeRequired, fnName, inputMin, inputMax)	
	}
	if CONTEXT=0 {
		// SPEC: If the input collection is empty, the result is empty.
		return 0
	}
	if CONTEXT > 1 {
		$$$ThrowError($$$HSFHIRPathErrNoCollectionAllowed, fnName)	
	}
	if CONTEXT(1,"t") '= "string" {
		$$$ThrowError($$$HSFHIRPathErrStringRequired, fnName)	
	}
	return 1
}

Method IFNstartsWith(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if ..checkStringFunction("startsWith", 1, 1, .CONTEXT, args) {
		Do ..processNode(args.GetAt(1), .FNCTX, .VALUE)
		if $D(VALUE(1), find) {
			set in = CONTEXT(1)
			$$$CollPushBoolean(OUTPUT, $E(in,1,$Length(find)) = find)
		}
	}
}

Method IFNendsWith(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if ..checkStringFunction("endsWith", 1, 1, .CONTEXT, args) {
		Do ..processNode(args.GetAt(1), .FNCTX, .VALUE)
		if $D(VALUE(1), find) {
			set in = CONTEXT(1)
			$$$CollPushBoolean(OUTPUT, $E(in,*+1-$Length(find),*) = find)
		}
	}
}

Method IFNindexOf(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if ..checkStringFunction("indexOf", 1, 1, .CONTEXT, args) {
		Do ..processNode(args.GetAt(1), .FNCTX, .VALUE)
		if $D(VALUE(1), find) {
			set in = CONTEXT(1)
			set index = $FIND(in,find)
			$$$CollPushNumber(OUTPUT, index - $S(index=0:0, 1:$Length(find)) - 1)
		}
	}
}

Method IFNsubstring(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if ..checkStringFunction("indexOf", 1, 2, .CONTEXT, args) {
		Do ..processNode(args.GetAt(1), .FNCTX, .VALUE)
		if $D(VALUE(1), first) {
			set string = CONTEXT(1)
			if (first < 0) || (first >= $Length(string)) {
				// If start lies outside the length of the string, the function returns empty
				return
			}
			
			set last = $Case(args.Count(), 2:first + args.GetAt(2).name - 1, :9999999999)
			$$$CollPushString(OUTPUT, $E(string, first+1, last+1))
		}
	}
}

Method IFNchildren(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	if (args.Count()) {
		$$$ThrowError($$$HSFHIRPathErrTooManyArgs, "children", 0)	
	}
	for ix=1:1:CONTEXT {
		set value = CONTEXT(ix)
		if $IsObject(value) && value.%IsA("%DynamicObject") {
			set fhirType = CONTEXT(ix,"t")
			do ..addChildren(value, fhirType, 0, .OUTPUT)
		}
	}
}

Method IFNdescendants(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	if (args.Count()) {
		$$$ThrowError($$$HSFHIRPathErrTooManyArgs, "descendants", 0)	
	}
	for ix=1:1:CONTEXT {
		set value = CONTEXT(ix)
		if $IsObject(value) && value.%IsA("%DynamicObject") {
			set fhirType = CONTEXT(ix,"t")
			do ..addChildren(value, fhirType, 1, .OUTPUT)
		}
	}
}

Method addChildren(
	value As %DynamicObject,
	fhirType As %String,
	recurse As %Boolean,
	ByRef OUTPUT) [ Private ]
{
	set iter = value.%GetIterator()
	while iter.%GetNext(.propName, .propValue) {
		Continue:(propName = "resourceType")
		// Leading underscore indicates Extension on a primitive property.
		if $extract(propName) '= "_" {
			set propType = ..schema.GetPropertyFHIRType(fhirType, propName)
		} else {
			set propType = "Extension"
		}
		if propType = "Resource" {
			set propType = value.%Get(propName).resourceType
		}
		if '..schema.IsPropertyArray(fhirType, propName) {
			$$$CollPushValue(OUTPUT, propValue, propType)
			if recurse && $IsObject(propValue) && propValue.%IsA("%DynamicObject") {
				do ..addChildren(propValue, propType, 1, .OUTPUT)
			}
		} else {
			set aiter = propValue.%GetIterator()
			while aiter.%GetNext(.ix, .elementValue) {
				$$$CollPushValue(OUTPUT, elementValue, propType)
				if recurse && $IsObject(elementValue) && elementValue.%IsA("%DynamicObject") {
					do ..addChildren(elementValue, propType, 1, .OUTPUT)
				}
			}
		}
	}
}

/// Apply subsetting function single().
/// https://hl7.org/fhirpath/#single-collection
Method IFNsingle(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if args.Count() {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "single")
	}
	if $Get(CONTEXT) > 0 {
		if CONTEXT = 1 {
			$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
		} else {
			$$$ThrowError("$$$HSFHIRPathErrTooManyCollectionItems", "single")
		}
	}
}

/// Apply subsetting function first().
/// https://hl7.org/fhirpath/#first-collection
Method IFNfirst(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if args.Count() {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "first")
	}
	if $Get(CONTEXT) > 0 {
		$$$CollPushFromColl(OUTPUT, CONTEXT, 1)
	}
}

/// Apply subsetting function last().
/// https://hl7.org/fhirpath/#last-collection
Method IFNlast(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if args.Count() {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "last")	
	}
	if $Get(CONTEXT) > 0 {
		$$$CollPushFromColl(OUTPUT, CONTEXT, CONTEXT)
	}
}

/// Apply subsetting function tail().
/// https://hl7.org/fhirpath/#tail-collection
Method IFNtail(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	if args.Count() {
		$$$ThrowError($$$HSFHIRPathErrNoArgsAllowed, "tail")
	}
	if $Get(CONTEXT) > 1 {
		For i = 2:1:CONTEXT {
			$$$CollPushFromColl(OUTPUT, CONTEXT, i)
		}
	}
}

/// Apply subsetting function skip().
/// https://hl7.org/fhirpath/#skipnum-integer-collection
Method IFNskip(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	
	if args.Count() '= 1 {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "skip")
	}
	
	Set argValue = args.GetAt(1).name
	
	// Do a pattern match check to optimize performance.
	if argValue?1N.N {
		Set argValue = +argValue
	} else {
		Do ..processNode(args.GetAt(1), .CONTEXT, .RESULT)
		if $Data(RESULT(1)) {
			Set argValue = RESULT(1)
		}
		if $Get(RESULT(1,"t")) '= "integer" {
			$$$ThrowError("IvalidFormat", "skip", argValue, "integer")
		}
	}
	
	For i = (argValue+1):1:$Get(CONTEXT) {
		$$$CollPushFromColl(OUTPUT, CONTEXT, i)
	}
}

/// Apply subsetting function take().
/// https://hl7.org/fhirpath/#takenum-integer-collection
Method IFNtake(
	ByRef CONTEXT,
	args As %ListOfObjects,
	Output OUTPUT)
{
	Set OUTPUT = 0
	
	if args.Count() '= 1 {
		$$$ThrowError($$$HSFHIRPathErrOneArgRequired, "take")
	}
	
	Set argValue = args.GetAt(1).name
	
	// Do a pattern match check to optimize performance.
	if argValue?1N.N {
		Set argValue = +argValue
	} else {
		Do ..processNode(args.GetAt(1), .CONTEXT, .RESULT)
		if $Data(RESULT(1)) {
			Set argValue = RESULT(1)
		}
		if $Get(RESULT(1,"t")) '= "integer" {
			$$$ThrowError("InvalidFormat", "take", argValue, "integer")
		}
	}
	
	For i = 1:1:argValue {
		Quit:'$Data(CONTEXT(i))
		$$$CollPushFromColl(OUTPUT, CONTEXT, i)
	}
}

}
