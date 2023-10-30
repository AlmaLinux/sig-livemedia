# Infrastructrue of AlmaLinux LiveMedia pipeline

Ideas:

1. Create a storage to store build artifacts.
2. Create a bot user to be used by job to upload the build artifacts to the storage.
3. Make sure bot account is confined within accessing only to this storage.
4. Make the uploaded artifacts publicly available for download.
5. Make sure to get optimal download speed from different continents (Asia, Australia, Europe, North America and South America etc.)

Implementations:

1. Create a S3 bucket on AWS with `almalinux-live` name.
2. Create an IAM user on AWS for `almalinux-livemedia-bot` bot account.
3. Write a S3 bucket policy to give`s3:GetObject` permission to objects for download.
4. Write a S3 bucket policy to give `almalinux-livemedia-bot` full access to `almalinux-live` bucket.
5. Use Amazon S3 Transfer Acceleration feature of AWS S3. See: http://s3-accelerate-speedtest.s3-accelerate.amazonaws.com/en/accelerate-speed-comparsion.html for comparison

Infrastructure as Code:

Create a terraform workspace for environment:

```sh
terraform workspace new production
```

Use the example file to set variables

```sh
cp terraform.tfvars.example ci/ci/infra/terraform.tfvars
```

Initialize project

```sh
terraform init -upgrade
```

Deploy

```sh
terraform apply
```

Decrypt Secret Access Key of `almalinux-livemedia-bot` AWS user

```sh
terraform output -raw livemedia_user_secret_key | base64 --decode | gpg --decrypt
```
