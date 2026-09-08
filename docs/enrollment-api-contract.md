# Enrollment API Contract

The Flutter app never receives or stores a Google service-account key. The backend owns Android Management API authentication.

## Create enterprise

`POST /apk/management/enterprise`

Request:

```json
{
  "displayName": "SmartPay Mobile Seller"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "enterpriseName": "enterprises/example"
  }
}
```

## Create enrollment token

`POST /apk/management/enrollment-token`

Request:

```json
{
  "enterpriseName": "enterprises/example",
  "sellerId": "seller-123"
}
```

Response:

```json
{
  "success": true,
  "data": {
    "qrCode": "{\"android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME\":\"...\"}"
  }
}
```

The `qrCode` value is the raw provisioning payload returned by Android Management API. Flutter renders it; it must not be replaced with a screenshot URL.

Both endpoints must return a non-2xx response with a JSON error when creation fails. The backend must store the service-account key in server-side secret storage only.