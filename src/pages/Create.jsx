import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import QuestionEditor from '../components/QuestionEditor'

function blankQuestion() {
  return {
    id: crypto.randomUUID(),
    question_text: '',
    time_limit: 30,
    points: 1000,
    image_url: '',
    answers: [
      { id: crypto.randomUUID(), answer_text: '', is_correct: true },
      { id: crypto.randomUUID(), answer_text: '', is_correct: false },
    ],
  }
}

export default function Create() {
  const navigate = useNavigate()
  const [title, setTitle] = useState('')
  const [questions, setQuestions] = useState([blankQuestion()])
  const [saving, setSaving] = useState(false)
  const [errors, setErrors] = useState({})

  function updateQuestion(index, updated) {
    setQuestions((qs) => qs.map((q, i) => (i === index ? updated : q)))
  }

  function deleteQuestion(index) {
    setQuestions((qs) => qs.filter((_, i) => i !== index))
  }

  function addQuestion() {
    setQuestions((qs) => [...qs, blankQuestion()])
  }

  function validate() {
    const errs = {}
    if (!title.trim()) errs.title = 'Quiz title is required'
    questions.forEach((q, i) => {
      if (!q.question_text.trim()) errs[`q${i}_text`] = 'Question text is required'
      const filledAnswers = q.answers.filter((a) => a.answer_text.trim())
      if (filledAnswers.length < 2) errs[`q${i}_answers`] = 'At least 2 answer options required'
      if (!q.answers.some((a) => a.is_correct)) errs[`q${i}_correct`] = 'Mark at least one correct answer'
    })
    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  async function handleSave() {
    if (!validate()) return
    setSaving(true)

    const { data: quiz, error: quizError } = await supabase
      .from('quizzes')
      .insert({ title: title.trim() })
      .select('id')
      .single()

    if (quizError || !quiz) {
      setErrors({ submit: quizError?.message ?? 'Failed to create quiz' })
      setSaving(false)
      return
    }

    const questionInserts = questions.map((q, i) => ({
      quiz_id: quiz.id,
      order_index: i,
      question_text: q.question_text.trim(),
      time_limit: q.time_limit,
      points: q.points,
      image_url: q.image_url.trim() || null,
    }))

    const { data: insertedQuestions, error: qError } = await supabase
      .from('questions')
      .insert(questionInserts)
      .select('id, order_index')

    if (qError || !insertedQuestions) {
      setErrors({ submit: qError?.message ?? 'Failed to save questions' })
      setSaving(false)
      return
    }

    const answerInserts = []
    insertedQuestions.forEach((iq) => {
      const orig = questions[iq.order_index]
      orig.answers.forEach((a, ai) => {
        answerInserts.push({
          question_id: iq.id,
          order_index: ai,
          answer_text: a.answer_text.trim(),
          is_correct: a.is_correct,
        })
      })
    })

    const { error: aError } = await supabase.from('answers').insert(answerInserts)

    if (aError) {
      setErrors({ submit: aError.message ?? 'Failed to save answers' })
      setSaving(false)
      return
    }

    navigate('/host')
  }

  return (
    <div className="min-h-screen bg-slate-900">
      <div className="max-w-2xl mx-auto px-4 py-8 flex flex-col gap-6">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold">Create Quiz</h1>
          <button
            type="button"
            onClick={() => navigate('/host')}
            className="text-slate-400 hover:text-white transition-colors text-sm"
          >
            Cancel
          </button>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm text-slate-400 font-medium">Quiz title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full bg-slate-800 border border-slate-600 rounded-lg px-4 py-3 text-white text-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
            placeholder="My awesome quiz"
          />
          {errors.title && <p className="text-red-400 text-sm">{errors.title}</p>}
        </div>

        <div className="flex flex-col gap-4">
          {questions.map((q, i) => (
            <div key={q.id}>
              <QuestionEditor
                index={i}
                question={q}
                onChange={(updated) => updateQuestion(i, updated)}
                onDelete={() => deleteQuestion(i)}
              />
              {(errors[`q${i}_text`] || errors[`q${i}_answers`] || errors[`q${i}_correct`]) && (
                <div className="mt-1 flex flex-col gap-0.5">
                  {errors[`q${i}_text`] && <p className="text-red-400 text-sm">{errors[`q${i}_text`]}</p>}
                  {errors[`q${i}_answers`] && <p className="text-red-400 text-sm">{errors[`q${i}_answers`]}</p>}
                  {errors[`q${i}_correct`] && <p className="text-red-400 text-sm">{errors[`q${i}_correct`]}</p>}
                </div>
              )}
            </div>
          ))}
        </div>

        <button
          type="button"
          onClick={addQuestion}
          className="w-full border-2 border-dashed border-slate-600 hover:border-slate-400 text-slate-400 hover:text-slate-300 rounded-xl py-4 transition-colors font-medium"
        >
          + Add question
        </button>

        {errors.submit && (
          <p className="text-red-400 text-sm">{errors.submit}</p>
        )}

        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition-colors"
        >
          {saving ? 'Saving…' : 'Save quiz'}
        </button>
      </div>
    </div>
  )
}
