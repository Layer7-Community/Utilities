const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Parse command-line arguments
// Usage: node ExportBundles.js [GRAPHMAN_HOME] [--gateway <gateway>]
// Example: node ExportBundles.js ../../graphman-client-main --gateway aws
// Example: node ExportBundles.js --gateway source
// Example: node ExportBundles.js /path/to/graphman-client-main

let graphmanHome = path.join(__dirname, '..', '..', 'graphman-client-main'); // default
let gateway = 'aws'; // default

// Parse arguments
let i = 2;
while (i < process.argv.length) {
  if (process.argv[i] === '--gateway' && process.argv[i + 1]) {
    gateway = process.argv[i + 1];
    i += 2; // Skip --gateway and its value
  } else if (process.argv[i] && !process.argv[i].startsWith('--')) {
    // First non-flag argument is GRAPHMAN_HOME
    graphmanHome = process.argv[i];
    i++;
  } else {
    i++;
  }
}

// Configuration
const resultsDir = path.join(__dirname, 'response');
const generatedDir = path.join(__dirname, 'generated');
const responseDir = path.join(__dirname, 'response');
const graphmanPath = path.join(graphmanHome, 'graphman.sh');

// Create generated directory if it doesn't exist
if (!fs.existsSync(generatedDir)) {
  fs.mkdirSync(generatedDir, { recursive: true });
}

// Read the original service data to get folderPath for each service
function loadServiceData() {
  const serviceDataFile = path.join(responseDir, 'spFolderSVCFull.json');
  
  if (!fs.existsSync(serviceDataFile)) {
    console.error(`Error: Service data file not found: ${serviceDataFile}`);
    return null;
  }

  try {
    const fileContent = fs.readFileSync(serviceDataFile, 'utf8');
    const data = JSON.parse(fileContent);
    return data;
  } catch (error) {
    console.error(`Error reading service data file: ${error.message}`);
    return null;
  }
}

// Get service info (folderPath and resolutionPath) by name
function getServiceInfo(serviceName, serviceData) {
  if (!serviceData || !serviceData.services) {
    return null;
  }

  const service = serviceData.services.find(s => s.name === serviceName);
  if (service) {
    return {
      folderPath: service.folderPath,
      resolutionPath: service.resolutionPath
    };
  }
  return null;
}

// Sanitize filename (remove invalid characters)
function sanitizeFileName(name) {
  return name.replace(/[^a-zA-Z0-9-_]/g, '_');
}

