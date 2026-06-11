const fs = require('fs');
const path = require('path');

// Usage: node ReplaceAssertions.js <results-file> <searchAssertion> <replaceAssertion>
// Example: node ReplaceAssertions.js response/evaluatejsonpathexpressionv2-results.json EvaluateJsonPathExpressionV2 EvaluateJsonPathExpressionV3

const resultsFile = process.argv[2];
const searchAssertion = process.argv[3];
const replaceAssertion = process.argv[4];

if (!resultsFile || !searchAssertion || !replaceAssertion) {
  console.error('Usage: node ReplaceAssertions.js <results-file> <searchAssertion> <replaceAssertion>');
  console.error('Example: node ReplaceAssertions.js response/evaluatejsonpathexpressionv2-results.json EvaluateJsonPathExpressionV2 EvaluateJsonPathExpressionV3');
  process.exit(1);
}

const generatedDir = path.join(__dirname, 'generated');

// Function to sanitize filename (same as ExportBundles.js and SearchAssertions.js)
function sanitizeFileName(name) {
  return name.replace(/[^a-zA-Z0-9-_]/g, '_');
}

// Recursively walk any object/array and replace every occurrence of searchAssertion
// key with replaceAssertion key, preserving the value. Mirrors deepSearchAssertion
// in SearchAssertions.js so that any depth of nesting is handled.
function deepReplaceAssertion(obj, searchAssertion, replaceAssertion) {
  if (!obj || typeof obj !== 'object') return false;

  let replaced = false;

  if (Array.isArray(obj)) {
    for (const item of obj) {
      if (deepReplaceAssertion(item, searchAssertion, replaceAssertion)) replaced = true;
    }
  } else {
    if (Object.prototype.hasOwnProperty.call(obj, searchAssertion)) {
      const value = obj[searchAssertion];
      delete obj[searchAssertion];
      obj[replaceAssertion] = value;
      replaced = true;
    }
    for (const key of Object.keys(obj)) {
      // Skip the key we just wrote to avoid an unnecessary re-visit
      if (key === replaceAssertion) continue;
      if (typeof obj[key] === 'object' && obj[key] !== null) {
        if (deepReplaceAssertion(obj[key], searchAssertion, replaceAssertion)) replaced = true;
      }
    }
  }

  return replaced;
}

// Resolve the policy code object from an entry, handling both formats:
//   - entry.policy.code  → already a parsed object (policyCodeFormat: code)
//   - entry.policy.json  → a JSON string that must be parsed  (policyCodeFormat: json)
// Returns { policyCode, writeBack } where writeBack(updated) persists changes when
// the policy was stored as a JSON string.
function getPolicyCodeForReplace(entry) {
  if (!entry || !entry.policy) return null;

  if (entry.policy.code && typeof entry.policy.code === 'object') {
    return {
      policyCode: entry.policy.code,
      writeBack: null   // mutations on the object are reflected in-place
    };
  }

  if (entry.policy.json) {
    try {
      const parsed = typeof entry.policy.json === 'string'
        ? JSON.parse(entry.policy.json)
        : entry.policy.json;
      return {
        policyCode: parsed,
        writeBack: (updated) => { entry.policy.json = JSON.stringify(updated); }
      };
    } catch (e) {
      return null;
    }
  }

  return null;
}

// Replace assertion in a bundle file (service or policy bundle).
// Handles both policy.code (parsed object) and policy.json (JSON string) formats.
function replaceInBundle(bundleData, itemType, searchAssertion, replaceAssertion) {
  let replaced = false;

  const processEntry = (entry) => {
    const result = getPolicyCodeForReplace(entry);
    if (!result) return false;

    const { policyCode, writeBack } = result;
    const didReplace = deepReplaceAssertion(policyCode, searchAssertion, replaceAssertion);

    if (didReplace && writeBack) {
      writeBack(policyCode);
    }

    return didReplace;
  };

  if (itemType === 'Service') {
    if (bundleData.services && Array.isArray(bundleData.services)) {
      for (const service of bundleData.services) {
        if (processEntry(service)) replaced = true;
      }
    }
  } else if (itemType === 'Policy') {
    if (bundleData.policies && Array.isArray(bundleData.policies)) {
      for (const policy of bundleData.policies) {
        if (processEntry(policy)) replaced = true;
      }
    }
  }

  return replaced;
}

