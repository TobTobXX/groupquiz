// Shared icon used to represent answer slots on both the host and player screens.
// The four shapes (circle, diamond, triangle, square) map 1:1 to the four slot positions.
export default function SlotIcon({ name, className, size = 40 }) {
  const fill = 'currentColor'
  if (name === 'circle') {
    return <svg width={size} height={size} viewBox="0 0 40 40" className={className}><circle cx="20" cy="20" r="18" fill={fill} /></svg>
  }
  if (name === 'diamond') {
    return <svg width={size} height={size} viewBox="0 0 40 40" className={className}><rect x="7" y="7" width="26" height="26" rx="2" transform="rotate(45 20 20)" fill={fill} /></svg>
  }
  if (name === 'triangle') {
    return <svg width={size} height={size} viewBox="0 0 40 40" className={className}><path d="M 21.5,6.6 L 36.5,33.4 Q 38,36 35,36 L 5,36 Q 2,36 3.5,33.4 L 18.5,6.6 Q 20,4 21.5,6.6 Z" fill={fill} /></svg>
  }
  if (name === 'square') {
    return <svg width={size} height={size} viewBox="0 0 40 40" className={className}><rect width="36" height="36" x="2" y="2" rx="2" fill={fill} /></svg>
  }
  return null
}
