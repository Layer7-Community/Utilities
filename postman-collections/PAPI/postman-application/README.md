# postman-aspplication-request
postman-application-request

## Purpose
This postman collection is an example for Application operations.

## Content
This collection include requests required to:
- Create Application
- Edit Application
- List and View all Applications with filter
- View a specific Application
- Delete an Application

## Requirements
To work with this collection, setup tenant ID, portal Url and Portal-Admin's Username/Password in the collection variable.

Please be advised that API Group and API-Plan cannot be use to together (specifically, if there is one API Group attached to an application, the API-Plan cannot be enable)

If You want to run this Collection as an example via Postman Collection Runner, you need to 

- Confirm there is no API Group attached to any application and disable API Group part in the collection (or the API-Plan part will not work, vice-versa)
- Confirm there is no Application Custom Field already exist (as a work-around, you can modify the request for create application, adding your custom field and it's value)

