# ResponseToFile-Postman

This project creates a local server which will help in writing the GatewayBundle downloaded files from Postman to file system.

This project is using a powerful feature built in postman called as `pm.sendRequest`, the docs for which can be found here: https://learning.postman.com/docs/postman/scripts/postman-sandbox-api-reference/#pmsendrequest

## Requirements
To work with this script, the latest Node.js is required.

## Steps To Use
1. Copy or Clone the repository to your machine a local folder.

2. Navigate into the directory and install the dependencies. Use the following command: `npm i`; 

3. Run the local server. Use the following command: `node script.js "<Postman Working Folder>"` Note: find the Postman Working Folder in Postman Settings.

4. Now, the responses for every request which is a part of this collection will be written to the Postman Working Folder.


## Additionally
The example of sending the request can be found in https://www.postman.com/postman/workspace/postman-answers/collection/3407886-888860dd-9e3c-4537-a78e-1c3f3db7535c?ctx=documentation, the script is under Test tab, you can copy the script from the `Tests` tab of this collection to the `Tests` tab of any request or even a specific folder.

**Note:** To access the `Tests` script of this collection:
1. You need to `Right Click` the `Write Responses To File` collection in the sidebar.
2. Click on `Edit`
3. Go to `Tests` tab.

Then you can send that particular request / requests under a folder for which the data needs to be written.

## File Extensions
You can also modify the **extension** of the file.

**Example:**
In case you want to write CSV data to a file, all you need to do is change the `fileExtension` property in the `Tests` script to `csv`.


## File Support
You can modify the `opts` variable as per your need under the `Tests` tab of the collection, the following features are supported:

1. If you want all the data to be written to a single file then you can modify the value of mode to appendFile instead of writeFile (More functions here: [Node FS](https://nodejs.org/api/fs.html#fs_fs_writefile_file_data_options_callback))

2. If you want each response to be stored in a different file, then you can provide a `uniqueIdentifier` such as `Date.now()` or some environment variable as a counter, and it'll be used generate unique file names. You can also make the value of uniqueIdentifier as `true` and the server will internally append a unique number to every file name.

3. You can provide options to the FS lib, e.g. `options: { encoding: 'base64' }`.
