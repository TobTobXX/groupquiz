import { createClient } from 'jsr:@supabase/supabase-js@2'

const BUCKET = 'images'
const BATCH_SIZE = 100

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // 1. Enumerate all storage objects (two-level: {userId}/{hash}.jpg)
  const { data: folders, error: foldersErr } = await supabase.storage
    .from(BUCKET)
    .list()
  if (foldersErr) {
    console.error('[sweep] Failed to list bucket root:', foldersErr.message)
    return new Response(foldersErr.message, { status: 500 })
  }

  const storagePaths: string[] = []
  for (const folder of folders ?? []) {
    const { data: files, error: filesErr } = await supabase.storage
      .from(BUCKET)
      .list(folder.name)
    if (filesErr) {
      console.error(`[sweep] Failed to list folder ${folder.name}:`, filesErr.message)
      continue
    }
    for (const file of files ?? []) {
      storagePaths.push(`${folder.name}/${file.name}`)
    }
  }

  console.log(`[sweep] Found ${storagePaths.length} object(s) in bucket`)

  // 2. Fetch all image URLs currently referenced by questions
  const { data: rows, error: dbErr } = await supabase
    .from('questions')
    .select('image_url')
    .not('image_url', 'is', null)
  if (dbErr) {
    console.error('[sweep] Failed to query questions:', dbErr.message)
    return new Response(dbErr.message, { status: 500 })
  }

  // 3. Convert public URLs → storage paths by stripping the known prefix
  const urlPrefix =
    `${Deno.env.get('SUPABASE_URL')}/storage/v1/object/public/${BUCKET}/`
  const referencedPaths = new Set(
    (rows ?? [])
      .map((r) => r.image_url as string)
      .filter((url) => url.startsWith(urlPrefix))
      .map((url) => url.slice(urlPrefix.length)),
  )

  console.log(`[sweep] ${referencedPaths.size} path(s) referenced by questions`)

  // 4. Orphans = in storage but not referenced
  const orphans = storagePaths.filter((p) => !referencedPaths.has(p))
  console.log(`[sweep] ${orphans.length} orphan(s) to delete`)

  // 5. Delete in batches
  let deleted = 0
  for (let i = 0; i < orphans.length; i += BATCH_SIZE) {
    const batch = orphans.slice(i, i + BATCH_SIZE)
    const { error } = await supabase.storage.from(BUCKET).remove(batch)
    if (error) {
      console.error('[sweep] Batch delete error:', error.message)
    } else {
      deleted += batch.length
    }
  }

  const result = { scanned: storagePaths.length, referenced: referencedPaths.size, deleted }
  console.log('[sweep] Done:', result)
  return new Response(JSON.stringify(result), {
    headers: { 'Content-Type': 'application/json' },
  })
})
