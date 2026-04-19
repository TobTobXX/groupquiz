import { useState } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { useI18n } from '../context/I18nContext'

const MAX_VISIBLE_PLAYERS = 20

// Waiting room shown before the host starts the game.
export default function HostLobby({ joinCode, joinUrl, players, shuffleAnswers, onShuffleChange, showLeaderboard, onShowLeaderboardChange, loadingSlots, onStart }) {
  const [copied, setCopied] = useState(false)
  const { t } = useI18n()

  function copyCode() {
    navigator.clipboard.writeText(joinCode).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    })
  }

  const visiblePlayers = players.slice(0, MAX_VISIBLE_PLAYERS)
  const hiddenCount = players.length - visiblePlayers.length
  const domain = joinUrl ? new URL(joinUrl).host : ''

  return (
    <div className="w-full flex flex-col items-center gap-8 py-6">

      {/* ── Join instructions ── */}
      <div className="flex flex-col items-center gap-6 text-center">
        <div>
          <p className="text-gray-500 text-lg mb-1">
            {t('hostLobby.joinAt')} <span className="text-gray-900 font-semibold">{domain}</span>
          </p>
          <p className="text-gray-500 text-sm">{t('hostLobby.orEnterCode')}</p>
        </div>

        {/* Clickable join code */}
        <button
          onClick={copyCode}
          title="Click to copy"
          className="group relative flex flex-col items-center cursor-pointer select-none"
        >
          <span className={`text-8xl font-bold tracking-widest transition-colors ${copied ? 'text-green-500' : 'text-gray-900 group-hover:text-indigo-500'}`}>
            {copied ? 'Copied!' : joinCode}
          </span>
          <span className="text-xs text-gray-400 mt-1 group-hover:text-gray-500 transition-colors">
            {t('hostLobby.clickToCopy')}
          </span>
        </button>

        {/* QR code */}
        <div className="flex flex-col items-center gap-2">
          <div className="p-2 bg-white rounded-lg">
            <QRCodeSVG value={joinUrl} size={180} bgColor="#ffffff" fgColor="#0f172a" />
          </div>
          <a
            href={joinUrl}
            target="_blank"
            rel="noreferrer"
            className="text-sm text-indigo-600 hover:text-indigo-500 underline underline-offset-2 transition-colors"
          >
            {joinUrl}
          </a>
        </div>
      </div>

      {/* ── Controls ── */}
      <div className="flex flex-col items-center gap-3 w-full max-w-xs">
        <label className="flex items-center gap-2 text-gray-600 text-sm cursor-pointer select-none">
          <input
            type="checkbox"
            checked={shuffleAnswers}
            onChange={(e) => onShuffleChange(e.target.checked)}
            className="w-4 h-4 accent-indigo-500"
          />
          {t('hostLobby.shuffleAnswers')}
        </label>
        <label className="flex items-center gap-2 text-gray-600 text-sm cursor-pointer select-none">
          <input
            type="checkbox"
            checked={showLeaderboard}
            onChange={(e) => onShowLeaderboardChange(e.target.checked)}
            className="w-4 h-4 accent-indigo-500"
          />
          {t('hostLobby.showLeaderboard')}
        </label>
        <button
          onClick={onStart}
          disabled={loadingSlots}
          className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition-colors"
        >
          {loadingSlots
            ? t('hostLobby.starting')
            : t('hostLobby.startGame', { count: players.length, playerWord: t(players.length === 1 ? 'common.player' : 'common.players') })}
        </button>
      </div>

      {/* ── Player list ── */}
      <div className="flex flex-col items-center gap-3 w-full max-w-2xl">
        <div className="flex items-center gap-2 text-gray-500 text-sm">
          <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse inline-block" />
          {players.length === 0
            ? t('hostLobby.waitingForPlayers')
            : t('hostLobby.playersJoined', { count: players.length, playerWord: t(players.length === 1 ? 'common.player' : 'common.players') })}
        </div>
        {visiblePlayers.length > 0 && (
          <div className="flex flex-wrap justify-center gap-2">
            {visiblePlayers.map((p) => (
              <span
                key={p.id}
                className="px-3 py-1 bg-indigo-100 text-indigo-700 text-sm rounded-full"
              >
                {p.nickname}
              </span>
            ))}
            {hiddenCount > 0 && (
              <span className="px-3 py-1 bg-indigo-50 text-indigo-500 text-sm rounded-full">
                {t('hostLobby.andMore', { count: hiddenCount })}
              </span>
            )}
          </div>
        )}
      </div>

    </div>
  )
}