// Export a single service using graphman
function exportService(serviceName, resolutionPath) {
  if (!resolutionPath) {
    console.log(`⚠ Skipping ${serviceName}: No resolutionPath found`);
    return false;
  }

  const outputFileName = `${sanitizeFileName(serviceName)}.json`;
  const outputPath = path.join(generatedDir, outputFileName);

  // Use absolute path for output
  const absoluteOutputPath = path.resolve(outputPath);

  // Use --using service with resolutionPath to export individual service
  // Quote resolutionPath to handle special characters and wildcards
  const quotedResolutionPath = `"${resolutionPath}"`;
  const command = `${graphmanPath} export --gateway ${gateway} --using service --variables.resolutionPath ${quotedResolutionPath} --output "${absoluteOutputPath}"`;

  try {
    console.log(`Exporting service: ${serviceName} (${resolutionPath})...`);
    console.log(`  Output: ${absoluteOutputPath}`);
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
      // Don't throw here - we'll check if file was created
    }
    
    // Show graphman output if any
    if (result && result.trim()) {
      console.log(`  Graphman output:\n${result.trim()}`);
    }
    if (errorOutput && errorOutput.trim()) {
      console.error(`  Graphman error:\n${errorOutput.trim()}`);
    }
    
    // Verify file was created
    if (fs.existsSync(absoluteOutputPath)) {
      const stats = fs.statSync(absoluteOutputPath);
      console.log(`✓ Successfully exported: ${serviceName} (${stats.size} bytes)\n`);
      return true;
    } else {
      console.error(`✗ Export completed but file not found: ${absoluteOutputPath}`);
      console.error(`  This usually means the graphman command failed silently.`);
      console.error(`  Check gateway connectivity and that the resolutionPath exists.\n`);
      return false;
    }
  } catch (error) {
    console.error(`✗ Failed to export ${serviceName}: ${error.message}`);
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

// Export a single policy using graphman
function exportPolicy(policyName) {
  if (!policyName) {
    console.log(`⚠ Skipping policy: No policy name found`);
    return false;
  }

  const outputFileName = `${sanitizeFileName(policyName)}.json`;
  const outputPath = path.join(generatedDir, outputFileName);

  // Use absolute path for output
  const absoluteOutputPath = path.resolve(outputPath);

  // Use --using policy with name and includeAllDependencies
  // Quote policy name to handle special characters
  const quotedPolicyName = `"${policyName}"`;
  const command = `${graphmanPath} export --gateway ${gateway} --using policy --variables.name ${quotedPolicyName} --variables.includeAllDependencies --output "${absoluteOutputPath}"`;

  try {
    console.log(`Exporting policy: ${policyName}...`);
    console.log(`  Output: ${absoluteOutputPath}`);
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
      // Don't throw here - we'll check if file was created
    }
    
    // Show graphman output if any
    if (result && result.trim()) {
      console.log(`  Graphman output:\n${result.trim()}`);
    }
    if (errorOutput && errorOutput.trim()) {
      console.error(`  Graphman error:\n${errorOutput.trim()}`);
    }
    
    // Verify file was created
    if (fs.existsSync(absoluteOutputPath)) {
      const stats = fs.statSync(absoluteOutputPath);
      console.log(`✓ Successfully exported: ${policyName} (${stats.size} bytes)\n`);
      return true;
    } else {
      console.error(`✗ Export completed but file not found: ${absoluteOutputPath}`);
      console.error(`  This usually means the graphman command failed silently.`);
      console.error(`  Check gateway connectivity and that the policy name exists.\n`);
      return false;
    }
  } catch (error) {
    console.error(`✗ Failed to export ${policyName}: ${error.message}`);
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

// Process all results files
function processResultsFiles() {
  // Find all *-results.json files
  const files = fs.readdirSync(resultsDir)
    .filter(file => file.endsWith('-results.json'));

  if (files.length === 0) {
    console.log('No results files found matching pattern *-results.json');
    return;
  }

  console.log(`Found ${files.length} results file(s)\n`);

  // Load service data once
  const serviceData = loadServiceData();
  if (!serviceData) {
    console.error('Failed to load service data. Exiting.');
    return;
  }

  // Collect all unique services and policies from all results files
  const servicesMap = new Map();
  const policiesMap = new Map();

  files.forEach(file => {
    const filePath = path.join(resultsDir, file);
    try {
      const fileContent = fs.readFileSync(filePath, 'utf8');
      const results = JSON.parse(fileContent);

      if (results.results && Array.isArray(results.results)) {
        results.results.forEach(item => {
          // Only include items where exists is true
          if (item.name && item.exists === true) {
            const itemType = item.type || 'Service'; // Default to Service for backward compatibility
            
            if (itemType === 'Service') {
              // Handle services
              if (!servicesMap.has(item.name)) {
                // Get full service info from original data
                const serviceInfo = getServiceInfo(item.name, serviceData);
                if (serviceInfo && serviceInfo.resolutionPath) {
                  servicesMap.set(item.name, {
                    name: item.name,
                    folderPath: serviceInfo.folderPath,
                    resolutionPath: serviceInfo.resolutionPath
                  });
                } else {
                  // Fallback to resolutionPath from results if not found in original data
                  if (item.resolutionPath) {
                    servicesMap.set(item.name, {
                      name: item.name,
                      folderPath: null,
                      resolutionPath: item.resolutionPath
                    });
                  }
                }
              }
            } else if (itemType === 'Policy') {
              // Handle policies
              if (!policiesMap.has(item.name)) {
                policiesMap.set(item.name, {
                  name: item.name,
                  folderPath: item.folderPath || null
                });
              }
            }
          }
        });
      }
    } catch (error) {
      console.error(`Error reading ${file}: ${error.message}`);
    }
  });

  console.log(`Found ${servicesMap.size} unique service(s) to export`);
  console.log(`Found ${policiesMap.size} unique policy/policies to export\n`);

  // Export each service
  let serviceSuccessCount = 0;
  let serviceFailCount = 0;

  servicesMap.forEach((serviceInfo, serviceName) => {
    const success = exportService(serviceName, serviceInfo.resolutionPath);
    if (success) {
      serviceSuccessCount++;
    } else {
      serviceFailCount++;
    }
  });

  // Export each policy
  let policySuccessCount = 0;
  let policyFailCount = 0;

  policiesMap.forEach((policyInfo, policyName) => {
    const success = exportPolicy(policyName);
    if (success) {
      policySuccessCount++;
    } else {
      policyFailCount++;
    }
  });

  // Summary
  const totalItems = servicesMap.size + policiesMap.size;
  const totalSuccess = serviceSuccessCount + policySuccessCount;
  const totalFail = serviceFailCount + policyFailCount;

  console.log('\n' + '='.repeat(50));
  console.log('Export Summary:');
  console.log(`  Total items: ${totalItems}`);
  console.log(`    Services: ${servicesMap.size} (Successful: ${serviceSuccessCount}, Failed: ${serviceFailCount})`);
  console.log(`    Policies: ${policiesMap.size} (Successful: ${policySuccessCount}, Failed: ${policyFailCount})`);
  console.log(`  Overall: Successful: ${totalSuccess}, Failed: ${totalFail}`);
  console.log(`  Output directory: ${generatedDir}`);
  console.log('='.repeat(50));
}

// Main execution
try {
  // Validate graphman path
  if (!fs.existsSync(graphmanPath)) {
    console.error(`Error: Graphman script not found at: ${graphmanPath}`);
    console.error(`Please provide the correct GRAPHMAN_HOME path as the first argument.`);
    console.error(`Usage: node ExportBundles.js [GRAPHMAN_HOME] [--gateway <gateway>]`);
    console.error(`Example: node ExportBundles.js ../../graphman-client-main --gateway aws`);
    process.exit(1);
  }

  console.log('Starting service and policy export process...');
  console.log(`  GRAPHMAN_HOME: ${graphmanHome}`);
  console.log(`  Gateway: ${gateway}`);
  console.log(`  Graphman path: ${graphmanPath}\n`);
  
  processResultsFiles();
} catch (error) {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
}
