const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Load centralized config (config.json), fall back to built-in defaults if not present
function loadConfig() {
  try {
    return require(path.join(__dirname, 'config.json'));
  } catch (e) {
    return {};
  }
}
const config = loadConfig();

// Parse command-line arguments
// Usage: node ImportBundles.js [GRAPHMAN_HOME] [--gateway GATEWAY] [--schema <schema>]
// Example: node ImportBundles.js ../../graphman-client-main --gateway aws --schema v11.2.1
// Example: node ImportBundles.js --gateway target --schema v11.2.1
// Example: node ImportBundles.js /path/to/graphman-client-main
// Defaults are loaded from config.json (targetGateway, graphmanHome, importSchema)

let graphmanHome = config.graphmanHome || path.join(__dirname, '..', '..', 'graphman-client-main');
let gateway = config.targetGateway || 'aws';
let schema = config.importSchema || 'v11.1.3';

// Parse arguments (CLI args override config.json values)
let i = 2;
while (i < process.argv.length) {
  if (process.argv[i] === '--gateway' && process.argv[i + 1]) {
    gateway = process.argv[i + 1];
    i += 2;
  } else if (process.argv[i] === '--schema' && process.argv[i + 1]) {
    schema = process.argv[i + 1];
    i += 2;
  } else if (process.argv[i] && !process.argv[i].startsWith('--')) {
    // First non-flag argument is GRAPHMAN_HOME
    graphmanHome = process.argv[i];
    i++;
  } else {
    i++;
  }
}

// Configuration
const generatedDir = path.join(__dirname, 'generated');
const graphmanExe = process.platform === 'win32' ? 'graphman.bat' : 'graphman.sh';
const graphmanPath = path.join(graphmanHome, graphmanExe);

// Check if generated directory exists
if (!fs.existsSync(generatedDir)) {
  console.error(`Error: Generated directory not found: ${generatedDir}`);
  console.error(`Please run ExportBundles.js first to generate bundle files.`);
  process.exit(1);
}

// Import a single bundle file using graphman
function importBundle(filePath, fileName) {
  // Use absolute path for input
  const absoluteFilePath = path.resolve(filePath);

  // Graphman import command
  const command = `${graphmanPath} import --gateway ${gateway} --input "${absoluteFilePath}" --options.schema ${schema}`;

  try {
    console.log(`Importing bundle: ${fileName}...`);
    console.log(`  Input: ${absoluteFilePath}`);
    console.log(`  Command: ${command}`);
    
    let result = '';
    let errorOutput = '';
    
    try {
      result = execSync(command, { 
        stdio: 'pipe',
        cwd: __dirname,
        env: { ...process.env, GRAPHMAN_HOME: graphmanHome },
        encoding: 'utf8'
      });
    } catch (execError) {
      // Capture both stdout and stderr from the error
      if (execError.stdout) {
        result = execError.stdout.toString();
      }
      if (execError.stderr) {
        errorOutput = execError.stderr.toString();
      }
      // Re-throw to handle as failure
      throw execError;
    }
    
    // Show graphman output if any
    if (result && result.trim()) {
      console.log(`  Graphman output:\n${result.trim()}`);
    }
    if (errorOutput && errorOutput.trim()) {
      console.error(`  Graphman error:\n${errorOutput.trim()}`);
    }
    
    console.log(`✓ Successfully imported: ${fileName}\n`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to import ${fileName}: ${error.message}`);
    if (error.stdout) {
      console.error(`  stdout: ${error.stdout.toString()}`);
    }
    if (error.stderr) {
      console.error(`  stderr: ${error.stderr.toString()}`);
    }
    console.error('');
    return false;
  }
}

// Process all JSON files in generated directory
function processBundleFiles() {
  // Find all .json files, excluding backup files
  const files = fs.readdirSync(generatedDir)
    .filter(file => {
      // Include only .json files
      if (!file.endsWith('.json')) {
        return false;
      }
      // Exclude backup files (files with .backup. in the name)
      if (file.includes('.backup.')) {
        return false;
      }
      return true;
    });

  if (files.length === 0) {
    console.log('No bundle files found in generated/ directory');
    console.log('Please run ExportBundles.js first to generate bundle files.');
    return;
  }

  console.log(`Found ${files.length} bundle file(s) to import\n`);

  // Import each file
  let successCount = 0;
  let failCount = 0;

  files.forEach(file => {
    const filePath = path.join(generatedDir, file);
    const success = importBundle(filePath, file);
    if (success) {
      successCount++;
    } else {
      failCount++;
    }
  });

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('Import Summary:');
  console.log(`  Total files: ${files.length}`);
  console.log(`  Successful: ${successCount}`);
  console.log(`  Failed: ${failCount}`);
  console.log(`  Input directory: ${generatedDir}`);
  console.log('='.repeat(50));
}

// Main execution
try {
  // Validate graphman path
  if (!fs.existsSync(graphmanPath)) {
    console.error(`Error: Graphman script not found at: ${graphmanPath}`);
    console.error(`Please provide the correct GRAPHMAN_HOME path as the first argument.`);
    console.error(`Usage: node ImportBundles.js [GRAPHMAN_HOME] [--gateway <gateway>]`);
    console.error(`Example: node ImportBundles.js ../../graphman-client-main --gateway aws`);
    process.exit(1);
  }

  console.log('Starting bundle import process...');
  console.log(`  GRAPHMAN_HOME: ${graphmanHome}`);
  console.log(`  Gateway: ${gateway}`);
  console.log(`  Schema: ${schema}`);
  console.log(`  Graphman path: ${graphmanPath}\n`);
  
  processBundleFiles();
} catch (error) {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
}
