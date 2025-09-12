# Babelfish Training Guide for SQL Server Developers

**Target Audience**: SQL Server developers with minimal Linux/Docker experience  
**Objective**: Connect to Babelfish, restore databases from S3, and query using familiar SQL Server tools

---

## 📋 **Prerequisites**

Before starting, ensure you have:

- ✅ **Windows 10/11** with WSL2 enabled
- ✅ **Docker Desktop** installed and running
- ✅ **SQL Server Management Studio (SSMS)** installed
- ✅ **VS Code** or **Cursor** installed
- ✅ **AWS CLI** configured (for S3 downloads)
- ✅ **This repository** cloned to your Windows machine - https://github.com/bill-ramos-rmoswi/docker-babelfishpg-devtools.git

---

## 🚀 **Phase 1: Start Your Babelfish Environment**

### Step 1.1: Open the Project
1. **Navigate to the project folder** in Windows Explorer:
   ```
   C:\Users\[YourUsername]\source\docker-babelfishpg-devtools
   ```

2. **Start Babelfish** using the familiar SQL Server-style command:
   - **Double-click** `start_babelfish.bat` **OR**
   - Open **Command Prompt** as Administrator and run:
   ```cmd
   start_babelfish.bat
   ```

3. **Wait for startup** (first time takes 30-60 minutes):
   ```
   ✓ Babelfish for PostgreSQL is now running!
   
   Connection Information:
     SQL Server (TDS) Port: localhost,3341
     PostgreSQL Port:        localhost:2345  
     SSH Port:              localhost:2223
   
   Default Credentials:
     Username: sa
     Password: arborgold
     Database: babelfish_db
   ```

### Step 1.2: Verify Connection
1. **Open SQL Server Management Studio (SSMS)**

2. **Connect using these settings**:
   ```
   Server Type: Database Engine
   Server name: localhost,3341
   Authentication: SQL Server Authentication
   Login: sa
   Password: arborgold
   ```

3. **Test the connection** by running:
   ```sql
   SELECT @@VERSION;
   SELECT name FROM sys.databases;
   ```

   You should see Babelfish version information and available databases.

---

## 📥 **Phase 2: Download Database from S3**

### Step 2.1: Prepare Backup Directory

1. **Open Command Prompt** and navigate to your backup folder:
   ```cmd
   cd C:\Users\%USERNAME%\bbf_backups
   ```
   *(This folder was automatically created when you started Babelfish)*

2. **Verify the folder exists**:
   ```cmd
   dir
   ```

### Step 2.2: Download from S3

**Option A: Using AWS CLI (Recommended)**
```cmd
REM Download the fxdevlop_cadm database backup
aws s3 cp s3://your-bucket-name/fxdevlop_cadm/ C:\Users\%USERNAME%\bbf_backups\fxdevlop_cadm\ --recursive

REM Verify download
dir C:\Users\%USERNAME%\bbf_backups\fxdevlop_cadm
```

**Option B: Using AWS Console (If AWS CLI not available)**
1. Open AWS Console in browser
2. Navigate to S3 bucket
3. Download fxdevlop_cadm backup files to:
   ```
   C:\Users\[YourUsername]\bbf_backups\fxdevlop_cadm\
   ```

### Step 2.3: Verify Download Structure

Your backup folder should look like this:
```
C:\Users\[YourUsername]\bbf_backups\
└── fxdevlop_cadm\
    └── [YYYY-MM-DD_HHMM]\          # Date folder from backup
        ├── fxdevlop_cadm.pgsql     # Roles and schema
        └── fxdevlop_cadm.tar       # Database content
```

---

## 🔄 **Phase 3: Restore Database to Babelfish**

### Step 3.1: Access the Container

Since you're a SQL Server developer, think of this as "logging into the database server":

1. **Open Command Prompt** and run:
   ```cmd
   REM This is like opening a SQL Server command prompt, but for Linux
   docker-compose exec babelfish bash
   ```

   You'll see a Linux command prompt like:
   ```bash
   postgres@[container-id]:/workspace$
   ```

### Step 3.2: Run the Restore

**Don't worry about the Linux commands - just follow exactly:**

1. **Navigate to the scripts folder**:
   ```bash
   cd /workspace
   ```

2. **Run the restore command** (replace with your actual database name):
   ```bash
   ./restore_babelfish.sh fxdevlop_cadm
   ```

3. **Watch for success messages**:
   ```
   ✓ Database 'fxdevlop_cadm' successfully created on target cluster
   ✓ Restore completed successfully
   ```

### Step 3.3: Handle Common Issues

**If you see "database already exists"**:
```bash
# In the container, connect to PostgreSQL and rename the existing database
psql -U sa -d babelfish_db -c "ALTER DATABASE fxdevlop_cadm RENAME TO fxdevlop_cadm_old;"

# Then retry the restore
./restore_babelfish.sh fxdevlop_cadm
```

**If restore fails with permission errors**:
```bash
# Fix permissions (run as container administrator)
exit
docker-compose exec --user root babelfish ./fix_permissions.sh --all
docker-compose exec babelfish bash
./restore_babelfish.sh fxdevlop_cadm
```

---

## 🔍 **Phase 4: Query with SQL Server Management Studio**

