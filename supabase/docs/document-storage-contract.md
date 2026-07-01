# Document Storage Contract

P0-BE-05 stores load documents in the private `load-documents` bucket. The
object key is owned by the `public.documents` metadata row and must use this
canonical path:

```text
{user_id}/{load_id}/{document_id}
```

Clients create or update the document metadata before uploading bytes. A
remotely available document must have:

- `load_id`
- `object_key`
- `sha256_hex`
- positive `byte_count`
- `uploaded_at`
- `sync_state = 'synced'`

The mobile app may upload directly to `load-documents` with the user's session
JWT only when the object path matches an owned document metadata row. Storage
policies intentionally do not allow listing or client-side signed URL creation.

To view a synced document, call the `document-signed-url` Edge Function:

```http
POST /functions/v1/document-signed-url
Authorization: Bearer <user access token>
Content-Type: application/json

{ "documentId": "00000000-0000-0000-0000-000000000000" }
```

The function validates ownership through the caller's JWT and RLS, then returns
a signed Storage URL that expires in 300 seconds.
