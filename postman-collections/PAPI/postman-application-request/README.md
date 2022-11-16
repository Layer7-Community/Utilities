# postman-user-application-request
postman-user-application-request

## Purpose
This postman collection include all requests needed to perform an Application request workflow demo

## Content
This collection include requests required to:
- Enable Create and Edit Application workflow
- Create Application and Application Request
- Create Application Detail Edit Request
- Create API and Application API Request
- Create API-Group and Application API-Group Request
- Create Custom Field and Application Custom Field Request
- Create Application API-Key Request
- Create Application API-Plan Request
- View All Requests with filter
- View and Review Specific Request
- Review and process every Request of same Application

## Requirements
To work with this collection, setup tenant ID, portal Url, Portal-Admin's and another Org-User's Username and Password in the collection variable.

Please be advised that API-Group and API-Plan cannot be use to together (specifically, if there is one API-Group attached to an application, the API-Plan cannot be enable)

If You want to run this Collection as a demo via Postman Collection Runner, you need to 

- Confirm there is no API-Group attached to any application (or the API-Plan part will not work)
- Confirm there is no Application Custom Field already exist (as a work-around, you can modify the request for create application, adding your custom field and it's value)

