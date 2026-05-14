const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// Get credentials from environment or .env
require('dotenv').config();

const projectId = 'koszfvvodjctiytbflup';
const dbUrl = `postgresql://postgres.${projectId}:YOUR_SERVICE_ROLE_KEY@db.${projectId}.supabase.co:5432/postgres`;

// Or provide database URL directly
const connectionUrl = process.env.DATABASE_URL || process.argv[2];

if (!connectionUrl) {
  console.error('❌ Error: No DATABASE_URL provided');
  console.error('Usage: node run_migrations.js "postgresql://postgres.PROJECT_ID:PASSWORD@db.PROJECT_ID.supabase.co:5432/postgres"');
  console.error('\nTo get the database URL:');
  console.error('1. Go to app.supabase.com');
  console.error('2. Select your project (koszfvvodjctiytbflup)');
  console.error('3. Go to Settings > Database > Connection String');
  console.error('4. Select "URI" and copy the full connection string');
  process.exit(1);
}

const pool = new Pool({ connectionString: connectionUrl });

const migrationsDir = path.join(__dirname, 'supabase', 'migrations');

async function runMigrations() {
  console.log('🚀 Starting database migrations...\n');
  
  const client = await pool.connect();
  
  try {
    // Get list of migration files in order
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    console.log(`📁 Found ${files.length} migration files\n`);

    // Run only the migrations we need
    const targetMigrations = [
      '202604120001_force_drop_legacy_work_requests_columns.sql',
      '202604120002_work_requests_uuid_migration.sql',
      '202604120003_drop_work_request_unused_columns.sql',
      '202604120004_create_work_evidence_bucket.sql'
    ];

    for (const migrationFile of targetMigrations) {
      if (!files.includes(migrationFile)) {
        console.warn(`⚠️  Skipping ${migrationFile} (not found)`);
        continue;
      }

      console.log(`📝 Running: ${migrationFile}`);
      const filePath = path.join(migrationsDir, migrationFile);
      const sql = fs.readFileSync(filePath, 'utf-8');

      try {
        await client.query(sql);
        console.log(`✅ ${migrationFile} completed\n`);
      } catch (err) {
        console.error(`❌ ${migrationFile} failed:`);
        console.error(err.message);
        console.error(`\nSQL:\n${sql}\n`);
        throw err;
      }
    }

    console.log('🎉 All migrations completed successfully!');
  } catch (err) {
    console.error('\n❌ Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
    await pool.end();
  }
}

runMigrations();
