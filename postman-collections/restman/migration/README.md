# Gateway_Postman_Collection

There are two collections sets, 

  One is environmentCollection where we can configure Source/Destination host and port details. And Policy Manager login credentials.
  
  Second one is entityCollection where we can execute entity migration.
  
  
End user have to import both the collections in postman.

 
Environment variables looks like this, Need to provide Source/Destination host and port details and login credentials as well.
 
 ![image](https://github.gwd.broadcom.net/storage/user/545/files/7b75fadc-6e57-40d1-9854-c6656f0cd25f)
 
 

Entities collection looks like this, Individually can run each collection. For Trusted certificates, Stored Passwords, JMS destinations, JDBC connection migrations,
We can run single entity migration or All entities migrations at once. In Run collection window we need to select which one we should run.

![image](https://github.gwd.broadcom.net/storage/user/545/files/e294a316-5361-427a-bb6f-0d54a85e2d89)



Documentation

Each collection have pretty much documented seperately. We just need click on Documentation in postman to view as below,

![image](https://github.gwd.broadcom.net/storage/user/545/files/4f72725d-ca89-459e-a7ec-5533271889f3)


