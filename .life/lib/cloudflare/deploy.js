#!/usr/bin/env node

// Cloudflare adapter — deploy a directory's Worker
// Reads the directory path from LIFE_CONTEXT or argv.
// Creates a minimal Worker from the directory's src/worker.js if it exists.

const fs = require('fs');
const path = require('path');

async function deploy() {
  const token = process.env.CLOUDFLARE_API_TOKEN;
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const targetDir = process.argv[2] || process.env.LIFE_TARGET;

  if (!token || !accountId) {
    console.log('✗ Cloudflare not connected. Run: life run cloudflare.connect');
    process.exit(1);
  }

  if (!targetDir) {
    console.log('✗ No target directory. Usage: node deploy.js <dir>');
    process.exit(1);
  }

  // Read the .life file to get the name
  const lifeFile = path.join(targetDir, '.life');
  if (!fs.existsSync(lifeFile)) {
    console.log(`✗ No .life file in ${targetDir}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(lifeFile, 'utf-8');
  const nameMatch = raw.match(/^name:\s*(.+)/m);
  const name = nameMatch ? nameMatch[1].trim() : path.basename(targetDir);

  // Find the worker source
  const workerPath = path.join(targetDir, 'src', 'worker.js');
  if (!fs.existsSync(workerPath)) {
    console.log(`✗ No src/worker.js in ${targetDir}`);
    process.exit(1);
  }

  const workerCode = fs.readFileSync(workerPath, 'utf-8');
  console.log(`Deploying ${name} to Cloudflare...`);

  // Deploy via Workers API
  const formData = new FormData();

  const metadata = JSON.stringify({
    main_module: 'worker.js',
    compatibility_date: '2024-01-01',
  });

  formData.append('metadata', new Blob([metadata], { type: 'application/json' }));
  formData.append('worker.js', new Blob([workerCode], { type: 'application/javascript+module' }), 'worker.js');

  try {
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${name}`,
      {
        method: 'PUT',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData,
      }
    );
    const data = await res.json();
    if (!data.success) {
      console.log('✗ Deploy failed:', JSON.stringify(data.errors));
      process.exit(1);
    }
    console.log(`✓ Worker "${name}" deployed`);
  } catch (e) {
    console.log('✗ Deploy failed:', e.message);
    process.exit(1);
  }
}

deploy();
