const fs = require('fs');
const path = require('path');

console.log('🔍 ChaosChain DVN - Repository Verification');
console.log('='.repeat(50));

const checks = [];
let allPassed = true;

// Check if required files exist
const requiredFiles = [
    'README.md',
    '.gitignore',
    'LICENSE',
    'CONTRIBUTING.md',
    'package.json',
    'hardhat.config.js',
    'config/environment.example',
    'docs/SETUP.md',
    'PHASE_1_COMPLETION_SUMMARY.md'
];

console.log('📁 Checking required files...');
requiredFiles.forEach(file => {
    const exists = fs.existsSync(file);
    const status = exists ? '✅' : '❌';
    console.log(`   ${status} ${file}`);
    if (!exists) allPassed = false;
    checks.push({ file, exists });
});

// Check if sensitive files are ignored
const sensitiveFiles = [
    '.env',
    'config/deployment-localhost.json',
    'config/deployment-hardhat.json'
];

console.log('\n🔒 Checking sensitive files are not committed...');
sensitiveFiles.forEach(file => {
    const exists = fs.existsSync(file);
    const ignored = !exists; // If file doesn't exist, it's effectively ignored
    const status = ignored ? '✅' : '⚠️';
    const message = ignored ? 'Not present (good)' : 'Exists (should be in .gitignore)';
    console.log(`   ${status} ${file} - ${message}`);
});

// Check contract compilation
console.log('\n🔨 Checking contract compilation...');
try {
    const artifactsDir = path.join(__dirname, '..', 'artifacts');
    if (fs.existsSync(artifactsDir)) {
        console.log('   ✅ Artifacts directory exists');
        
        // Check for main contracts
        const mainContracts = [
            'DVNRegistryPOC',
            'StudioPOC', 
            'DVNAttestationPOC',
            'DVNConsensusPOC'
        ];
        
        mainContracts.forEach(contract => {
            const contractPath = path.join(artifactsDir, 'contracts', `${contract}.sol`, `${contract}.json`);
            const exists = fs.existsSync(contractPath);
            const status = exists ? '✅' : '❌';
            console.log(`   ${status} ${contract} artifact`);
            if (!exists) allPassed = false;
        });
    } else {
        console.log('   ❌ Artifacts directory not found - run "npm run compile"');
        allPassed = false;
    }
} catch (error) {
    console.log('   ❌ Error checking compilation artifacts');
    allPassed = false;
}

// Check package.json scripts
console.log('\n📋 Checking package.json scripts...');
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const requiredScripts = [
    'compile',
    'test', 
    'coverage',
    'deploy:sepolia',
    'clean'
];

requiredScripts.forEach(script => {
    const exists = packageJson.scripts && packageJson.scripts[script];
    const status = exists ? '✅' : '❌';
    console.log(`   ${status} ${script} script`);
    if (!exists) allPassed = false;
});

// Check dependencies
console.log('\n📦 Checking key dependencies...');
const requiredDeps = [
    '@openzeppelin/contracts',
    'ethers',
    'hardhat'
];

requiredDeps.forEach(dep => {
    const exists = (packageJson.dependencies && packageJson.dependencies[dep]) ||
                   (packageJson.devDependencies && packageJson.devDependencies[dep]);
    const status = exists ? '✅' : '❌';
    console.log(`   ${status} ${dep}`);
    if (!exists) allPassed = false;
});

// Summary
console.log('\n' + '='.repeat(50));
if (allPassed) {
    console.log('🎉 REPOSITORY READY FOR GITHUB!');
    console.log('✅ All checks passed');
    console.log('\nNext steps:');
    console.log('1. Initialize git: git init');
    console.log('2. Add files: git add .');
    console.log('3. Initial commit: git commit -m "feat: initial ChaosChain DVN PoC implementation"');
    console.log('4. Add remote: git remote add origin <your-repo-url>');
    console.log('5. Push: git push -u origin main');
} else {
    console.log('❌ REPOSITORY NOT READY');
    console.log('Please fix the issues above before pushing to GitHub');
}
console.log('='.repeat(50)); 