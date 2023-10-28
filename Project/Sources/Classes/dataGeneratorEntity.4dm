Class extends Entity

exposed Function get settingValueHid() : Text
	If (This.hidden)
		return "*****"
	Else 
		return This.settingValue
	End if 
	
exposed Function saveWithValue($value : Text)
	If ($value="*****")
		Web Form.setWarning("Please enter a valid value")
	Else 
		This.settingValue:=$value
		This.save()
		Web Form.setMessage("Setting "+This.settingKey+" saved successfully")
	End if 