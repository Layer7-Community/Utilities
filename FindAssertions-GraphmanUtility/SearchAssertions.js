const fs = require('fs');
const path = require('path');

// Parse command line arguments
// Usage: node SearchAssertions.js [assertionType] [--replace-enabled true|false]
// Example: node SearchAssertions.js EvaluateJsonPathExpressionV2
// Example: node SearchAssertions.js SetVariable --replace-enabled true
let searchAssertion = 'EvaluateJsonPathExpressionV2';
let replaceEnabled = false;

// Parse arguments
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg === '--replace-enabled') {
    const value = process.argv[i + 1];
    replaceEnabled = value === 'true' || value === 'True' || value === 'TRUE';
    i++;
  } else if (!arg.startsWith('--')) {
    searchAssertion = arg;
  }
}

// File paths
const inputFile = path.join(__dirname, 'response', 'spFolderSVCFull.json');
// Generate output file names based on search assertion
const safeAssertionName = searchAssertion.replace(/[^a-zA-Z0-9]/g, '-').toLowerCase();
const outputFile = path.join(__dirname, 'response', `${safeAssertionName}-results.json`);
const htmlOutputFile = path.join(__dirname, 'response', `${safeAssertionName}-results.html`);

try {
  // Read and parse the JSON file
  console.log(`Reading file: ${inputFile}`);
  const fileContent = fs.readFileSync(inputFile, 'utf8');
  const data = JSON.parse(fileContent);

  // Check if services or policies arrays exist
  if ((!data.services || !Array.isArray(data.services)) &&
    (!data.policies || !Array.isArray(data.policies))) {
    throw new Error('Invalid JSON structure: services or policies array not found');
  }

  // Helper function to search for assertion in a policies array
  function searchInPoliciesArray(policiesArray, assertionName) {
    if (!policiesArray || !Array.isArray(policiesArray)) {
      return null;
    }

    for (const policyItem of policiesArray) {
      if (policyItem && typeof policyItem === 'object') {
        // Check if this item has the assertion directly
        if (policyItem.hasOwnProperty(assertionName)) {
          return policyItem[assertionName];
        }

        // Check inside OneOrMore.All if it exists
        // OneOrMore can be an array or an object, handle both cases
        const oneOrMore = policyItem.OneOrMore || policyItem.OneorMore || policyItem.oneOrMore || policyItem.oneormore || null;

        if (oneOrMore) {
          // If OneOrMore is an array, iterate through it
          if (Array.isArray(oneOrMore)) {
            for (const oneOrMoreItem of oneOrMore) {
              if (oneOrMoreItem && typeof oneOrMoreItem === 'object') {
                // Check if this item has an All property
                const oneOrMoreAll = oneOrMoreItem.All || oneOrMoreItem.all || null;
                if (oneOrMoreAll && Array.isArray(oneOrMoreAll)) {
                  const found = searchInPoliciesArray(oneOrMoreAll, assertionName);
                  if (found) {
                    return found;
                  }
                }
              }
            }
          }
          // If OneOrMore is an object, check for All property directly
          else if (typeof oneOrMore === 'object') {
            const oneOrMoreAll = oneOrMore.All || oneOrMore.all || null;
            if (oneOrMoreAll && Array.isArray(oneOrMoreAll)) {
              const found = searchInPoliciesArray(oneOrMoreAll, assertionName);
              if (found) {
                return found;
              }
            }
          }
        }
      }
    }
    return null;
  }

  const results = [];

  // Iterate through each service
  if (data.services && Array.isArray(data.services)) {
    data.services.forEach((service, index) => {
      const serviceName = service.name || `Service_${index}`;
      const resolutionPath = service.resolutionPath || 'N/A';

      let foundPolicy = null;
      let exists = false;

      // Check if policy.code exists
      if (service.policy && service.policy.code) {
        const policyCode = service.policy.code;

        // Search in policy.code.All (case-insensitive)
        // This will also recursively search in policy.code.All.OneorMore.All
        const allPolicies = policyCode.All || policyCode.all || null;
        if (allPolicies && Array.isArray(allPolicies)) {
          foundPolicy = searchInPoliciesArray(allPolicies, searchAssertion);
          if (foundPolicy) {
            exists = true;
          }
        }
      }

      // Get folderPath from service data
      const folderPath = service.folderPath || 'N/A';

      // Add all services to results, regardless of whether they have the policy
      results.push({
        type: 'Service',
        name: serviceName,
        resolutionPath: resolutionPath,
        folderPath: folderPath,
        exists: exists,
        policyDetails: foundPolicy || null
      });

      if (exists) {
        console.log(`✓ Found ${searchAssertion} in service: ${serviceName}`);
      } else {
        console.log(`✗ ${searchAssertion} not found in service: ${serviceName}`);
      }
    });
  }

  // Iterate through each policy
  if (data.policies && Array.isArray(data.policies)) {
    data.policies.forEach((policy, index) => {
      const policyName = policy.name || `Policy_${index}`;
      const folderPath = policy.folderPath || 'N/A';

      let foundPolicy = null;
      let exists = false;

      // Check if policy.code exists
      if (policy.policy && policy.policy.code) {
        const policyCode = policy.policy.code;

        // Search in policy.code.All (case-insensitive)
        // This will also recursively search in policy.code.All.OneorMore.All
        const allPolicies = policyCode.All || policyCode.all || null;
        if (allPolicies && Array.isArray(allPolicies)) {
          foundPolicy = searchInPoliciesArray(allPolicies, searchAssertion);
          if (foundPolicy) {
            exists = true;
          }
        }
      }

      // Add all policies to results, regardless of whether they have the assertion
      results.push({
        type: 'Policy',
        name: policyName,
        resolutionPath: 'N/A', // Policies don't have resolutionPath
        folderPath: folderPath,
        exists: exists,
        policyDetails: foundPolicy || null
      });

      if (exists) {
        console.log(`✓ Found ${searchAssertion} in policy: ${policyName}`);
      } else {
        console.log(`✗ ${searchAssertion} not found in policy: ${policyName}`);
      }
    });
  }

  // Extract hostname from properties.meta.hostname
  const hostname = (data.properties && data.properties.meta && data.properties.meta.hostname)
    ? data.properties.meta.hostname
    : 'N/A';

  // Count items with the specified assertion
  const itemsWithAssertions = results.filter(r => r.exists === true).length;
  const totalServices = data.services ? data.services.length : 0;
  const totalPolicies = data.policies ? data.policies.length : 0;
  const totalItems = totalServices + totalPolicies;

  // Write results to output file
  const outputData = {
    timestamp: new Date().toISOString(),
    inputFile: inputFile,
    hostname: hostname,
    searchAssertion: searchAssertion,
    totalServices: totalServices,
    totalPolicies: totalPolicies,
    totalItems: totalItems,
    itemsWithAssertion: itemsWithAssertions,
    results: results
  };

  fs.writeFileSync(outputFile, JSON.stringify(outputData, null, 2), 'utf8');

  // Generate HTML output
  const htmlContent = generateHTML(outputData, searchAssertion, replaceEnabled);
  fs.writeFileSync(htmlOutputFile, htmlContent, 'utf8');

  console.log(`\n✓ Processing complete!`);
  console.log(`  Search assertion: ${searchAssertion}`);
  console.log(`  Total services processed: ${totalServices}`);
  console.log(`  Total policies processed: ${totalPolicies}`);
  console.log(`  Total items processed: ${totalItems}`);
  console.log(`  Items with ${searchAssertion}: ${itemsWithAssertions}`);
  console.log(`  Items without ${searchAssertion}: ${totalItems - itemsWithAssertions}`);
  console.log(`  Results saved to: ${outputFile}`);
  console.log(`  HTML report saved to: ${htmlOutputFile}`);

} catch (error) {
  console.error('Error processing file:', error.message);
  if (error.code === 'ENOENT') {
    console.error(`File not found: ${inputFile}`);
  } else if (error instanceof SyntaxError) {
    console.error('Invalid JSON format in input file');
  }
  process.exit(1);
}

