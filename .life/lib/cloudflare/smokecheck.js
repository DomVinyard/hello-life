#!/usr/bin/env node

// Cloudflare adapter — smokecheck
// Verifies a deployed Worker is reachable.

async function smokecheck() {
  const token = process.env.CLOUDFLARE_API_TOKEN;
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const targetName = process.argv[2] || process.env.LIFE_TARGET_NAME;

  if (!token || !accountId) {
    console.log('✗ Not connected');
    process.exit(1);
  }

  if (!targetName) {
    console.log('✗ No target. Usage: node smokecheck.js <worker-name>');
    process.exit(1);
  }

  try {
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/workers/scripts/${targetName}`,
      { headers: { 'Authorization': `Bearer ${token}` } }
    );
    const data = await res.json();
    if (data.success) {
      console.log(`✓ Worker "${targetName}" exists`);
    } else {
      console.log(`✗ Worker "${targetName}" not found`);
      process.exit(1);
    }
  } catch (e) {
    console.log('✗ Smokecheck failed:', e.message);
    process.exit(1);
  }
}

smokecheck();
