import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

function generateJoinCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  let code = ''
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)]
  }
  return code
}

export default function Host() {
  const [quizzes, setQuizzes] = useState([])
  const [joinCode, setJoinCode] = useState(null)
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase
      .from('quizzes')
      .select('id, title')
      .then(({ data, error }) => {
        if (error) setError(error.message)
        else setQuizzes(data)
        setLoading(false)
      })
  }, [])

  async function createSession(quizId) {
    const code = generateJoinCode()
    const { error } = await supabase
      .from('sessions')
      .insert({ quiz_id: quizId, join_code: code, state: 'waiting' })
    if (error) {
      setError(error.message)
    } else {
      setJoinCode(code)
    }
  }

  return (
    <div>
      <h1>Host</h1>
      {loading && <p>Loading quizzes...</p>}
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {joinCode ? (
        <div>
          <p>Join code:</p>
          <strong style={{ fontSize: '2rem' }}>{joinCode}</strong>
          <p>Waiting for players...</p>
        </div>
      ) : (
        <ul>
          {quizzes.map((quiz) => (
            <li key={quiz.id}>
              {quiz.title}{' '}
              <button onClick={() => createSession(quiz.id)}>
                Create session
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
