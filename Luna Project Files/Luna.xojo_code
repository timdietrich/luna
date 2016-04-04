#tag Class
Protected Class Luna
	#tag Method, Flags = &h0
		Function AppMethodGet(App As WebApplication, Request As WebRequest) As Introspection.MethodInfo
		  // Get the version of the API that has been referenced.
		  Dim apiVersion As String = Replace(RequestPathComponents(0), "_", "")
		  
		  
		  // Get the name of the entity being referenced, and remove any underscores.
		  Dim entityName As String = Replace(RequestPathComponents(1), "_", "")
		  
		  
		  // Get the name of the method that should handle the endpoint.
		  // e.g. DepartmentsGetV1
		  Dim methodName As String = entityName + Request.Method + apiVersion
		  
		  
		  // Get an array of the App's methods.
		  Dim methods() As Introspection.MethodInfo = Introspection.GetType(App).GetMethods
		  
		  
		  // Loop through the array of methods...
		  For i As Integer = Ubound(methods) DownTo 0
		    
		    // If this is the method that should be used to process the request...
		    If methods(i).name = methodName Then
		      
		      // Return the method.
		      Return methods(i)
		      
		    End If
		    
		  Next
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(Request As WebRequest, SecureConnectionsRequired As Boolean, DatabaseHost As String, DatabaseUserName As String, DatabasePassword As String, DatabaseName As String, Optional DatabaseSchema As String)
		  // If this isn't a request for the root...
		  If Request.Path = "" Then
		    // Display the Luna launch page.
		    LaunchPageCreate(Request)
		    Return
		  End If
		  
		  
		  // All response bodies will be JSON-encoded.
		  Request.Header("Content-Type") = "application/json"
		  
		  
		  // Set the Server header.
		  Request.Header("Server") = "Luna/" + LunaVersion
		  
		  
		  // Assume that no errors will be encountered during the construction of the object.
		  Request.Status = 200
		  
		  
		  // If secure connections are required, and this connection isn't being made securely...
		  If SecureConnectionsRequired and not Request.Secure Then
		    Request.Status = 403.4
		    Request.Print( ErrorResponseCreate ( "403.4", "Forbidden: SSL is required to view this resource.", "Use: https://" + Request.RemoteAddress + "/" + Request.Path) )
		    Return
		  End If
		  
		  // Create and configure a database connection object.
		  #if UseMySQL and UsePostgreSQL
		    #pragma Error "You need to set only one of the constants (UseMySQL or UsePostgreSQL) to True to be able to work"
		  #elseif UseMySQL
		    DatabaseConnection = New MySQLCommunityServer
		    DatabaseConnection.Host = DatabaseHost
		    DatabaseConnection.UserName = DatabaseUserName
		    DatabaseConnection.Password = DatabasePassword
		    DatabaseConnection.DatabaseName = DatabaseName
		  #elseif UsePostgreSQL
		    pgDatabaseConnection = New PostgreSQLDatabase
		    pgDatabaseConnection.Host = DatabaseHost
		    pgDatabaseConnection.UserName = DatabaseUserName
		    pgDatabaseConnection.Password = DatabasePassword
		    pgDatabaseConnection.DatabaseName = DatabaseName
		  #Else
		    #pragma Error "You need to set one of the constants (UseMySQL or UsePostgreSQL) to True to be able to work"
		  #endif
		  
		  // If we cannot connect to the database...
		  #if UseMySQL
		    If not DatabaseConnection.Connect Then
		      Request.Status = 500
		      Request.Print( ErrorResponseCreate ( "500", "Unable to connect to the database.", "Database error code: " + DatabaseConnection.ErrorCode.ToText) )
		      Return
		    End If
		  #elseif UsePostgreSQL
		    If not pgDatabaseConnection.Connect Then
		      Request.Status = 500
		      Request.Print( ErrorResponseCreate ( "500", "Unable to connect to the database.", "Database error code: " + pgDatabaseConnection.ErrorCode.ToText) )
		      Return
		    End If
		  #endif
		  
		  #if UsePostgreSQL
		    if DatabaseSchema<>"" Then
		      pgDatabaseConnection.SQLExecute("SET SEARCH_PATH=" + DatabaseSchema + ";")
		    end if
		  #endif
		  
		  // Get the JSON-encoded version of the request body.
		  RequestJSON = New JSONItem(Request.Entity)
		  
		  
		  // Create a GET dictionary based on the query string.
		  // This is similar to PHP's $_GET variable scope, and provided for convenience.
		  GET = StringToDictionary(Request.QueryString)
		  
		  
		  // Create an array based on the request path's components.
		  // For example:
		  // A request for... 
		  // /v1/Contacts/47B9FACA-4CAB-41B9-AF21-9ED4E4DD8372/
		  // Would result in an array with these elements...
		  // [0] = v1, [1] = Contacts, [2] = 47B9FACA-4CAB-41B9-AF21-9ED4E4DD8372
		  RequestPathComponents = split(Request.Path, "/")
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function ErrorResponseCreate(Code As String, Message As String, Description As String) As String
		  Dim Response As New JSONItem
		  
		  Response.Value("Code") = Code
		  Response.Value("Message") = Message
		  Response.Value("Description") = Description
		  
		  Return Response.ToString
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub LaunchPageCreate(Request As WebRequest)
		  Dim HTML As String = "<html>" _
		  + "<head><title>Luna</title></head>" _
		  + "<body style=""background-color: #eeeeee;"">" _
		  + "<div style=""margin: 0 auto; margin-top: 24px; background-color: #ffffff; padding: 24px; width: 400px; border: 1px #ccc solid; border-radius: 12px; box-shadow: 10px 10px 5px #cccccc; "">" _
		  + "<p style=""text-align: center;"">" _
		  + "<img src=""http://timdietrich.me/luna/images/luna_logo_03.jpg"" style=""max-width: 300px; margin-bottom: 24px;""><br />" _
		  + "<!--<span style=""font-weight: bold; font-size: 120px; color: #32cd32; font-family: Helvetica;"">Luna</span><br />-->" _
		  + "<span style=""font-weight: normal; font-size: 14px; color: #8F8F8F margin-top: 0px; font-family: Helvetica;"">A RESTful API Server Framework for Xojo</span></p>" _
		  + "<p style=""text-align: center; font-family: Helvetica; font-size: 12px; color: #cccccc;"">Version " + LunaVersion + "</p>" _
		  + "</div>" _ 
		  + "</body>" _
		  + "</html>"
		  
		  Request.Status = 200
		  Request.Print (HTML)
		  
		  Return
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function RequestAuthenticate(Authorization As String) As Boolean
		  // If the Authorization has not been specified correctly...
		  If InStr(0, Authorization, "Bearer ") <> 1 Then
		    Return False
		  End if
		  
		  // Remove the "Bearer" prefix from the value.
		  Authorization = Replace(Authorization, "Bearer ", "")
		  
		  // Implement your custom authentication here.
		  
		  Dim APIKey As String = "Xo28zHT7np3iVE3GzvTjmHtMEQaeo3ULdvuC7M9HHq4Fi9dHsB"
		  
		  If Authorization = APIKey Then
		    Return True
		  Else
		    Return False
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SQLColumnsPrepare() As String
		  // Enables the caller to specify a list of columns to be returned.
		  // The list is passed as a URL variable ("columns") with a list of columns names.
		  // e.g. columns=Department_ID,Department_Name
		  // If no column list is specified, then all columns are returned.
		  
		  If not GET.HasKey("columns") Then
		    
		    Return "*"
		    
		  Else
		    
		    Dim Columns As String = DecodeURLComponent(GET.Value("columns"))
		    
		    Return Columns
		    
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SQLDELETEProcess(Table As String, PKColumn As String) As Dictionary
		  
		  Dim sql As String
		  Dim Response As New Dictionary
		  
		  // Build the SELECT statement.
		  #if UseMySQL
		    sql = "SELECT " + PKColumn + " FROM " + Table + " WHERE " + PKColumn + " = ?"
		  #elseif UsePostgreSQL
		    sql = "SELECT " + Lowercase(PKColumn) + " FROM " + Lowercase(Table) + " WHERE " + Lowercase(PKColumn) + " = $1"
		  #endif
		  
		  // Create the prepared statement.
		  #if UseMySQL
		    SQLStatement = DatabaseConnection.Prepare(sql)
		  #elseif UsePostgreSQL
		    pgSQLStatement = pgDatabaseConnection.Prepare(sql)
		  #endif
		  
		  // Specify the binding types.
		  #if UseMySQL
		    SQLStatement.BindType(0, MySQLPreparedStatement.MYSQL_TYPE_STRING)
		  #endif
		  
		  // Bind the values.
		  #if UseMySQL
		    SQLStatement.Bind(0, RequestPathComponents(2))
		  #elseif UsePostgreSQL
		    pgSQLStatement.Bind(0, RequestPathComponents(2))
		  #endif
		  
		  // Send the request.
		  Dim data As RecordSet
		  #if UseMySQL
		    data = SQLStatement.SQLSelect
		  #elseif UsePostgreSQL
		    data = pgSQLStatement.SQLSelect
		  #endif
		  
		  // If an error was thrown...
		  Dim bError As Boolean=False
		  #if UseMySQL
		    bError=DatabaseConnection.Error
		  #elseif UsePostgreSQL
		    bError=pgDatabaseConnection.Error
		  #endif
		  If bError Then
		    
		    Response.Value("ResponseStatus") = 500
		    #if UseMySQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "SQL INSERT Failure", "Database error code: " + DatabaseConnection.ErrorCode.ToText)
		    #elseif UsePostgreSQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "SQL INSERT Failure", "Database error code: " + pgDatabaseConnection.ErrorCode.ToText)
		    #endif
		    Return Response
		    
		  End If
		  
		  // If there is no data to be returned...
		  If data.EOF Then
		    
		    Response.Value("ResponseStatus") = 404
		    Response.Value("ResponseBody") = ErrorResponseCreate ( "404", "SQL SELECT Failure", "No records were found that meet the filter criteria.")
		    Return Response
		    
		  End If
		  
		  // Build the DELETE statement.
		  #if UseMySQL
		    sql = "DELETE FROM " + Table + " WHERE " + PKColumn + " = ?"
		  #elseif UsePostgreSQL
		    sql = "DELETE FROM " + Lowercase(Table) + " WHERE " + Lowercase(PKColumn) + " = $1"
		  #endif
		  
		  // Create the prepared statement.
		  #if UseMySQL
		    SQLStatement = DatabaseConnection.Prepare(sql)
		  #elseif UsePostgreSQL
		    pgSQLStatement = pgDatabaseConnection.Prepare(sql)
		  #endif
		  
		  // Specify the binding types.
		  #if UseMySQL
		    SQLStatement.BindType(0, MySQLPreparedStatement.MYSQL_TYPE_STRING)
		  #endif
		  
		  // Bind the values.
		  #if UseMySQL
		    SQLStatement.Bind(0, RequestPathComponents(2))
		  #elseif UsePostgreSQL
		    pgSQLStatement.Bind(0, RequestPathComponents(2))
		  #endif
		  
		  // Execute the statement.
		  #if UseMySQL
		    SQLStatement.SQLExecute
		  #elseif UsePostgreSQL
		    pgSQLStatement.SQLExecute
		  #endif
		  
		  // If an error was thrown...
		  #if UseMySQL
		    bError=DatabaseConnection.Error
		  #elseif UsePostgreSQL
		    bError=pgDatabaseConnection.Error
		  #endif
		  If bError Then
		    Response.Value("ResponseStatus") = 500
		    #if UseMySQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "DELETE Request Failed", DatabaseConnection.ErrorMessage)
		    #elseif UsePostgreSQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "DELETE Request Failed", pgDatabaseConnection.ErrorMessage)
		    #endif
		    Return Response
		  End If
		  
		  // Build the SELECT statement.
		  #if UseMySQL
		    sql = "SELECT " + PKColumn + " FROM " + Table + " WHERE " + PKColumn + " = ?"
		  #elseif UsePostgreSQL
		    sql = "SELECT " + Lowercase(PKColumn) + " FROM " + Lowercase(Table) + " WHERE " + Lowercase(PKColumn) + " = $1"
		  #endif
		  
		  // Create the prepared statement.
		  #if UseMySQL
		    SQLStatement = DatabaseConnection.Prepare(sql)
		  #elseif UsePostgreSQL
		    pgSQLStatement = pgDatabaseConnection.Prepare(sql)
		  #endif
		  
		  // Specify the binding types.
		  #if UseMySQL
		    SQLStatement.BindType(0, MySQLPreparedStatement.MYSQL_TYPE_STRING)
		  #endif
		  
		  // Bind the values.
		  #if UseMySQL
		    SQLStatement.Bind(0, RequestPathComponents(1))
		  #elseif UsePostgreSQL
		    pgSQLStatement.Bind(0, RequestPathComponents(1))
		  #endif
		  
		  // Send the request.
		  #if UseMySQL
		    data = SQLStatement.SQLSelect
		  #elseif UsePostgreSQL
		    data = pgSQLStatement.SQLSelect
		  #endif
		  
		  // If there is no data to be returned...
		  If data.EOF Then
		    // DELETE was successful.
		    // Return "204 No Content."
		    // This indicates that "the server successfully processed the request, but is not returning any content."
		    Response.Value("ResponseStatus") = 204
		    Response.Value("ResponseBody") = ""
		    Return Response
		  Else
		    Response.Value("ResponseStatus") = 500
		    Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "DELETE Request Failed",  "")
		    Return Response
		  End If
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function SQLSELECTProcess() As Dictionary
		  Dim Response As New Dictionary
		  
		  // Records is a JSONItem.
		  Dim Records As New JSONItem
		  
		  // Send the request.
		  Dim data As RecordSet
		  #if UseMySQL
		    data = SQLStatement.SQLSelect
		  #elseif UsePostgreSQL
		    data = pgSQLStatement.SQLSelect
		  #endif
		  
		  // If an error was thrown...
		  Dim bError As Boolean=False
		  #if UseMySQL
		    bError=DatabaseConnection.Error
		  #elseif UsePostgreSQL
		    bError=pgDatabaseConnection.Error
		  #endif
		  If bError Then
		    
		    Response.Value("ResponseStatus") = 500
		    #if UseMySQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "SQL SELECT Failure", "Database error code: " + self.DatabaseConnection.ErrorCode.ToText)
		    #elseif UsePostgreSQL
		      Response.Value("ResponseBody") = ErrorResponseCreate ( "500", "SQL SELECT Failure", "Database error code: " + self.pgDatabaseConnection.ErrorCode.ToText)
		    #endif
		    Return Response
		    
		  End If
		  
		  // If there is data to be returned...
		  If Not data.EOF Then
		    
		    // Loop over each row...
		    While Not data.EOF
		      
		      // We'll treat each record as a dictionary.
		      Dim Record As New Dictionary
		      
		      // For each column...
		      For i As Integer = 0 To data.FieldCount-1
		        // Add the column name / value pair as a dictionary element.
		        Record.Value( data.IdxField(i+1).Name ) = data.IdxField(i+1).StringValue
		      Next
		      
		      // Add the record to the JSON object.
		      Records.Append(Record)
		      
		      // Go to the next row.
		      data.MoveNext
		      
		    Wend
		    
		    // Close the records.
		    data.Close
		    
		    // Return the "200" response with the data.
		    Response.Value("ResponseStatus") = 200
		    Response.Value("ResponseBody") = Records.ToString
		    Return Response
		    
		  Else
		    
		    Response.Value("ResponseStatus") = 404
		    Response.Value("ResponseBody") = ErrorResponseCreate ( "404", "SQL SELECT Failure", "No records were found that meet the filter criteria.")
		    Return Response
		    
		  End If
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function StringToDictionary(nameValues As String) As Dictionary
		  // Converts a string of name-value pairs into a dictionary.
		  // For example, Request.QueryString might look like: x=1&y=2&z=3
		  // This method will generate a dictionary, where x = 1, y = 2, and z = 3.
		  
		  // Create an array of name-value pairs.
		  Dim StringsArray() As String = Split ( nameValues, "&" )
		  
		  // This is the dictionary that we'll load.
		  Dim StringsDict As New Dictionary
		  
		  // Loop over the array of name-value pairs...
		  For i As Integer = 0 To UBound(StringsArray)
		    
		    // Split the string into a name / value array.
		    Dim nv() As String = Split(StringsArray(i), "=")
		    
		    // Add the name / value pair to the dictionary.
		    StringsDict.Value(nv(0)) = nv(1)
		    
		  Next
		  
		  // Return the dictionary
		  Return StringsDict
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function UUIDGenerate() As String
		  // Source: https://forum.xojo.com/18856-getting-guid/0 ( Roberto C of Milan, Italy )
		  
		  Dim db As New SQLiteDatabase
		  
		  Dim Sql_instruction As String= "select hex( randomblob(4)) " _
		  + "|| '-' || hex( randomblob(2)) " _
		  + "|| '-' || '4' || substr( hex( randomblob(2)), 2) " _
		  + "|| '-' || substr('AB89', 1 + (abs(random()) % 4) , 1) " _
		  + "|| substr(hex(randomblob(2)), 2) " _
		  + "|| '-' || hex(randomblob(6)) AS GUID"
		  
		  If db.Connect Then
		    Dim GUID As String = db.SQLSelect(Sql_instruction).Field("GUID")
		    db.Close
		    Return  GUID
		  End If
		End Function
	#tag EndMethod


	#tag Note, Name = License
		--------------------------------------------------------------------------------------------
		The MIT License (MIT)
		--------------------------------------------------------------------------------------------
		
		Copyright (c) 2016 Timothy Dietrich
		
		Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
		
		The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
		
		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
		
		https://www.tldrlegal.com/l/mit
	#tag EndNote

	#tag Note, Name = Read Me
		--------------------------------------------------------------------------------------------
		About Luna
		--------------------------------------------------------------------------------------------
		
		Luna is a Xojo-based framework that can be used to create RESTful APIs for 
		MySQL and Amazon Aurora databases.
		
		With Luna, Xojo developers can quickly and easily implement feature-rich, 
		professional, secure, and scalable REST APIs.
		
		Luna's features include:
		• Support for RESTful URLs and actions.
		• Sensible HTTP status codes are returned.
		• Easily require HTTPS connections.
		• Error responses include help JSON-encoded information.
		• Versioning is supported via URLs.
		• Supports user-specified limiting of the columns that are returned.
		• Requests to update or create records return resource representations.
		• All responses are JSON-encoded.
		• POST, PUT and PATCH bodies are JSON-encoded.
		• Easy implementation of your preferred authentication method.
		
		Learn more: http://timdietrich.me/luna/
		
		
		--------------------------------------------------------------------------------------------
		Developed By
		--------------------------------------------------------------------------------------------
		
		Tim Dietrich: http://timdietrich.me/
		
		
		--------------------------------------------------------------------------------------------
		Special Thanks
		--------------------------------------------------------------------------------------------
		
		Paul Lefebvre of Xojo, Inc.: http://xojo.com
		
		Hal Gumbert of Camp Software: http://campsoftware.com
		
		Vinay Sahni: http://www.vinaysahni.com
		
		
		
	#tag EndNote

	#tag Note, Name = Response Codes
		--------------------------------------------------------------------------------------------
		HTTP Response Codes
		--------------------------------------------------------------------------------------------
		
		200 OK: Successful response for GET, PUT, and PATCH requests.
		
		201 Created: Successful response for POST requests.
		
		204 No Content: Successful response for DELETE requests.
		
		400 Bad Request: Failure response to a request with a malformed body.
		
		401 Unauthorized: Failure response for missing or invalid authentication credentials.
		
		403 Forbidden: Failure response to an unauthorized request. The client does not have permission to perform the action.
		
		403.4 Forbidden: Failure response because SSL is required.
		
		404 Not Found: Failure response because the requested resource is invalid.
		
		
		
		
	#tag EndNote

	#tag Note, Name = UsePostgreSQL
		To use PostgreSQL instead of MySQL:
		- set UseMySQL to False
		- set UsePostgreSQL to True
		- if you use a databaseschema in PostgreSQL set the value of DatabaseSchema
		
		You can then connect to a PostgreSQL database with Luna.
		
		When programming for PostgreSQL take the following differences compared to MySQL into account:
		
		1. PostgreSQL also has database schemas which are not synonymous to databases like they are in MySQL. 
		   The schemas in PostgreSQL are collections within a database (containing tables, data types, functions, operators...). 
		   That's the reason I added the optional Databaseschema to the Luna constructor. I made it optional because MySQL does not need it, 
		   since in MySQL a schema is a database and that is already a parameter. 
		   In PostgreSQL if no schema name is specified, the schema public will be used. This schema is made by default by PostgreSQL.
		
		2. PostgreSQL prepared statements use $ followed by a number for its parameters instead of ? (so for instance $2 is parameter 2)
		
		3. In PostgreSQL you don't need to bind the columns to a type
		
		4. The fieldnames are not capitalised after executing the creation script, which meant that since PostgreSQL is case-dependent 
		   Luna couldn't find the fieldnames (for instance City isn't found because the script created city) 
		   (to avoid confusion, I made a new creation script for PostgreSQL that only uses lower case fields, that way it's less confusing, 
		   since the original script even if it contained City would create city in PostgreSQL)
		
		5. Postgresql has its own prepared statement in Xojo, so Luna uses pgSQLStatement instead of SQLStatement when using PostgreSQL.
		
		6. Postgresql is not a MySQLCommunityServer so Luna uses pgDatabaseConnection instead of DatabaseConnection when using PostgreSQL.
		
		
	#tag EndNote


	#tag Property, Flags = &h0
		DatabaseConnection As MySQLCommunityServer
	#tag EndProperty

	#tag Property, Flags = &h0
		GET As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0
		LunaVersion As String = "2016.02.19"
	#tag EndProperty

	#tag Property, Flags = &h0
		pgDatabaseConnection As PostgreSQLDatabase
	#tag EndProperty

	#tag Property, Flags = &h0
		pgSQLStatement As PostgreSQLPreparedStatement
	#tag EndProperty

	#tag Property, Flags = &h0
		RequestJSON As JSONItem
	#tag EndProperty

	#tag Property, Flags = &h0
		#tag Note
			split(Request.Path, "/")
		#tag EndNote
		RequestPathComponents() As String
	#tag EndProperty

	#tag Property, Flags = &h0
		SQLStatement As PreparedSQLStatement
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LunaVersion"
			Group="Behavior"
			InitialValue="2016.02.08"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
