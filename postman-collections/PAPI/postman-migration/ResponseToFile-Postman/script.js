const express = require('express'),
  app = express(),
  fs = require('fs'),
  shell = require('shelljs');

   // The folder path in which responses need to be stored, 
   // The folder path is presented at argument, if not, use './Responses/' as default 
  const myArgs = process.argv.slice(2);
  if( myArgs[0]) {
    folderPath = myArgs[0];
  }else{
    folderPath = './Responses/';
  }
  defaultFileExtension = 'json'; // Change the default file extension
  bodyParser = require('body-parser'),
  DEFAULT_MODE = 'writeFile',
  path = require('path');

// Create the folder path in case it doesn't exist
shell.mkdir('-p', folderPath);

 // Change the limits according to your response size
app.use(bodyParser.json({limit: '50mb', extended: true}));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true })); 

app.get('/', (req, res) => res.send('Hello, I write data to file. Send them requests!'));

app.post('/write', (req, res) => {
  let extension = req.body.fileExtension || defaultFileExtension,
    fsMode = req.body.mode || DEFAULT_MODE,
    uniqueIdentifier = req.body.uniqueIdentifier ? typeof req.body.uniqueIdentifier === 'boolean' ? Date.now() : req.body.uniqueIdentifier : false,
    filename = `${req.body.requestName}${uniqueIdentifier || ''}`,
    filePath = `${path.join(folderPath, filename)}.${extension}`,
    options = req.body.options || undefined;

  fs[fsMode](filePath, req.body.responseData, options, (err) => {
    if (err) {
      console.log(err);
      res.send('Error');
    }
    else {
      res.send('Success');
    }
  });
});

app.listen(3000, () => {
  console.log('ResponsesToFile App is listening now! Send them requests my way!');
  console.log(`Data is being stored at location: ${path.resolve(process.cwd(), folderPath)}`);
});
