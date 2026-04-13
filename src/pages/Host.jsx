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
  const [sessionId, setSessionId] = useState(null)
  const [quizId, setQuizId] = useState(null)
  const [sessionState, setSessionState] = useState('waiting')
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0)
  const [totalQuestions, setTotalQuestions] = useState(0)
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

  async function createSession(selectedQuizId) {
    const code = generateJoinCode()
    const { data, error } = await supabase
      .from('sessions')
      .insert({ quiz_id: selectedQuizId, join_code: code, state: 'waiting' })
      .select('id')
      .single()
    if (error) {
      setError(error.message)
    } else {
      setJoinCode(code)
      setSessionId(data.id)
      setQuizId(selectedQuizId)
    }
  }

  async function startGame() {
    const { count, error: countError } = await supabase
      .from('questions')
      .select('id', { count: 'exact', head: true })
      .eq('quiz_id', quizId)
    if (countError) { setError(countError.message); return }

    const { error } = await supabase
      .from('sessions')
      .update({ state: 'active', current_question_index: 0 })
      .eq('id', sessionId)
    if (error) { setError(error.message); return }

    setTotalQuestions(count)
    setCurrentQuestionIndex(0)
    setSessionState('active')
  }

  async function nextQuestion() {
    const next = currentQuestionIndex + 1
    const { error } = await supabase
      .from('sessions')
      .update({ current_question_index: next })
      .eq('id', sessionId)
    if (error) { setError(error.message); return }
    setCurrentQuestionIndex(next)
  }

  async function endGame() {
    const { error } = await supabase
      .from('sessions')
      .update({ state: 'finished' })
      .eq('id', sessionId)
    if (error) { setError(error.message); return }
    setSessionState('finished')
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
          {sessionState === 'waiting' && (
            <>
              <p>Waiting for players...</p>
              <button onClick={startGame}>Start game</button>
            </>
          )}
          {sessionState === 'active' && (
            <>
              <p>Question {currentQuestionIndex + 1} / {totalQuestions}</p>
              <button onClick={nextQuestion} disabled={currentQuestionIndex >= totalQuestions - 1}>
                Next question
              </button>
              {' '}
              <button onClick={endGame}>End game</button>
            </>
          )}
          {sessionState === 'finished' && <p>Game over.</p>}
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
