Include HS.FHIRPath.Parser

/// This class parses a FHIRPath expression and returns a <class>HS.FHIRPath.Node</class> object that
/// is the root of the parse tree.  
Class HS.FHIRPath.Parser Extends %RegisteredObject
{

Parameter MetaGlobalName = "^HS.FHIRPath.Meta";

Property fhirPathVersion As %Integer;

Property lexer As HS.FHIRPath.Lexer;

/// Right now, the parser can handle the syntax for both V1 and V2 of FHIRPath
/// without any conditionals based on the version.  We will keep the input for
/// future use.
Method %OnNew(fhirPathVersion = "2") As %Status
{
	Set ..fhirPathVersion = 2
	Set ..lexer = ##class(Lexer).%New()
	return $$$OK
}

/* Command to test
do ##class(HS.FHIRPath.Lexer).%New().lex("~a+b a(b) 'abcd'",.tokens) for ord=1:1:tokens { w tokens(ord).asString(),! }
*/
Method parse(
	text As %String,
	debug = 0) As Node
{
	Do ..lexer.lex(text, .tokens)
	Return ..parseTokens(.tokens, debug)
}

Method parseTokens(
	ByRef tokens,
	debug = 0) As Node [ Private ]
{
	Set DBG = debug
	
	Set tp = 1
	
	// Access the Token List
	#define GetToken(%n) tokens(%n)
	#define NextToken $$$GetToken($I(tp)-1)
	#define SkipToken if $I(tp) {}
	#define CurToken $$$GetToken(tp-1)
	#define PeekToken $$$GetToken(tp)
	
	#define TokenType(%t) %t.type
	#define TokenClass(%t) %t.subtype
	#define TokenVal(%t)  %t.value
	
	// Access the element stack
	#define SPushMarker(%token,%name) $$$SPushElement($$$SNewElement("m",%token,##class(Node).%New("ID", %name)))
	#define SPushOperator(%token,%node) $$$SPushElement($$$SNewElement("o",%token,%node))
	#define SPushTerm(%token,%node) $$$SPushElement($$$SNewElement("t",%token,%node))
	#define SNewElement(%cls,%token,%node) ##class(PSE).%New(%cls,%token,%node)
	#define SPushElement(%pse)   Set stack($I(sp)) = %pse
	#define SPopElement          stack($I(sp,-1)+1)		
	#define SDropElement         do $I(sp,-1)
	
	#define SElementIsMarker(%el) (%el.cls="m")
	#define SElementIsOperator(%el) (%el.cls="o")
	#define SElementIsTerm(%el) (%el.cls="t")
	#define SElementCanBeUnary(%el) ($$$SElementIsOperator(%el) && $$$TokenCanBeUnary(%el.token))
	#define SElementCanBePostUnary(%el) ($$$SElementIsOperator(%el) && $$$TokenCanBePostUnary(%el.token))
	#define SElementCanBeBinary(%el) ($$$SElementIsOperator(%el) && $$$TokenCanBeBinary(%el.token))

	#define TOS			stack(sp)

	Set result = ""
	
	Set endMarker = $$$NewMarker("EOT", "EOT")
	Set sp = 0
	$$$SPushMarker(endMarker, "EOT")
	for {
		#dim token as Token = $$$NextToken
		w:(DBG>1) "--- Next Token is ", token.asString(),!
		do:(DBG>1) showStack()
		
		if $$$TokenIsMarker(token) {
			// Just push the marker
			$$$SPushMarker(token,token.markerName)
			Continue
		}

		Set useAsOp = $$$TokenCanBeOp(token)
		if useAsOp && $$$TokenCanBeId(token) {
			// Determine whether to treat this as an identifier or an operator
			if $$$TOS.cls '= "t" {
				// If the top of stack is a term, this must be an operator.
				// Otherwise it is a marker or operator and we treat it as a term
				Set useAsOp = 0
			}			
		}
		#dim TOS as PSE 
		#dim TOS2 as PSE 
		if useAsOp { 
			Do Reduce(token)

			if $$$SElementIsMarker($$$TOS) {
				#dim markerElement as PSE = $$$SPopElement
				Set termCount = markerElement.node.children.Count()
				if token.opName = markerElement.token.markerName {
					// We have the closing element for the marker
					if token.opName = "EOT" {
						if termCount > 1 {
							$$$ThrowParseError($$$HSFHIRPathErrSynExpressionList)
						}
						return markerElement.node.children.GetAt(1)	
					} elseif token.opName = ")" {
						// Parenthesized expression list.  If the previous token is
						// an identifier, then convert to a function call
						if $$$SElementIsTerm($$$TOS) {
							#dim fnElement as PSE = $$$SPopElement
							Set fnName = fnElement.node.name
							// Convert to function call
							Set node = ##class(Node).%New("FN", fnName)
							for ord=1:1:termCount {
								Set childNode = markerElement.node.children.GetAt(ord)
								Do node.children.Insert( childNode )
							}
							$$$SPushTerm(markerElement.token, node)
						} else {
							// Push expression term (must only be one)
							if termCount '= 1 {
								$$$ThrowParseError($$$HSFHIRPathErrSynExpressionList)
							}
							$$$SPushTerm(markerElement.token, markerElement.node.children.GetAt(1))
						}						
						
					} elseif token.opName = "]" {
						// Parenthesized expression list.  Convert into an Indexing operation
						
						if $$$SElementIsTerm($$$TOS) {
							if termCount '= 1 {
								$$$ThrowParseError($$$HSFHIRPathErrSynMultiSubscript)
							}
							Do Reduce(##class(Token).NewOperator("[", 85," u "))
							Set contextNode = $$$SPopElement
							// Convert to function call
							Set node = ##class(Node).%New("FN", "subscriptGeneric")
							Set node.context = contextNode.node
							Do node.children.Insert( markerElement.node.children.GetAt(1) )
							$$$SPushTerm(markerElement.token, node)
						} else {
							// Cannot subscript an operator
							$$$ThrowParseError($$$HSFHIRPathErrSynSubscript)
						}						
}
				} elseif token.opName = "," {
					$$$SPushElement(markerElement)
				} else {
					w "Token is operator, but not ,",!
					$$$SPushElement(markerElement)
					Set node = ##class(Node).%New("OP", token.opName)
					$$$SPushOperator(token, node)
				}
			} else {
				Set node = ##class(Node).%New("OP", token.opName)
				$$$SPushOperator(token, node)
			}
			Continue
		}
		
		if $$$TokenCanBeId(token) {
			Set literalType = token.literalType
			if literalType '= "" {
				Set node = ##class(Node).%New("LIT", token.idName)
				Set node.literalType = literalType
			} else {
				// An identifier
				Set node = ##class(Node).%New("ID", token.idName)
			}
			$$$SPushTerm(token, node)
		}
	}
	return ""
	
	
