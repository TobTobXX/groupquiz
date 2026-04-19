import { useSearchParams, Navigate } from 'react-router-dom'
import HostSession from '../components/HostSession'

export default function Host() {
  const [searchParams] = useSearchParams()
  const sessionId = searchParams.get('sessionId')
  if (!sessionId) return <Navigate to="/library" replace />
  return <HostSession key={sessionId} sessionId={sessionId} />
}
