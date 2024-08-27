Class extends DataClass

exposed Function addEmptyAPIKey()
	var $entity : cs.dataGeneratorEntity
	
	If (This.query("settingKey == :1"; "OpenAI_APIKey").length=0)
		$entity:=This.new()
		$entity.settingKey:="OpenAI_APIKey"
		$entity.settingValue:=""
		$entity.hidden:=True
		$entity.save()
	End if 
	
	
Function getSetting($settingKey : Text) : Text
	var $setting : cs.dataGeneratorEntity
	
	$setting:=This.query("settingKey == :1"; $settingKey).first()
	Case of 
		: ($setting=Null) || ($setting.settingValue="")
			throw(1; $settingKey+" not set, please set it in settings screen")
			return ""
		Else 
			return $setting.settingValue
	End case 
	
	
exposed Function dropData($dataclassName : Text)
	ds[$dataclassName].all().drop()
	Web Form.setMessage(" Data dropped")
	
	
exposed Function listDatatables() : Collection
	var $dataclasses : Collection
	var $entry : Object
	var $index : Integer
	
	$dataclasses:=OB Entries(ds)
	$index:=$dataclasses.findIndex(Formula($1.value.key=$2); This.getInfo().name)
	$dataclasses.remove($index)
	//FIXME: it is necessary to remove ds object ("value") otherwise nothing is returned
	For each ($entry; $dataclasses)
		OB REMOVE($entry; "value")
		$entry.count:=ds[$entry.key].getCount()
	End for each 
	return $dataclasses
	
	
exposed Function getFirstAttribute($attributeList : Collection) : Object
	If (($attributeList=Null) || ($attributeList.length=0))
		return {}
	Else 
		return $attributeList.first()
	End if 
	
	
	
