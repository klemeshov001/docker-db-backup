# S3 Backup with Yandex CLI Integration

This example demonstrates how to use the docker-db-backup container with Yandex Cloud Lockbox integration using Yandex CLI (yc) for authentication.

## Features

- **Yandex CLI Authentication**: Uses `yc iam create-token` for IAM token generation
- **Automatic Profile Management**: Creates and configures Yandex CLI profiles automatically
- **Lockbox Integration**: Retrieves secrets using `yc lockbox payload get`
- **S3 Storage**: Stores backups in Yandex Object Storage
- **PostgreSQL Support**: Backs up PostgreSQL databases

## Prerequisites

1. **Yandex CLI Installation**: The container must have Yandex CLI (yc) installed
2. **Service Account Key**: A valid service account key file (`authorized_key.json`)
3. **Lockbox Secrets**: Configured secrets in Yandex Cloud Lockbox
4. **S3 Bucket**: A configured S3 bucket in Yandex Object Storage

## Configuration

### Environment Variables

#### Yandex Lockbox Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `YANDEX_LOCKBOX_SECRET_IDS` | Comma-separated list of Lockbox secret IDs | Required |
| `YANDEX_LOCKBOX_AUTH_TYPE` | Authentication method (`metadata` or `yc-cli`) | `yc-cli` |
| `YANDEX_LOCKBOX_METADATA_URL` | Metadata service URL for IAM token | `http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token` |
| `YANDEX_LOCKBOX_API_URL` | Lockbox API endpoint | `https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets` |
| `DEBUG_YANDEX_LOCKBOX` | Enable debug logging for Lockbox operations | `TRUE` |

#### Yandex CLI Configuration (for yc-cli auth type)

| Variable | Description | Default |
|----------|-------------|---------|
| `YANDEX_LOCKBOX_YC_PROFILE` | Yandex CLI profile name | `backup-service` |
| `YANDEX_LOCKBOX_YC_SERVICE_ACCOUNT_KEY` | Path to service account key file | `/config/authorized_key.json` |
| `YANDEX_LOCKBOX_YC_CLOUD_ID` | Yandex Cloud ID | Required |
| `YANDEX_LOCKBOX_YC_FOLDER_ID` | Yandex Cloud Folder ID | Required |

### Service Account Setup

1. Create a service account in Yandex Cloud Console
2. Assign necessary roles:
   - `lockbox.payloadViewer` - to read Lockbox secrets
   - `storage.editor` - to write to S3 bucket
3. Create a service account key and save it as `authorized_key.json`

### Lockbox Secrets

Create secrets in Yandex Cloud Lockbox with the following structure:

**Secret 1 (Database credentials):**
```json
{
  "DB01_PASS": "your_database_password"
}
```

**Secret 2 (S3 credentials):**
```json
{
  "DEFAULT_S3_ACCESS_KEY": "your_s3_access_key",
  "DEFAULT_S3_SECRET_KEY": "your_s3_secret_key"
}
```

## Usage

1. **Prepare the service account key:**
   ```bash
   cp /path/to/your/service-account-key.json authorized_key.json
   ```

2. **Configure environment variables:**
   ```bash
   export S3_BUCKET=your-backup-bucket
   export S3_PATH=backups/production
   export YANDEX_LOCKBOX_SECRET_IDS=secret1-id,secret2-id
   export YANDEX_LOCKBOX_YC_CLOUD_ID=your-cloud-id
   export YANDEX_LOCKBOX_YC_FOLDER_ID=your-folder-id
   ```

3. **Start the services:**
   ```bash
   docker-compose up -d
   ```

## How It Works

1. **Profile Creation**: The container automatically creates a Yandex CLI profile named `backup-service`
2. **Configuration Setup**: Sets the service account key, cloud-id, and folder-id for the profile
3. **Token Generation**: Uses `yc iam create-token` to get IAM tokens
4. **Secret Retrieval**: Uses `yc lockbox payload get` to retrieve secrets from Lockbox
5. **Backup Execution**: Performs database backups and uploads to S3

## Advantages of Yandex CLI

- **Simplified Authentication**: No need to manually create JWT tokens
- **Automatic Token Management**: Yandex CLI handles token refresh automatically
- **Profile Management**: Easy switching between different service accounts
- **Built-in Error Handling**: Better error messages and debugging
- **Native Integration**: Uses official Yandex Cloud tools

## Troubleshooting

### Common Issues

1. **Yandex CLI not found**: Ensure `yc` is installed in the container
2. **Profile creation failed**: Check service account key file permissions
3. **Token generation failed**: Verify service account has necessary roles
4. **Secret retrieval failed**: Check Lockbox secret IDs and permissions

### Debug Mode

Enable debug mode for detailed logging:
```bash
export DEBUG_YANDEX_LOCKBOX=TRUE
```

### Testing Connectivity

The container includes built-in connectivity tests:
```bash
docker exec db-backup-s3-yc-cli test_yandex_lockbox_connectivity
```

## Security Considerations

- Store service account keys securely
- Use least-privilege access for service accounts
- Regularly rotate service account keys
- Monitor Lockbox access logs
- Use network policies to restrict container access
