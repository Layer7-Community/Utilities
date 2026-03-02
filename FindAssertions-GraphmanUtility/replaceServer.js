const http = require('http');
const url = require('url');
const path = require('path');
const { execSync } = require('child_process');

const PORT = 3001; // Different port from the previous server to avoid conflicts

/**
 * Handle import bundles request
 */
async function handleImportBundles(req, res) {
  let body = '';

  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    try {
      const params = JSON.parse(body);
      const { graphmanHome, gateway } = params;

      // Use defaults if not provided
      const graphmanHomePath = graphmanHome || path.join(path.dirname(require.main ? require.main.filename : process.cwd()), '..', '..', 'graphman-client-main');
      const gatewayName = gateway || 'aws';

      console.log(`\n[${new Date().toISOString()}] Import request received:`);
      console.log(`  GRAPHMAN_HOME: ${graphmanHomePath}`);
      console.log(`  Gateway: ${gatewayName}`);

      // Get the directory where this script is located
      const scriptDir = path.dirname(require.main ? require.main.filename : process.cwd());
      
      // Construct the command to run ImportBundles.js
      const importScriptPath = path.join(scriptDir, 'ImportBundles.js');
      const command = `node "${importScriptPath}" "${graphmanHomePath}" --gateway ${gatewayName}`;

      try {
        // Execute the ImportBundles.js script
        const output = execSync(command, {
          cwd: scriptDir,
          encoding: 'utf8',
          stdio: 'pipe',
          env: { ...process.env, GRAPHMAN_HOME: graphmanHomePath }
        });

        res.writeHead(200, { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: true,
          message: 'Import operation completed successfully',
          output: output
        }));

      } catch (execError) {
        // Capture the error output
        const errorOutput = execError.stdout || execError.stderr || execError.message;
        
        res.writeHead(500, { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: false,
          error: 'Import operation failed',
          output: errorOutput.toString()
        }));
      }

    } catch (error) {
      console.error('Error handling import request:', error);
      res.writeHead(500, { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      res.end(JSON.stringify({
        success: false,
        error: error.message
      }));
    }
  });
}

/**
 * Handle replace and import request
 */
async function handleReplaceAndImport(req, res) {
  let body = '';

  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    try {
      const params = JSON.parse(body);
      const { resultsFile, searchAssertion, replaceAssertion } = params;

      if (!resultsFile || !searchAssertion || !replaceAssertion) {
        res.writeHead(400, { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: false,
          error: 'Missing required parameters: resultsFile, searchAssertion, and replaceAssertion are required'
        }));
        return;
      }

      console.log(`\n[${new Date().toISOString()}] Replace request received:`);
      console.log(`  Results File: ${resultsFile}`);
      console.log(`  Search: ${searchAssertion}`);
      console.log(`  Replace: ${replaceAssertion}`);

      // Get the directory where this script is located
      const scriptDir = path.dirname(require.main ? require.main.filename : process.cwd());
      
      // Convert relative results file path to absolute path
      let absoluteResultsFile = resultsFile;
      if (!path.isAbsolute(resultsFile)) {
        // If it starts with ../response/, resolve it relative to script directory
        if (resultsFile.startsWith('../response/')) {
          absoluteResultsFile = path.join(scriptDir, 'response', path.basename(resultsFile));
        } else if (resultsFile.startsWith('response/')) {
          absoluteResultsFile = path.join(scriptDir, 'response', path.basename(resultsFile));
        } else {
          absoluteResultsFile = path.join(scriptDir, resultsFile);
        }
      }
      
      // Construct the command to run ReplaceAssertions.js
      const replaceScriptPath = path.join(scriptDir, 'ReplaceAssertions.js');
      const command = `node "${replaceScriptPath}" "${absoluteResultsFile}" "${searchAssertion}" "${replaceAssertion}"`;

      try {
        // Execute the ReplaceAssertions.js script
        const output = execSync(command, {
          cwd: scriptDir,
          encoding: 'utf8',
          stdio: 'pipe'
        });

        res.writeHead(200, { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: true,
          message: 'Replace operation completed successfully',
          output: output
        }));

      } catch (execError) {
        // Capture the error output
        const errorOutput = execError.stdout || execError.stderr || execError.message;
        
        res.writeHead(500, { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });
        res.end(JSON.stringify({
          success: false,
          error: 'Replace operation failed',
          output: errorOutput.toString()
        }));
      }

    } catch (error) {
      console.error('Error handling replace request:', error);
      res.writeHead(500, { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      res.end(JSON.stringify({
        success: false,
        error: error.message
      }));
    }
  });
}

/**
 * Create HTTP server
 */
const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end();
    return;
  }

  // Handle health check endpoint
  if (req.method === 'GET' && pathname === '/api/health') {
    res.writeHead(200, { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({ status: 'ok', message: 'Replace server is running' }));
    return;
  }

  // Handle replace endpoint
  if (req.method === 'POST' && pathname === '/api/replace-and-import') {
    handleReplaceAndImport(req, res);
    return;
  }

  // Handle import bundles endpoint
  if (req.method === 'POST' && pathname === '/api/import-bundles') {
    handleImportBundles(req, res);
    return;
  }

  // 404 for other requests
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n✓ Replace server running at http://localhost:${PORT}/`);
  console.log(`  API endpoints:`);
  console.log(`    - http://localhost:${PORT}/api/replace-and-import`);
  console.log(`    - http://localhost:${PORT}/api/import-bundles`);
  console.log(`  Listening on all network interfaces (0.0.0.0:${PORT})`);
  console.log(`\n  Press Ctrl+C to stop the server\n`);
});

// Handle server errors
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n✗ Error: Port ${PORT} is already in use.`);
    console.error(`  Please stop the other server or use a different port.\n`);
  } else {
    console.error(`\n✗ Server error: ${err.message}\n`);
  }
  process.exit(1);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\nShutting down replace server...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
