# CourierMatch iOS — API Specification

## No External APIs

This is a **fully offline, standalone iOS application**. There are:

- No REST APIs
- No HTTP endpoints
- No server connections
- No WebSocket channels
- No third-party service integrations
- No backend server

All data is stored on-device using Core Data. All computation (matching, scoring, auditing, authentication) runs locally on the device. The application does not make any network requests.

## Data Persistence

- **Database**: Core Data (SQLite on-device)
- **Secrets**: iOS Keychain
- **Files**: App sandbox (`Documents/attachments/`)
- **Encryption**: AES-256-CBC + HMAC-SHA256 for sensitive fields

## Authentication

- Local username + password (no server auth)
- Optional Face ID / Touch ID (device-local biometrics)
- Session managed entirely in-memory + Keychain
