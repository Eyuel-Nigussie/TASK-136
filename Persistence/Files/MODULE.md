# Persistence / Files

Responsibilities (design.md §11.3, §16):

- Sandbox path helpers: `Documents/attachments/{tenantId}/…`, `Caches/debug-log`,
  `Caches/attachment-thumbs`.
- File protection class assignment per directory.
- Ownership checks so repositories cannot escape `tenantId` boundary via path traversal.

Files to be added in Step 2:

- `CMFileLocations.{h,m}`
- `CMFileProtection.{h,m}`