Function isRelationField($fieldName : Text; $tableName : Text) : Boolean
	var $numTable; $numField; $destTable; $destField : Integer
	
	$numTable:=ds[$tableName].getInfo().tableNumber
	$numField:=Num(ds[$tableName][$fieldName].fieldNumber)
	GET RELATION PROPERTIES($numTable; $numField; $destTable; $destField)
	return ($destTable#0)
	
	
	
	
exposed Function listDatatableAttributes($name : Text) : Collection
	var $attributes : Collection
	var $entry : Object
	var $dataClassPK : Text
	
	If (($name=Null) || ($name=""))
		return []
	End if 
	
	$attributes:=OB Entries(ds[$name])
	$dataClassPK:=ds[$name].getInfo().primaryKey
	
	For each ($entry; $attributes)
		$entry.value.AIremark:=""
		Case of 
			: (($entry.value.kind="relatedEntities") || ($entry.value.kind="calculated"))
				$entry.value.whatToDo:="nothing"
			: ($entry.value.name=$dataClassPK)
				$entry.value.whatToDo:="nothing"
				$entry.value.PK:=True
				$entry.value.name+=" (PK)"
			: (($entry.value.type="blob") || ($entry.value.type="image") || ($entry.value.type="object"))
				$entry.value.whatToDo:="nothing"
			: (This.isRelationField($entry.value.name; $name))
				$entry.value.whatToDo:="nothing"
			: ($entry.value.kind="relatedEntity")
				$entry.value.whatToDo:="get entity"
			: ($entry.value.type="bool")
				$entry.value.whatToDo:="random"
			Else 
				$entry.value.whatToDo:="openAI"
				$entry.value.AIrequestset:=10
		End case 
	End for each 
	
	return $attributes
	
exposed Function updateAttributes($attributeList : Collection; $updatedEntry : Object) : Collection
	var $entry : Object
	
	For each ($entry; $attributeList)
		If ($entry.key=$updatedEntry.key)
			$entry.value.AIremark:=$updatedEntry.value.AIremark
			$entry.value.AIrequestset:=$updatedEntry.value.AIrequestset
			$entry.value.whatToDo:=$updatedEntry.value.whatToDo
		End if 
	End for each 
	
	return $attributeList
	
exposed Function previewAIdata($attribute : Object) : Text
	var $aiGenerator : cs.openAIgetdata
	var $iterator : Integer
	var $retString : Text
	var $apiKey : Text
	
	$apiKey:=This.getSetting("OpenAI_APIKey")
	If ($apiKey="")
		return "OpenAI API Key not set, go to settings to set it up"
	End if 
	
	$aiGenerator:=cs.openAIgetdata.new($apiKey; $attribute.value.name; $attribute.value.type; 5; $attribute.value.AIremark)
	For ($iterator; 1; 5)
		$retString+=$aiGenerator.getNextValue()+"\n"
		If ($aiGenerator.fetchStatusCode#200)
			return "Could not fetch OpenAI response. OpenAI error: "+$aiGenerator.fetchErrorMessage
		End if 
	End for 
	$retString+="openAI query duration: "+String($aiGenerator.lastFetchDuration)+" ms"
	return $retString
	
	
exposed Function getAttributesToGenerate($dataclassName : Text; $attributeList : Collection) : Collection
	var $attributesToGenerate : Collection
	var $targetPK : Text
	var $entry : Object
	var $apiKey : Text
	
	$apiKey:=This.getSetting("OpenAI_APIKey")
	If ($apiKey="")
		return []
	End if 
	
	$attributesToGenerate:=[]
	For each ($entry; $attributeList)
		If ($entry.value.whatToDo="nothing")
			continue
		End if 
		
		If ($entry.value.whatToDo="openAI")
			$entry.value.aiGenerator:=cs.openAIgetdata.new(This.getSetting("OpenAI_APIKey"); $entry.value.name; $entry.value.type; Num($entry.value.AIrequestset); $entry.value.AIremark)
		End if 
		
		If ($entry.value.whatToDo="get entity")
			$entry.value.selection:=ds[$entry.value.relatedDataClass].all()
			$entry.value.length:=$entry.value.selection.length
		End if 
		$attributesToGenerate.push($entry)
	End for each 
	
	return $attributesToGenerate
	
	
	
exposed Function generateData($dataclassName : Text; $recordQty : Integer; $attributeList : Collection) : Object
	var $attributesToGenerate : Collection
	var $attributeGenerators : Collection
	var $entry : Object
	var $iterator : Integer
	var $entity : 4D.Entity
	var $nextValue; $fetchError : Text
	var $failedFetch : Boolean
	
	$failedFetch:=False
	$fetchError:=""
	$attributesToGenerate:=This.getAttributesToGenerate($dataclassName; $attributeList)
	If ($attributesToGenerate.length>0)
		$iterator:=0
		For ($iterator; 1; $recordQty)
			$entity:=ds[$dataclassName].new()
			For each ($entry; $attributesToGenerate)
				Case of 
					: (($entry.value.whatToDo="empty") || ($entry.value.whatToDo="nothing"))
						continue
						
					: (($entry.value.whatToDo="get entity") && ($entry.value.length>0))
						$entity[$entry.value.name]:=$entry.value.selection[Random%$entry.value.length]
						
					: (($entry.value.whatToDo="random") && ($entry.value.kind="storage"))
						Case of 
							: ($entry.value.type="string")
								$entity[$entry.value.name]:=This.gRandomString()
							: (entry.value.type="number")
								$entity[$entry.value.name]:=This.gRandomInteger()
							: ($entry.value.type="bool")
								$entity[$entry.value.name]:=This.gRandomBool()
							: ($entry.value.type="date")
								$entity[$entry.value.name]:=This.gRandomDate()
							Else 
								continue
						End case 
						
					: ($entry.value.whatToDo="openAI")
						$nextValue:=$entry.value.aiGenerator.getNextValue()
						If ($entry.value.aiGenerator.fetchStatusCode#200)
							$failedFetch:=True
							$fetchError:=$entry.value.aiGenerator.fetchErrorMessage
							break
						End if 
						Case of 
							: ($entry.value.type="number")
								$entity[$entry.value.name]:=Num($nextValue)
							: ($entry.value.type="date")
								$entity[$entry.value.name]:=Date($nextValue+"T00:00:00")
							Else 
								$entity[$entry.value.name]:=$nextValue
						End case 
					Else 
						continue
				End case 
			End for each 
			If ($failedFetch)
				break
			Else 
				$entity.save()
			End if 
			
			
		End for 
	End if 
	If ($failedFetch)
		throw(1; "Could not fetch OpenAI response, check your API key")
	End if 
	
	
	
Function gRandomBool() : Boolean
	return Bool(Random%2)
	
Function gRandomInteger() : Integer
	return Random
	
Function gRandomString() : Text
	var $l; $i : Integer
	var $retStr : Text
	
	$l:=(Random%64)+1
	$retStr:="a"*l
	For ($i; 1; $l)
		//random%(122-33+1)+33
		$retStr[[i]]:=Char((Random%90)+33)
	End for 
	return $retStr
	
Function gRandomDate() : Date
	var $day; $month; $year; $maxDay : Integer
	var $dayS; $monthS; $yearS : Text
	
	//random%(2099-1980+1)+1980
	$year:=(Random%120)+1980
	$yearS:=String($year)
	
	//random%(12-1+1)+1
	$month:=Random%(12)+1
	$monthS:=(($month<10) ? "0" : "")+String($month)
	
	Case of 
		: ($month=2)
			$maxDay:=28
		: (($month=4) || ($month=6) || ($month=9) || ($month=11))
			$maxDay:=30
		Else 
			$maxDay:=31
	End case 
	
	//random%(maxDay-1+1)+1
	$day:=Random%($maxDay)+1
	$dayS:=(($day<10) ? "0" : "")+String($day)
	
	return Date($yearS+"-"+$monthS+"-"+$dayS+"T00:00:00")