// Function to sanitize filename (same as ExportBundles.js)
function sanitizeFileName(name) {
  return name.replace(/[^a-zA-Z0-9-_]/g, '_');
}

// Function to generate HTML content
function generateHTML(data, assertionName, replaceEnabled = false) {
  const timestamp = new Date(data.timestamp).toLocaleString();
  assertionName = assertionName || data.searchAssertion || 'Assertion';
  const replaceCautionText = 'Replacement and Import feature is intended for lower environments, where proper quality testing will be planned for "Replace Assertions" before importing the policies/services entities into the Gateway';

  let tableRows = '';
  if (data.results && data.results.length > 0) {
    data.results.forEach((result, index) => {
      const assertionsExists = result.exists ? 'Yes' : 'No';
      const rowClass = result.exists ? 'exists-yes' : 'exists-no';
      const serialNo = index + 1;
      const itemType = result.type || 'Unknown';

      // Create link to exported bundle if item exists (was exported)
      // Both Services and Policies are now exported, so create links for both types
      let itemNameCell;
      if (result.exists) {
        const sanitizedName = sanitizeFileName(result.name);
        const bundlePath = `../generated/${sanitizedName}.json`;
        itemNameCell = `<a href="${bundlePath}" target="_blank">${escapeHtml(result.name)}</a>`;
      } else {
        itemNameCell = escapeHtml(result.name);
      }

      tableRows += `
        <tr class="${rowClass}">
          <td>${serialNo}</td>
          <td>${escapeHtml(itemType)}</td>
          <td>${itemNameCell}</td>
          <td>${escapeHtml(result.resolutionPath)}</td>
          <td>${escapeHtml(result.folderPath || 'N/A')}</td>
          <td>${assertionsExists}</td>
        </tr>`;
    });
  } else {
    tableRows = '<tr><td colspan="6" style="text-align: center; padding: 20px;">No items found</td></tr>';
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${assertionName} - Service Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #e5e5e5;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: #f5f5f5;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 20px;
        }
        .header-content {
            text-align: center;
        }
        .header-logo {
            max-width: 150px;
            max-height: 60px;
            height: auto;
            width: auto;
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 14px;
            opacity: 0.9;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            padding: 20px;
            background: #f0f0f0;
            border-bottom: 2px solid #d0d0d0;
        }
        .stat-item {
            text-align: center;
        }
        .stat-value {
            font-size: 32px;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            font-size: 14px;
            color: #6c757d;
            margin-top: 5px;
        }
        .table-container {
            padding: 30px;
            overflow-x: auto;
            max-height: 600px;
            overflow-y: auto;
            background: #ffffff;
            border-radius: 6px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.15);
            margin: 20px;
            border: 1px solid #d0d0d0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: #ffffff;
        }
        thead {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #e0e0e0;
        }
        td a {
            color: #0288d1;
            text-decoration: none;
            font-weight: 500;
            transition: color 0.2s;
        }
        td a:hover {
            color: #01579b;
            text-decoration: underline;
        }
        tbody tr {
            transition: background-color 0.2s;
        }
        tbody tr:hover {
            background-color: #f0f4f8;
        }
        .exists-yes {
            background-color: #b3e5fc;
            border-left: 4px solid #0288d1;
        }
        .exists-yes:hover {
            background-color: #81d4fa;
        }
        .exists-no {
            background-color: #fff3cd;
        }
        .exists-no:hover {
            background-color: #ffeaa7;
        }
        .gateway-info {
            padding: 20px 30px;
            background: #f0f0f0;
            border-bottom: 2px solid #d0d0d0;
        }
        .gateway-info h2 {
            font-size: 18px;
            color: #495057;
            margin-bottom: 8px;
        }
        .gateway-info p {
            font-size: 16px;
            color: #212529;
            font-weight: 500;
        }
        .replace-section {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #d0d0d0;
            display: flex;
            align-items: center;
            gap: 12px;
            flex-wrap: wrap;
        }
        .replace-section label {
            font-size: 16px;
            color: #495057;
            font-weight: 500;
            white-space: nowrap;
        }
        .replace-section input[type="text"] {
            flex: 1;
            min-width: 200px;
            padding: 10px 15px;
            font-size: 14px;
            border: 2px solid #d0d0d0;
            border-radius: 4px;
            transition: border-color 0.2s;
        }
        .replace-section input[type="text"]:focus {
            outline: none;
            border-color: #667eea;
        }
        .replace-section button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            font-size: 16px;
            font-weight: 600;
            border-radius: 4px;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            white-space: nowrap;
        }
        .replace-section button:hover:not(:disabled) {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.3);
        }
        .replace-section button:active:not(:disabled) {
            transform: translateY(0);
        }
        .replace-section button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .replace-section #importButton {
            background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
        }
        .replace-section #importButton:hover:not(:disabled) {
            box-shadow: 0 4px 8px rgba(40, 167, 69, 0.3);
        }
        .replace-caution {
            margin-top: 16px;
            margin-bottom: 12px;
            padding: 12px 16px;
            background-color: #fff8e6;
            border: 1px solid #f0c674;
            border-left: 4px solid #e6a800; 
            border-radius: 4px;
            font-size: 10.9px;
            color: #e90e0eff;
            line-height: 1.5;
        }
        .replace-caution strong {
            color: #5c4a00;
        }
        .footer {
            padding: 20px 30px;
            background: #f0f0f0;
            border-top: 2px solid #d0d0d0;
            text-align: center;
            color: #6c757d;
            font-size: 12px;
        }
        @media (max-width: 768px) {
            .header {
                flex-direction: column;
                gap: 15px;
            }
            .header-logo {
                max-width: 120px;
                max-height: 50px;
            }
            .stats {
                flex-direction: column;
                gap: 15px;
            }
            .table-container {
                padding: 15px;
                margin: 10px;
            }
            table {
                font-size: 14px;
            }
            th, td {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="../broadcom.png" alt="Broadcom Logo" class="header-logo">
            <div class="header-content">
                <h1>${assertionName} Service & Policy Report</h1>
                <p>Generated on ${timestamp}</p>
            </div>
        </div>
        <div class="stats">
            <div class="stat-item">
                <div class="stat-value">${data.totalItems || 0}</div>
                <div class="stat-label">Total Items</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">${data.totalServices || 0}</div>
                <div class="stat-label">Services</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">${data.totalPolicies || 0}</div>
                <div class="stat-label">Policies</div>
            </div>
            <div class="stat-item">
                <div class="stat-value">${data.itemsWithAssertion || 0}</div>
                <div class="stat-label">With ${assertionName}</div>
            </div>
        </div>
        <div class="gateway-info">
            <p><strong>Gateway.Hostname:</strong> ${escapeHtml(data.hostname || 'N/A')}</p>
            ${replaceEnabled ? `
            <div class="replace-section">
                 <div class="replace-caution"><strong>Caution:</strong> ${escapeHtml(replaceCautionText)}</div>
                <label for="assertionsToReplace">Assertions To Replace</label>
                <input type="text" id="assertionsToReplace" name="assertionsToReplace" placeholder="Enter assertion name to replace">
                <button type="button" id="replaceButton" onclick="handleReplaceAssertions('${escapeHtml(assertionName)}')">Replace Assertions</button>
                <button type="button" id="importButton" onclick="handleImportBundles()">Import Bundles</button>
            </div>
            ` : `
            <div class="replace-section" style="opacity: 0.5;">
                <label for="assertionsToReplace" style="color: #999;">Assertions To Replace (Disabled)</label>
                <input type="text" id="assertionsToReplace" name="assertionsToReplace" placeholder="Run searchAssertions.sh with 'Yes' to enable" disabled>
                <button type="button" id="replaceButton" disabled style="opacity: 0.5; cursor: not-allowed;">Replace Assertions</button>
                <button type="button" id="importButton" disabled style="opacity: 0.5; cursor: not-allowed;">Import Bundles</button>
            </div>
            `}
        </div>
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Serial No</th>
                        <th>Type</th>
                        <th>Name</th>
                        <th>Resolution Path</th>
                        <th>Folder Path</th>
                        <th>Assertions Exists</th>
                    </tr>
                </thead>
                <tbody>
                    ${tableRows}
                </tbody>
            </table>
        </div>
        <div class="footer">
            <p>Input File: ${escapeHtml(data.inputFile)}</p>
            <p>All rights reserved</p>
        </div>
    </div>
    <script>
        async function checkServerHealth() {
            try {
                const healthCheck = await fetch('http://localhost:3001/api/health', {
                    method: 'GET',
                    headers: { 'Content-Type': 'application/json' }
                });
                if (!healthCheck.ok) {
                    throw new Error('Server health check failed');
                }
                return true;
            } catch (healthError) {
                throw new Error('SERVER_NOT_RUNNING');
            }
        }

        function showServerError(error) {
            let errorMessage = 'Error: Could not connect to server.\\n\\n';
            
            if (error.message === 'SERVER_NOT_RUNNING' || 
                error.message.includes('Failed to fetch') || 
                error.message.includes('NetworkError') ||
                error.message.includes('ERR_CONNECTION_REFUSED')) {
                errorMessage += 'The replace server is not running.\\n\\n';
                errorMessage += 'To start the server:\\n\\n';
                errorMessage += '  1. Open a terminal/command prompt\\n';
                errorMessage += '  2. Navigate to the script directory:\\n';
                errorMessage += '     cd /Users/br661896/Documents/APIM/Graphman/Scripts/Find-Assertions\\n';
                errorMessage += '  3. Run: node replaceServer.js\\n\\n';
                errorMessage += 'You should see:\\n';
                errorMessage += '  ✓ Replace server running at http://localhost:3001/\\n\\n';
                errorMessage += 'Keep the server running and try again.';
            } else {
                errorMessage += 'Error details: ' + error.message;
            }
            
            alert(errorMessage);
        }

        async function handleReplaceAssertions(searchAssertion) {
            const inputField = document.getElementById('assertionsToReplace');
            const replaceAssertion = inputField.value.trim();
            const button = document.getElementById('replaceButton');
            
            if (!replaceAssertion) {
                alert('Please enter an assertion name to replace.');
                return;
            }
            
            // Disable button and show loading state
            const originalText = button.textContent;
            button.disabled = true;
            button.textContent = 'Processing...';
            
            try {
                // Check if server is running
                await checkServerHealth();
                
                // Construct the results file path based on the current HTML file
                const currentPage = window.location.pathname;
                const pageName = currentPage.split('/').pop() || '';
                const resultsFileName = pageName.replace('-results.html', '-results.json');
                const resultsFile = '../response/' + resultsFileName;
                
                // Call the replace API endpoint
                const response = await fetch('http://localhost:3001/api/replace-and-import', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        resultsFile: resultsFile,
                        searchAssertion: searchAssertion,
                        replaceAssertion: replaceAssertion
                    })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    alert('Success!\\n\\nReplaced "' + searchAssertion + '" with "' + replaceAssertion + '" in all bundle files.\\n\\nCheck the generated/ folder for updated files.\\nBackup files have been created.');
                    console.log('Replace successful:', result);
                } else {
                    const errorMsg = result.error || 'Unknown error occurred';
                    const outputMsg = result.output ? '\\n\\nOutput:\\n' + result.output.substring(0, 500) : '';
                    alert('Error: ' + errorMsg + outputMsg);
                    console.error('Replace failed:', result);
                }
            } catch (error) {
                console.error('Error calling replace API:', error);
                showServerError(error);
            } finally {
                // Re-enable button
                button.disabled = false;
                button.textContent = originalText;
            }
        }

        async function handleImportBundles() {
            const button = document.getElementById('importButton');
            
            // Disable button and show loading state
            const originalText = button.textContent;
            button.disabled = true;
            button.textContent = 'Processing...';
            
            try {
                // Check if server is running
                await checkServerHealth();
                
                // Use default values (can be made configurable later)
                const graphmanHome = '../../graphman-client-main';
                const gateway = 'aws';
                
                // Call the import API endpoint
                const response = await fetch('http://localhost:3001/api/import-bundles', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        graphmanHome: graphmanHome,
                        gateway: gateway
                    })
                });
                
                const result = await response.json();
                
                if (result.success) {
                    alert('Success!\\n\\nImported all bundle files from generated/ directory to the gateway.\\n\\nCheck the console output for details.');
                    console.log('Import successful:', result);
                } else {
                    const errorMsg = result.error || 'Unknown error occurred';
                    const outputMsg = result.output ? '\\n\\nOutput:\\n' + result.output.substring(0, 500) : '';
                    alert('Error: ' + errorMsg + outputMsg);
                    console.error('Import failed:', result);
                }
            } catch (error) {
                console.error('Error calling import API:', error);
                showServerError(error);
            } finally {
                // Re-enable button
                button.disabled = false;
                button.textContent = originalText;
            }
        }
    </script>
</body>
</html>`;
}

// Function to escape HTML special characters
function escapeHtml(text) {
  if (text === null || text === undefined) {
    return '';
  }
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return String(text).replace(/[&<>"']/g, m => map[m]);
}
