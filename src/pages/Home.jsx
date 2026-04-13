import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export default function Home() {
  const [code, setCode] = useState('')
  const [nickname, setNickname] = useState('')
  const [error, setError] = useState(null)
  const navigate = useNavigate()

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)

    const { data: session, error: sessionError } = await supabase
      .from('sessions')
      .select('id')
      .eq('join_code', code)
      .eq('state', 'waiting')
      .single()

    if (sessionError || !session) {
      setError('Session not found or already started')
      return
    }

    const { data: player, error: playerError } = await supabase
      .from('players')
      .insert({ session_id: session.id, nickname })
      .select('id')
      .single()

    if (playerError) {
      setError(playerError.message)
      return
    }

    localStorage.setItem('player_id', player.id)
    navigate(`/play/${code}`)
  }

  return (
    <div>
      <h1>Join a game</h1>
      <form onSubmit={handleSubmit}>
        <div>
          <label>
            Join code
            <input
              type="text"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              required
            />
          </label>
        </div>
        <div>
          <label>
            Nickname
            <input
              type="text"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              required
            />
          </label>
        </div>
        {error && <p style={{ color: 'red' }}>{error}</p>}
        <button type="submit">Join</button>
      </form>
    </div>
  )
}
