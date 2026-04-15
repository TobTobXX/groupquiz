const MAX_WIDTH = 1500
const MAX_HEIGHT = 1000
const JPEG_QUALITY = 0.85

/**
 * Scales `width` × `height` down so neither dimension exceeds its limit,
 * preserving aspect ratio. Returns the target dimensions unchanged if they
 * already fit.
 */
function scaledDimensions(width, height) {
  const scaleW = width > MAX_WIDTH ? MAX_WIDTH / width : 1
  const scaleH = height > MAX_HEIGHT ? MAX_HEIGHT / height : 1
  const scale = Math.min(scaleW, scaleH)
  return { w: Math.round(width * scale), h: Math.round(height * scale) }
}

/**
 * Loads a File/Blob into an HTMLImageElement and returns it.
 */
function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('Could not load image'))
    }
    img.src = url
  })
}

/**
 * Given an image File, resizes it to fit within MAX_WIDTH × MAX_HEIGHT,
 * encodes it as JPEG, uploads it to the 'images' Supabase bucket, and
 * returns the public URL.
 *
 * Path: {userId}/{questionId}.jpg — uploading again overwrites the previous
 * version (upsert: true).
 *
 * @param {import('@supabase/supabase-js').SupabaseClient} supabase
 * @param {File} file  — any browser-readable image file
 * @param {string} userId
 * @param {string} questionId
 * @returns {Promise<string>} public URL of the uploaded image
 */
const SMALL_JPEG_THRESHOLD = 150 * 1024 // 150 KiB

export async function processAndUploadImage(supabase, file, userId, questionId) {
  const path = `${userId}/${questionId}.jpg`

  console.log('[image] Processing image…')
  const img = await loadImage(file)

  let blob
  if (
    file.type === 'image/jpeg' &&
    file.size < SMALL_JPEG_THRESHOLD &&
    img.naturalWidth <= MAX_WIDTH &&
    img.naturalHeight <= MAX_HEIGHT
  ) {
    console.log('[image] Small JPEG within dimensions — skipping transform, uploading as-is…')
    blob = file
  } else {
    const { w, h } = scaledDimensions(img.naturalWidth, img.naturalHeight)
    console.log(`[image] Resizing to ${w}×${h} and encoding as JPEG…`)

    const canvas = document.createElement('canvas')
    canvas.width = w
    canvas.height = h
    canvas.getContext('2d').drawImage(img, 0, 0, w, h)

    blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', JPEG_QUALITY))
  }

  console.log(`[image] Uploading to storage (${(blob.size / 1024).toFixed(1)} KiB)…`)
  const { error } = await supabase.storage
    .from('images')
    .upload(path, blob, {
      contentType: 'image/jpeg',
      upsert: true,
    })

  if (error) throw new Error(error.message)

  const { data } = supabase.storage.from('images').getPublicUrl(path)
  console.log('[image] Upload complete')
  return data.publicUrl
}
