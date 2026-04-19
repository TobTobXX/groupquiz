import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import Header from '../components/Header'
import { useI18n } from '../context/I18nContext'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [mode, setMode] = useState('signin')
  const [magicLink, setMagicLink] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [sent, setSent] = useState(null)
  const { t } = useI18n()

  async function handleSubmit(e) {
    e.preventDefault()
    setError(null)
    setSent(null)
    setLoading(true)

    if (magicLink) {
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: { emailRedirectTo: window.location.origin + '/host' },
      })
      setLoading(false)
      if (error) setError(error.message)
      else setSent(t('login.magicLinkSent'))
      return
    }

    if (mode === 'signin') {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      setLoading(false)
      if (error) setError(error.message)
      else navigate('/host')
    } else {
      const { error } = await supabase.auth.signUp({ email, password })
      setLoading(false)
      if (error) setError(error.message)
      else {
        setSent(t('login.accountCreated'))
        setMode('signin')
      }
    }
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <div className="flex-1 flex items-center justify-center px-4">
        <div className="w-full max-w-sm bg-white border border-gray-200 rounded-2xl shadow-xl p-8 flex flex-col gap-6">
          <div className="text-center">
            <h1 className="text-2xl font-bold">{t('login.welcome')}</h1>
          <p className="text-gray-500 text-sm mt-1">
            {mode === 'signin' ? t('login.signInSubtitle') : t('login.signUpSubtitle')}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1">
            <label className="text-sm text-gray-500">{t('login.email')}</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
              placeholder="you@example.com"
              required
            />
          </div>

          {!magicLink && (
            <div className="flex flex-col gap-1">
              <label className="text-sm text-gray-500">{t('login.password')}</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                placeholder="••••••••"
                required
              />
            </div>
          )}

          {error && <p className="text-red-400 text-sm">{error}</p>}
          {sent && <p className="text-emerald-400 text-sm">{sent}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition-colors"
          >
            {loading
              ? t('login.pleaseWait')
              : magicLink
              ? t('login.sendMagicLink')
              : mode === 'signin'
              ? t('login.signIn')
              : t('login.createAccount')}
          </button>
        </form>

        {!magicLink && (
          <button
            type="button"
            onClick={() => setMode(mode === 'signin' ? 'signup' : 'signin')}
            className="text-center text-sm text-gray-500 hover:text-gray-700 transition-colors"
          >
            {mode === 'signin' ? t('login.noAccount') : t('login.haveAccount')}
          </button>
        )}

        {!sent && (
          <button
            type="button"
            onClick={() => setMagicLink((v) => !v)}
            className="text-center text-sm text-indigo-600 hover:text-indigo-500 transition-colors"
          >
            {magicLink ? t('login.usePassword') : t('login.signInMagicLink')}
          </button>
        )}
        </div>
      </div>
    </div>
  )
}
