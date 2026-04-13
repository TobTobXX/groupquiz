import { copyFileSync, readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const distDir = resolve(__dirname, '../dist')

const routes = ['login', 'host', 'join', 'play', 'create', 'edit', 'library']

const indexHtml = readFileSync(resolve(distDir, 'index.html'), 'utf-8')

for (const route of routes) {
  const dest = resolve(distDir, `${route}.html`)
  mkdirSync(dirname(dest), { recursive: true })
  writeFileSync(dest, indexHtml)
  console.log(`Created ${route}.html`)
}

// 404.html - preserves original URL for redirect
const notFoundHtml = indexHtml.replace(
  '</body>',
  `<script>
    sessionStorage.setItem('redirect', location.pathname + location.search);
  </script></body>`
)
writeFileSync(resolve(distDir, '404.html'), notFoundHtml)
console.log('Created 404.html')