try {
  // 1. Read the search results file
  console.log(`Reading search results: ${resultsFile}`);
  if (!fs.existsSync(resultsFile)) {
    throw new Error(`Results file not found: ${resultsFile}`);
  }
  
  const resultsContent = fs.readFileSync(resultsFile, 'utf8');
  const resultsData = JSON.parse(resultsContent);

  // Verify the searchAssertion matches
  if (resultsData.searchAssertion !== searchAssertion) {
    console.warn(`⚠ Warning: Results file searchAssertion (${resultsData.searchAssertion}) doesn't match provided searchAssertion (${searchAssertion})`);
    console.warn('  Continuing anyway...\n');
  }

  // 2. Filter to items where exists === true (both Services and Policies)
  const itemsToReplace = resultsData.results.filter(item => item.exists === true);
  
  if (itemsToReplace.length === 0) {
    console.log('No items found with the assertion to replace.');
    process.exit(0);
  }

  // Separate by type for better reporting
  const servicesToReplace = itemsToReplace.filter(item => item.type === 'Service');
  const policiesToReplace = itemsToReplace.filter(item => item.type === 'Policy');

  console.log(`Found ${itemsToReplace.length} item(s) to process:`);
  console.log(`  Services: ${servicesToReplace.length}`);
  console.log(`  Policies: ${policiesToReplace.length}\n`);
  
  itemsToReplace.forEach(item => {
    console.log(`  - ${item.type}: ${item.name}`);
  });

  // 3. Verify generated directory exists
  if (!fs.existsSync(generatedDir)) {
    throw new Error(`Generated directory not found: ${generatedDir}\nPlease run ExportBundles.js first to generate the bundle files.`);
  }

  // 4. Replace assertions in each bundle file (both Services and Policies)
  console.log(`\nReplacing "${searchAssertion}" with "${replaceAssertion}" in bundle files...\n`);
  
  let totalReplacements = 0;
  let serviceReplacements = 0;
  let policyReplacements = 0;
  const replacedItems = [];
  const failedItems = [];
  const missingFiles = [];

  itemsToReplace.forEach(item => {
    // Construct the bundle filename (same as ExportBundles.js)
    const sanitizedName = sanitizeFileName(item.name);
    const bundleFile = path.join(generatedDir, `${sanitizedName}.json`);
    
    if (!fs.existsSync(bundleFile)) {
      missingFiles.push({ type: item.type, name: item.name, file: bundleFile });
      console.log(`⚠ Bundle file not found: ${bundleFile}`);
      return;
    }

    try {
      // Read the bundle file
      const bundleContent = fs.readFileSync(bundleFile, 'utf8');
      const bundleData = JSON.parse(bundleContent);

      // Create backup of the bundle file
      const backupFile = path.join(generatedDir, `${sanitizedName}.backup.${Date.now()}.json`);
      fs.writeFileSync(backupFile, bundleContent, 'utf8');

      // Replace assertions in the bundle
      const replaced = replaceInBundle(bundleData, item.type, searchAssertion, replaceAssertion);
      
      if (replaced) {
        // Write the updated bundle back
        fs.writeFileSync(bundleFile, JSON.stringify(bundleData, null, 2), 'utf8');
        
        totalReplacements++;
        if (item.type === 'Service') {
          serviceReplacements++;
        } else if (item.type === 'Policy') {
          policyReplacements++;
        }
        replacedItems.push({ type: item.type, name: item.name, file: bundleFile });
        console.log(`✓ Replaced in ${item.type}: ${item.name} (${bundleFile})`);
      } else {
        // No replacement made, restore from backup
        fs.unlinkSync(backupFile);
        failedItems.push({ type: item.type, name: item.name, file: bundleFile });
        console.log(`✗ No assertion found to replace in ${item.type}: ${item.name}`);
      }
    } catch (error) {
      failedItems.push({ type: item.type, name: item.name, file: bundleFile, error: error.message });
      console.log(`✗ Error processing ${item.type}: ${item.name} - ${error.message}`);
    }
  });
  
  // 5. Summary
  console.log(`\n${'='.repeat(50)}`);
  console.log('Replacement Summary:');
  console.log(`  Total items processed: ${itemsToReplace.length}`);
  console.log(`    Services: ${servicesToReplace.length}`);
  console.log(`    Policies: ${policiesToReplace.length}`);
  console.log(`  Total replacements: ${totalReplacements}`);
  console.log(`    Services: ${serviceReplacements}`);
  console.log(`    Policies: ${policyReplacements}`);
  
  if (replacedItems.length > 0) {
    console.log(`\n  Successfully replaced:`);
    replacedItems.forEach(item => {
      console.log(`    ✓ ${item.type}: ${item.name}`);
      console.log(`      File: ${item.file}`);
    });
  }
  
  if (missingFiles.length > 0) {
    console.log(`\n  Bundle files not found (run ExportBundles.js first):`);
    missingFiles.forEach(item => {
      console.log(`    ⚠ ${item.type}: ${item.name}`);
      console.log(`      Expected: ${item.file}`);
    });
  }
  
  if (failedItems.length > 0) {
    console.log(`\n  Failed to replace:`);
    failedItems.forEach(item => {
      console.log(`    ✗ ${item.type}: ${item.name}`);
      if (item.error) {
        console.log(`      Error: ${item.error}`);
      }
    });
  }
  
  console.log(`\n  Updated bundle files are in: ${generatedDir}`);
  console.log(`  Backup files created with timestamp in: ${generatedDir}`);
  console.log(`${'='.repeat(50)}`);

} catch (error) {
  console.error('\n✗ Error:', error.message);
  if (error.code === 'ENOENT') {
    console.error(`File not found: ${error.path || 'unknown'}`);
  } else if (error instanceof SyntaxError) {
    console.error('Invalid JSON format');
  }
  process.exit(1);
}
