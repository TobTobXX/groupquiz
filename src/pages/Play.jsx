import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export default function Play() {
  const { code } = useParams()
  const [nickname, setNickname] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function load() {
      const { data: session, error: sessionError } = await supabase
        .from('sessions')
        .select('id')
        .eq('join_code', code)
        .single()

      if (sessionError || !session) {
        setError('Session not found')
        return
      }

      const playerId = localStorage.getItem('player_id')
      if (!playerId) {
        setError('Player not found — did you join via the home page?')
        return
      }

      const { data: player, error: playerError } = await supabase
        .from('players')
        .select('nickname')
        .eq('id', playerId)
        .single()

      if (playerError || !player) {
        setError('Could not load player info')
        return
      }

      setNickname(player.nickname)
    }

    load()
  }, [code])

  if (error) return <p style={{ color: 'red' }}>{error}</p>
  if (!nickname) return <p>Loading...</p>

  return (
    <div>
      <p>Playing as <strong>{nickname}</strong></p>
      <p>Waiting for the host to start...</p>
    </div>
  )
}
