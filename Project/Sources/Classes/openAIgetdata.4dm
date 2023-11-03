property apiKey; attributeName; attributeType; remark; systemPrompt; userPrompt : Text
property quantity; failedAttempts; maxFailedAttempts; lastFetchDuration; fetchStatusCode : Integer
property valueList; messages : Collection

Class constructor($apiKey : Text; $attributeName : Text; $attributeType : Text; $quantity : Integer; $remark : Text)
	
	This.apiKey:=$apiKey
	This.attributeName:=$attributeName
	This.attributeType:=$attributeType
	This.quantity:=$quantity
	This.remark:=$remark
	This.valueList:=[]
	This.systemPrompt:="You are data generator. "
	This.systemPrompt+="You will be provided with a description values to generate; and your task is to generate as many values as requested. "
	This.systemPrompt+="Generated values must be separated by the character separator ¶. "
	This.systemPrompt+="The file must start with 2 characters: ¶¶. "
	This.systemPrompt+="The file must end with 2 characters: ¶¶. "
	
	This.messages:=[]
	This.messages.push({role: "system"; content: This.systemPrompt})
	This.messages.push({role: "user"; content: "Generate a list of exactly 10 values for \"firstname\" of type Text."})
	This.messages.push({role: "assistant"; content: "¶¶Alice¶Oliver¶Elsa¶Liam¶Maja¶Noah¶Ella¶Lucas¶Wilma¶Hugo¶¶"})
	This.messages.push({role: "user"; content: "Generate a list of exactly 10 values for \"amount\" of type number."})
	This.messages.push({role: "assistant"; content: "¶¶35¶64797¶101246¶3¶119¶4477¶647779¶357769¶94¶77¶¶"})
	This.messages.push({role: "user"; content: "Generate a list of exactly 5 values for \"birthdate\" of type date."})
	This.messages.push({role: "assistant"; content: "¶¶1980-10-05¶2035-05-02¶1995-12-15¶2022-10-14¶2011-05-23¶¶"})
	
	This.userPrompt:="Generate a list of exactly "+String($quantity)+" values for \""+String($attributeName)+"\" of type "+This.attributeType+"."
	This.userPrompt+=($remark#"") ? (" Remark: "+$remark) : ""
	If ($attributeType="date")
		This.userPrompt+=". Date format: YYYY-MM-DD"
	End if 
	
	This.failedAttempts:=0
	This.maxFailedAttempts:=5
	This.fetchStatusCode:=200
	
Function getNextValue() : Text
	If (This.valueList.length=0)
		This.getNewValues()
	End if 
	
	Case of 
		: (This.fetchStatusCode#200)
			return ""
			
		: (This.valueList.length=0)
			throw(1; "Value list is empty")
			return ""
			
		Else 
			return This.valueList.shift()
	End case 
	
Function getNewValues()
	var $response : Text
	var $valuesText : Text
	var $values : Collection
	var $fstart; $fend : Integer
	
	If (This.failedAttempts<This.maxFailedAttempts)
		$response:=This.queryOpenAI()
		If (This.fetchStatusCode=200)
			$fstart:=Position("¶¶"; $response)
			If ($fstart>0)
				$fstart+=2
				$fend:=Position("¶¶"; $response; $fstart)
				
				If ($fend>0)
					$valuesText:=Substring($response; $fstart; $fend-$fstart)
					$values:=Split string($valuesText; "¶"; sk ignore empty strings+sk trim spaces)
					This.valueList:=This.valueList.concat($values)
				Else 
					This.failedAttempts+=1
					This.getNewValues()
				End if 
			Else 
				This.failedAttempts+=1
				This.getNewValues()
			End if 
		End if 
	End if 
	
	
Function queryOpenAI() : Text
	var $url : Text
	var $headers; $data; $opts : Object
	var $request : 4D.HTTPRequest
	var $startTime : Integer
	
	$url:="https://api.openai.com/v1/chat/completions"
	$headers:=New object("Authorization"; "Bearer "+This.apiKey; "Content-Type"; "application/json")
	
	$data:={}
	$data.model:="gpt-3.5-turbo"
	$data.messages:=This.messages.copy()
	$data.messages.push({role: "user"; content: This.userPrompt})
	
	$opts:={method: "POST"; headers: $headers; body: $data}
	
	This.lastFetchDuration:=Milliseconds
	$request:=4D.HTTPRequest.new($url; $opts)
	$request.wait()
	This.lastFetchDuration:=Milliseconds-This.lastFetchDuration
	
	This.fetchStatusCode:=$request.response.status
	
	If (This.fetchStatusCode=200)
		return $request.response.body.choices[0].message.content
	Else 
		return ""
	End if 
	
	