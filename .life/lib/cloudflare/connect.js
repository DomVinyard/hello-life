#!/usr/bin/env node

// Cloudflare adapter — connection lifecycle
// Verifies: token present → token valid → account accessible

const checkOnly = process.argv.includes('--check');

async function connect() {
  const token = process.env.CLOUDFLARE_API_TOKEN;
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;

  // Step 1: Token present
  if (!token) {
    console.log('✗ CLOUDFLARE_API_TOKEN not set');
    console.log('  Set it in your environment and re-run.');
    process.exit(1);
  }
  console.log('✓ CLOUDFLARE_API_TOKEN present');

  if (!accountId) {
    console.log('✗ CLOUDFLARE_ACCOUNT_ID not set');
    console.log('  Set it in your environment and re-run.');
    process.exit(1);
  }
  console.log('✓ CLOUDFLARE_ACCOUNT_ID present');

  // Step 2: Token valid
  try {
    const res = await fetch('https://api.cloudflare.com/client/v4/user/tokens/verify', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const data = await res.json();
    if (!data.success) {
      console.log('✗ Token invalid:', data.errors?.[0]?.message || 'unknown error');
      process.exit(1);
    }
    console.log('✓ Token valid');
  } catch (e) {
    console.log('✗ Could not reach Cloudflare API:', e.message);
    process.exit(1);
  }

  // Step 3: Account accessible
  try {
    const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const data = await res.json();
    if (!data.success) {
      console.log('✗ Account not accessible:', data.errors?.[0]?.message || 'unknown error');
      process.exit(1);
    }
    console.log(`✓ Account: ${data.result.name}`);
  } catch (e) {
    console.log('✗ Account check failed:', e.message);
    process.exit(1);
  }

  console.log('\nCloudflare adapter connected.');
}

connect();
