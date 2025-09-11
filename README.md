# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

## File Uploads (Active Storage) – Heroku + S3

This app uses Active Storage for user document uploads and background jobs to optimize large images.

### 1) AWS S3 Bucket
- Create a bucket (e.g. `qcare-user-uploads`), keep public access blocked.
- Optional CORS (for future direct uploads):
  ```json
  [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedOrigins": ["https://www.qcare.au", "https://<HEROKU_APP>.herokuapp.com", "http://localhost:3000"],
      "ExposeHeaders": ["ETag"]
    }
  ]
  ```

### 2) IAM User + Policy
Create user `qcare-active-storage` (programmatic) and attach this policy (replace bucket name if different):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": "arn:aws:s3:::qcare-user-uploads"
    },
    {
      "Sid": "S3ObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::qcare-user-uploads/*"
    }
  ]
}
```

### 3) Heroku config vars
```
heroku config:set ACTIVE_STORAGE_SERVICE=amazon_env --app <HEROKU_APP>
heroku config:set AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... --app <HEROKU_APP>
heroku config:set AWS_REGION=ap-southeast-2 AWS_BUCKET=qcare-user-uploads --app <HEROKU_APP>
heroku config:set APP_HOST=www.qcare.au --app <HEROKU_APP>
```

### 4) ImageMagick on Heroku (for optimization)
- Add apt buildpack before Ruby:
```
heroku buildpacks:add --index 1 heroku-community/apt --app <HEROKU_APP>
```
- `Aptfile` at repo root contains:
```
imagemagick
```
- Deploy, then verify:
```
heroku run --app <HEROKU_APP> -- bash -c "identify -version"
```

### 5) Background jobs
Scale worker dyno so optimization jobs run:
```
heroku ps:scale worker=1 --app <HEROKU_APP>
```

### 6) Upload limits and security
- Allowed types: JPEG/PNG/WEBP/HEIC/HEIF and PDF
- Max size: 12 MB per file
- Large images auto-resized to a max dimension of ~2000px and JPEGs recompressed

### 7) Verifying
After deploy, upload a file on a user profile. It should attach, then be optimized by the worker. Files are stored in S3 and served via signed URLs.
