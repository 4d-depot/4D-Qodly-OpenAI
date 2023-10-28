Class extends DataStoreImplementation

Function showItem($itemName : Text)
	Web Form[$itemName].show()
	
Function hideItem($itemName : Text)
	Web Form[$itemName].hide()
	
exposed Function showHideAIPanel($value : Text; $componentRef : Text)
	If ($value="openAI")
		This.showItem($componentRef)
	Else 
		This.hideItem($componentRef)
	End if 
	
exposed Function showHideUpdateSection($selectedAttribute : Object; $componentRef : Text)
	Case of 
		: ($selectedAttribute.value.whatToDo="nothing")
			This.hideItem($componentRef)
		: ($selectedAttribute.value.type="bool")
			This.hideItem($componentRef)
		: ($selectedAttribute.value.kind="relatedEntity")
			This.hideItem($componentRef)
		Else 
			This.showItem($componentRef)
	End case 
	
exposed Function getManifestObject() : Object
	var $manifestFile : 4D.File
	var $manifestObject : Object
	
	$manifestFile:=File("/PACKAGE/Project/Sources/Shared/manifest.json")
	$manifestObject:=JSON Parse($manifestFile.getText())
	
	return $manifestObject
	
	
exposed Function returnValue($value : Variant) : Variant
	return $value
	
exposed Function getOpeningWebForm() : Text
	If (ds.dataGenerator.query("settingKey == :1"; "OpenAI_APIKey").length=0)
		return "setup"
	Else 
		return "generateData"
	End if 