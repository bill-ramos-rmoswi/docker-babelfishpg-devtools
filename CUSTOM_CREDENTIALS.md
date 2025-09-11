# Custom Credentials Configuration

## Overview
You can customize both the database credentials and the root SSH password for your DevContainer.

## Method 1: Using Environment Variables (Recommended)

### Step 1: Create .env File
Create a `.devcontainer/.env` file (DO NOT commit this to Git):

```bash
cd .devcontainer
cp .env.example .env
```

### Step 2: Edit .env with Your Credentials
```bash
# .devcontainer/.env
BABELFISH_USER=myuser
BABELFISH_PASSWORD=mySecurePassword123!
BABELFISH_DATABASE=mydb
ROOT_PASSWORD=myRootPassword456!
```

### Step 3: Start DevContainer
The DevContainer will automatically use these environment variables.

## Method 2: Command Line Arguments

Edit `.devcontainer/docker-compose.yml`:

```yaml
command: /start.sh -u myuser -p mypassword -d mydb
```

## Method 3: Build-time Configuration (Permanent)

For permanent root password, modify the Dockerfile:

```dockerfile
# In the runner stage, replace:
RUN echo 'root:postgres' | chpasswd
# With:
ARG ROOT_PASSWORD=myCustomRootPassword
RUN echo "root:${ROOT_PASSWORD}" | chpasswd
```

Then build with:
```bash
docker build --build-arg ROOT_PASSWORD=mypassword -t babelfishpg-devtools .
```

## Security Best Practices

1. **Never commit .env files** - Already in .gitignore
2. **Use strong passwords** - Mix of letters, numbers, special characters
3. **Rotate credentials regularly** - Especially for production
4. **Use secrets management** - Consider Docker secrets or AWS Secrets Manager

## Connection Examples with Custom Credentials

### From Host (with custom credentials):
```bash
# PostgreSQL
psql -h localhost -p 2345 -U myuser -d mydb

# SQL Server tools
sqlcmd -S localhost,3341 -U myuser -P mySecurePassword123!
```

### SSH Access (with custom root password):
```bash
ssh -p 2223 root@localhost
# Enter: myRootPassword456!
```

## Resetting Credentials

If you need to reset credentials after initialization:

1. Stop the container
2. Remove the data volume: `docker volume rm devcontainer_babelfish-data`
3. Update your .env file
4. Restart the DevContainer

## Default Credentials (if not customized)

- **Database User**: babelfish_admin
- **Database Password**: secret_password
- **Database Name**: babelfish_db
- **Root SSH Password**: postgres