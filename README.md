About Luna
==========

Luna is a Xojo-based framework that can be used to create RESTful APIs for 
MySQL and Amazon Aurora databases.

With Luna, Xojo developers can quickly and easily implement feature-rich, 
professional, secure, and scalable REST APIs.

Luna's features include:
- Support for RESTful URLs and actions.
- Sensible HTTP status codes are returned.
- Easily require HTTPS connections.
- Error responses include help JSON-encoded information.
- Versioning is supported via URLs.
- Supports user-specified limiting of the columns that are returned.
- Requests to update or create records return resource representations.
- All responses are JSON-encoded.
- POST, PUT and PATCH bodies are JSON-encoded.
- Easy implementation of your preferred authentication method.

Learn more: http://timdietrich.me/luna/


## Setup / Configuration

Specify your database connection information via the App's properties. There are properties for the database host address (DatabaseHost), the name of the database (DatabaseName), as well as the account name (DatabaseUserName) and password (DatabasePassword) that you would like Luna to use to access the database.

Additionally, you can require that connections to the API be secure by setting the SecureConnectionsRequired property to True.

Implement your API's authentication scheme via the app's RequestAuthenticate method. A very simple example of an authentication scheme is provided in the Xojo project.

For each endpoint that you wish to support, create a corresponding app method. Name the methods according to the entities and actions that you wish to support, as well as the version of the API that the method is intended for. For example, a method to support the creation of a new contact would be named ContactsPostV1. Sample methods have been included in the Xojo project. They demonstrate how you might implement endpoints for GET, POST, PUT, PATCH, and DELETE actions.


## Sample Data

I've provided a SQL script that you might want to use to load up a MySQL table for testing Luna. The script creates a Contacts table and loads it with 500 sample (fake) contact records.

I've also provided a Paw file that you can use to make API calls. Paw is a REST client for the Mac. For details, visit: https://luckymarmot.com/paw


## Developed By

Tim Dietrich: http://timdietrich.me/



## Special Thanks

Paul Lefebvre of Xojo, Inc.: http://xojo.com

Hal Gumbert of Camp Software: http://campsoftware.com

Vinay Sahni: http://www.vinaysahni.com


