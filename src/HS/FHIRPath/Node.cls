/// This object is used during parsing and in the representation of the final
/// parse tree.  The property desriptions detail the internal usage. 
/// In the final parse tree, the valid types and values are:
/// <ul>
/// <li> type="ID": An identifier.  value = The name of a variable or FHIR type
/// <li> type="b" A boolean literal.  value = true | false
/// <li> type="s" A string literal.  value = a %String value
/// <li> type="n" A numeric literal.  value = The %Numeric value
/// <li> type="i" An invocation literal.  value = ( $this | $index | $total )
/// <li> type="{}" A null-object literal.
/// <li> type="Expr": An operator.  value = the actual operator (e.g. '+').
/// a special case is a function call which has value="Call" and the actual function name is
/// in the 'functionName' property.  Also, the 'isUnary' property may modify certain operators
/// when they are being used as a unary operator.
/// </ul>
Class HS.FHIRPath.Node Extends %RegisteredObject
{

/// The type of node
/// <ul>
/// <li> type="ID": An identifier.  value = The name of a variable or FHIR type
/// <li> type="OP": An identifier.  value = The name of a variable or FHIR type
/// <li> type="FN": An identifier.  The 'name' property holds the function name.  The 'context' property
/// is a Node describing the input context for the function.  The 'children' property is a list
/// of Node's providing the arguments for the function
/// <li> type="LIT": An identifier.  Literal nodes hold the literal value in the 'name' property,
/// and the literal type (boolean, string, number, object) in the 'literalType' property
/// <li> type="Expr": An operator.  value = the actual operator (e.g. '+').
/// </ul>
Property type As %String;

/// The name of an identifier, operator, or function.  Or the value of a literal.
Property name As %String;

/// Indicates a Unary Operation
Property isUnary As %Boolean;

/// Indicates the type of literal (if type="LIT")
/// <ul>
/// <li> type="b" A boolean literal with a value of true or false
/// <li> type="s" A string literal.  
/// <li> type="n" A numeric literal.
/// <li> type="o" A null-object literal.
/// </ul>
Property literalType As %String;

/// Terms for operator or function call arguments
Property children As list Of Node;

/// The input context for the node (empty = global)
Property context As Node;

/// Set to true if this node is the context node of a primitive Element node.
/// which, if present, contains the 'id' and 'extension' properties for primitive FHIR types
Property pushElement As %Boolean;

Method %OnNew(
	type As %String,
	name As %String) As %Status
{
	Set ..type = type
	Set ..name = name
	return $$$OK
}

/// Serialized Node tree.
/// All elements in this chain are OR'd together in a query
Method toSerial() As %List
{
	// NOTE: This method has to be hand-coded because %SerialObject does not support
	// recursive object references
	set children = ""
	for ord=1:1:..children.Count() {
		Set $List(children,*+1) = ..children.GetAt(ord).toSerial()
	}
	return $ListBuild(..type, ..name, ..isUnary, ..literalType, $S(..context="":"",1:..context.toSerial()), children)
}

ClassMethod fromSerial(ser) As Node
{
	// NOTE: This method has to be hand-coded because %SerialObject does not support
	// recursive object references
	Set node = ..%New($LG(ser,1), $LG(ser,2))
	Set node.isUnary = $LG(ser,3)
	Set node.literalType = $LG(ser,4)
	Set node.context = $S($LG(ser,5)="":"", 1:..fromSerial($LG(ser,5)))
	set ix=0
	while $ListNext($LG(ser,6),ix,cser) {
		do node.children.Insert(..fromSerial(cser))
	}
	return node
}

ClassMethod Test(
	text As %String,
	debug = 0)
{
	Set obj = ##class(HS.FHIRPath.Parser).%New()
	#dim expr as Node = obj.parse(text, debug)
	do expr.showTree()
}

Method showTree()
{
	do ..showNode("", 1)
}

Method showNode(
	prefix As %String = "",
	recurse As %Boolean = 0)
{
	w prefix, ..asString(), !
	Set nextPrefix = prefix _ "  *--"
	if $IsObject(..context) {
		Do ..context.showNode(nextPrefix, recurse)	
	}
	Set nextPrefix = prefix _ "  |--"
	for ord=1:1:..children.Count() {
		Set childNode = ..children.GetAt(ord)
		Do childNode.showNode(nextPrefix, recurse)
	}
}

Method asString()
{
	if ..type="ID" {
		set str = ..name
		if ..pushElement {
			set str = str _ " (as Element)"
		}
	}
	elseif ..type="OP" {
		set str = "[" _ ..name _ $Select(..isUnary:" (Unary ",1:"") _ "]" 
	}
	elseif ..type="FN" {
		set str = ..name _ "()"
	}
	elseif ..type="LIT" {
		if ..literalType = "string" {
			set str = "string: '" _ ..name_ "'"
		} else {
 			Set str = $Case(..literalType, "{}":"object", "inv":"invocation", :..literalType)_": "_..name
		}
	} else {
		w "!Oops!", !
		zw $this
	}
	return str
}

}