### Step 4.1: Refresh SSMS Connection

1. **In SSMS, right-click** on the server connection
2. **Select "Refresh"**
3. **Expand "Databases"** - you should now see `fxdevlop_cadm`

### Step 4.2: Explore the Database

**View available tables**:
```sql
-- List all tables in the restored database
USE fxdevlop_cadm;
GO

SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS TableName,
    create_date AS CreatedDate
FROM sys.tables
ORDER BY SchemaName, TableName;
```

**Check table row counts**:
```sql
-- Get row counts for all tables (useful for validation)
SELECT 
    t.name AS TableName,
    p.rows AS RowCount
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id < 2
ORDER BY p.rows DESC;
```

### Step 4.3: Sample Queries

**Basic data exploration**:
```sql
-- Example: Query the first few rows from each major table
-- (Adjust table names based on your actual schema)

-- Check if there's a users/customers table
SELECT TOP 10 * FROM [dbo].[users] ORDER BY 1;

-- Check if there's an orders/transactions table  
SELECT TOP 10 * FROM [dbo].[orders] ORDER BY 1;

-- Get database statistics
SELECT 
    COUNT(*) as TableCount 
FROM sys.tables;

SELECT 
    DB_NAME() as DatabaseName,
    GETDATE() as QueryTime;
```

**Advanced queries** (same T-SQL you know):
```sql
-- Complex joins and analytics work exactly like SQL Server
SELECT 
    u.username,
    COUNT(o.order_id) as OrderCount,
    SUM(o.total_amount) as TotalSpent
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
WHERE u.created_date >= '2023-01-01'
GROUP BY u.username, u.user_id
HAVING COUNT(o.order_id) > 0
ORDER BY TotalSpent DESC;
```

---

## 🛠️ **Troubleshooting Guide**

### Connection Issues

**Problem**: "Cannot connect to localhost,3341"
```cmd
REM Check if Babelfish is running
docker-compose ps

REM If not running, start it
start_babelfish.bat

REM Check Docker Desktop is running
docker version
```

**Problem**: "Login failed for user 'sa'"
```cmd
REM Check your credentials in the .env file
type .devcontainer\.env

REM Look for these lines:
REM PGUSER=sa  
REM PGPASSWORD=arborgold
```

### Database Issues

**Problem**: "Database 'fxdevlop_cadm' does not exist"
```sql
-- In SSMS, check what databases are available:
SELECT name FROM sys.databases;

-- If it's not there, re-run the restore process
```

**Problem**: "Permission denied" errors
```cmd
REM Reset permissions (from Windows Command Prompt)
docker-compose exec --user root babelfish ./fix_permissions.sh --all

REM Restart if needed
stop_babelfish.bat
start_babelfish.bat
```

### Performance Issues

**Problem**: Queries running slowly
```sql
-- Check if statistics need updating (Babelfish supports this)
UPDATE STATISTICS [your_table_name];

-- Or update all statistics in the database
EXEC sp_updatestats;
```

---

## 📚 **Reference Information**

### Connection Details
| Component | Windows Access | Notes |
|-----------|----------------|-------|
| **SQL Server (TDS)** | `localhost,3341` | Use this in SSMS |
| **PostgreSQL Native** | `localhost:2345` | For PostgreSQL tools |
| **SSH Access** | `localhost:2223` | Advanced users only |

### File Locations
| Type | Windows Path | Container Path | Purpose |
|------|-------------|----------------|---------|
| **Backups** | `C:\Users\%USERNAME%\bbf_backups` | `/var/lib/babelfish/windows_backups` | Your database backups |
| **Scripts** | Project folder | `/workspace` | Restore/backup scripts |

### Useful Commands

**Windows (Command Prompt):**
```cmd
start_babelfish.bat          :: Start Babelfish
stop_babelfish.bat           :: Stop Babelfish  
reset_babelfish.bat          :: Nuclear option - deletes everything!
docker-compose ps            :: Check container status
docker-compose logs babelfish :: View container logs
```

**Inside Container (Linux):**
```bash
./restore_babelfish.sh [db_name]     # Restore a database
./backup_babelfish.sh [db_name]      # Backup a database
psql -U sa -d babelfish_db          # Connect to PostgreSQL directly
exit                                # Leave container
```

### Getting Help

1. **Check container logs**:
   ```cmd
   docker-compose logs babelfish
   ```

2. **View this guide**: Always available at `SQL_SERVER_DEVELOPER_TRAINING_GUIDE.md`

3. **Reset everything** (if really stuck):
   ```cmd
   reset_babelfish.bat
   ```
   ⚠️ **Warning: This deletes all data!**

---

## ✅ **Success Checklist**

- [ ] Babelfish container started successfully
- [ ] Connected to Babelfish using SSMS (localhost,3341)
- [ ] Downloaded fxdevlop_cadm from S3 to Windows bbf_backups folder
- [ ] Successfully restored fxdevlop_cadm database
- [ ] Can see database in SSMS Object Explorer
- [ ] Successfully ran queries against restored tables
- [ ] Understand how to start/stop Babelfish for future sessions

**Congratulations! You're now ready to work with Babelfish as if it were SQL Server!** 🎉

---

*Need help? Check the troubleshooting section above or ask your team lead.*