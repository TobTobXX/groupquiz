import { useParams } from 'react-router-dom'
import HostLobby from '../components/HostLobby'
import HostSession from '../components/HostSession'

// Routes to the lobby (quiz picker) or the live session view depending on the URL.
export default function Host() {
  const { sessionId } = useParams()
  return sessionId ? <HostSession sessionId={sessionId} /> : <HostLobby />
}
