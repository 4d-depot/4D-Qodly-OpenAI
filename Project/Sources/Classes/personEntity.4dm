Class extends Entity

exposed Function get fullname() : Text
	Case of 
		: (This.firstname="")
			return This.lastname
		: (This.lastname="")
			return This.firstname
		Else 
			return This.firstname+" "+This.lastname
	End case 