#dim forToken as Token
#dim rLeftOperand as PSE
#dim rOperator as PSE
#dim rRightOperand as PSE
#dim rNode as Node

Reduce(forToken)
	// Top of the stack should be a term (or a marker)
	// below that should be an operator
	set rCycle = 0
	for  {
		w:(DBG>1) "Reduce Cycle "_$I(rCycle)_ ", sp=",sp,", prec= ",forToken.opPrecedence,", op=",forToken.opName,": ",!
		do:(DBG>2) showStack()
		
		// These are the possible stack configurations
		// rTOS| rT2 } rT3
		// m   | -   | -: Done
		// o.u | -   | -: Done
		// o.b | -   | -: Error unless token is Unary Op
		// o.p | t   | -: Apply for post-unary
		// t   | m   | -: Apply for marker
		// t   | o.b | t: Apply for binary
		// t   | o.u | m: Apply for unary
		// t   | o.u | o: Apply for unary
		// t   | o.u | t: Error
		// t   | o.b | m: Error
		// t   | o.b | o: Error
		Set reduceFor = ""
		for {
			// This inner block determines whether to perform a reduction on this cycle.
			// The variable 'reduceFor' indicates the shape of the stack.
			Set rTopElement = $$$TOS
			if $$$SElementIsMarker(rTopElement) || $$$SElementCanBeUnary(rTopElement) {
				Quit
			}
			if $$$SElementCanBeBinary(rTopElement) {
				// Error unless the token is a unary operator
				if ' $$$TokenCanBeUnary(forToken) {
					$$$ThrowParseError($$$HSFHIRPathErrUnexpectedOperator, forToken.opName)
				}
				Quit
			}
			Set rElement2 = stack(sp-1)
			if $$$SElementCanBePostUnary(rTopElement) {
				if $$$SElementIsTerm(rElement2) {
					Set reduceFor = "p"
					Set rOperator = $$$SPopElement
					Set rLeftOperand = $$$SPopElement
					Quit
				}
			}
			
			// If we get here, TOS is a term.
			if $$$SElementIsMarker(rElement2) {
				Set reduceFor = "m"
				Quit
			}
			Set rElement3 = stack(sp-2)
			if $$$SElementCanBeBinary(rElement2) && $$$SElementIsTerm(rElement3) {
				// Reduce a binary operator here
				if forToken.opPrecedence <= stack(sp-1).token.opPrecedence {
					Set reduceFor = "b"
					Set rRightOperand = $$$SPopElement
					Set rOperator = $$$SPopElement
					Set rLeftOperand = $$$SPopElement
				}
				Quit
			}
			if $$$SElementCanBeUnary(rElement2) {
				if $$$SElementIsTerm(rElement3) {
					// This is a binary-only operator between two terms 
					$$$ThrowParseError($$$HSFHIRPathErrUnexpectedOperator, forToken.opName)
				}
				// Reduce unary operator
				if forToken.opPrecedence <= stack(sp-1).token.opPrecedence {
					Set reduceFor = "u"
					Set rRightOperand = $$$SPopElement
					Set rOperator = $$$SPopElement
				}
				Quit
			}
			$$$ThrowParseError($$$HSFHIRPathErrUnexpectedOperator, forToken.opName)
		}
		if reduceFor = "" {
			// Nothing to reduce, we are done with the loop
			Quit
		}
		// Perform a stack reduction
		if reduceFor = "b" {
			// Handle Invocation ('.') specially
			set opName = rOperator.token.opName
			if opName = "." {
				Set rRightOperand.node.context = rLeftOperand.node
				if (rRightOperand.node.name = "extension") || (rRightOperand.node.name = "id") {
					set rLeftOperand.node.pushElement = 1
				}
				$$$SPushTerm(rOperator.token, rRightOperand.node)
			} else {
				// Pop the op and the term and add re-push the expression
				Set rNode = ##class(Node).%New("OP", rOperator.token.opName)
				// Push the operand
				Do rNode.children.Insert(rLeftOperand.node)
				Do rNode.children.Insert(rRightOperand.node)
				$$$SPushTerm(rOperator.token, rNode)
			}
			Continue
		}
		if reduceFor = "m" {
			
			// Pop the term and add it's Node as a child to the marker's Node
			#dim rMarkerElement as PSE = stack(sp-1)
			if (forToken.opName = rMarkerElement.token.markerName) || (forToken.opName = ",") {
				#dim rTermElement as PSE = $$$SPopElement
				Do rMarkerElement.node.children.Insert(rTermElement.node)
			}
			Quit
		}
		if reduceFor = "u" {
			// Pop the op and the term and add re-push the expression
			Set rNode = ##class(Node).%New("OP", rOperator.token.opName)
			Set rNode.isUnary = 1
			// Push the operand
			Do rNode.children.Insert(rRightOperand.node)
			$$$SPushTerm(rOperator.token, rNode)
			Continue
		}
		if reduceFor = "p" {
			// Pop the op and the term and add re-push the expression
			set rNode = ##class(Node).%New("FN", "unitConversion")
			// Push the value to convert
			Do rNode.children.Insert(rLeftOperand.node)
			// Push the target units
			Do rNode.children.Insert(##class(Node).%New("ID", rOperator.token.opName))
			$$$SPushTerm(rOperator.token, rNode)
			Continue
		}
		Quit
	}
	w:(DBG>1) "Reduced",!
	do:(DBG>1) showStack()
	Quit
	
showStack()
	for ssord=1:1:sp {
		#dim ssel as PSE = stack(ssord)
		w "[",ssord,"]: ",ssel.asString(),!
		//do stack(ssord).showTree()
	}
	Quit
}

}
