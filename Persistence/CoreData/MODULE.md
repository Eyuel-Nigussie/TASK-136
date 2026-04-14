# Persistence / CoreData

Responsibilities (design.md §2.3, §3, §7.3, questions.md Q7):

- `NSPersistentContainer` bootstrap with two stores:
  - Main store `CourierMatch.sqlite` — `NSFileProtectionComplete`.
  - Sidecar store `work.sqlite` — `NSFileProtectionCompleteUntilFirstUserAuthentication` (Q7).
- `viewContext` on main; background writes via `performBackgroundTask:`.
- Merge policy `NSErrorMergePolicy` to surface uniqueness conflicts.
- Field-level AES-GCM encryption hook for flagged transformable columns.
- TenantContext scoping — every repository fetch includes `tenantId` predicate.

Files to be added in Step 2:

- `CMCoreDataStack.{h,m}`
- `CMManagedObjectContext+CMHelpers.{h,m}`
- `CMEncryptedValueTransformer.{h,m}`
- `CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents`
