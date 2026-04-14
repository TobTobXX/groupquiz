import encode from '@jsquash/jxl/encode'

const MAX_WIDTH = 1500
const MAX_HEIGHT = 1000

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
 * encodes it as JPEG-XL, uploads it to the 'images' Supabase bucket, and
 * returns the public URL.
 *
 * Path: {userId}/{questionId}.jxl — uploading again overwrites the previous
 * version (upsert: true).
 *
 * @param {import('@supabase/supabase-js').SupabaseClient} supabase
 * @param {File} file  — any browser-readable image file
 * @param {string} userId
 * @param {string} questionId
 * @returns {Promise<string>} public URL of the uploaded image
 */
export async function processAndUploadImage(supabase, file, userId, questionId) {
  const img = await loadImage(file)

  const { w, h } = scaledDimensions(img.naturalWidth, img.naturalHeight)

  const canvas = document.createElement('canvas')
  canvas.width = w
  canvas.height = h
  const ctx = canvas.getContext('2d')
  ctx.drawImage(img, 0, 0, w, h)

  const imageData = ctx.getImageData(0, 0, w, h)
  const jxlBuffer = await encode(imageData)

  const path = `${userId}/${questionId}.jxl`
  const { error } = await supabase.storage
    .from('images')
    .upload(path, jxlBuffer, {
      contentType: 'image/jxl',
      upsert: true,
    })

  if (error) throw new Error(error.message)

  const { data } = supabase.storage.from('images').getPublicUrl(path)
  return data.publicUrl
}
