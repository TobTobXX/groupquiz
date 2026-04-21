import SlotIcon from './SlotIcon'
import { SLOT_ICONS } from '../lib/slots'
import { useI18n } from '../context/I18nContext'

// Shown on the player screen after a question closes: result banner,
// slot feedback grid, and live leaderboard while waiting for next question.
export default function FeedbackView({ isCorrect, pointsEarned, slots, slotProps, leaderboard, playerId }) {
  const playerStreak = leaderboard.find(p => p.id === playerId)?.streak ?? 0
  const { t } = useI18n()

  return (
    <div className="w-full max-w-xl flex flex-col gap-4">
      {/* Result banner */}
      {isCorrect !== null ? (
        <div className={`rounded-xl px-6 py-4 text-center font-bold text-xl ${isCorrect ? 'bg-emerald-600' : 'bg-red-600'}`}>
          {isCorrect
            ? <>{t('feedback.correct', { points: pointsEarned })}{playerStreak >= 3 && <> 🔥<span className="text-orange-400 font-bold">{playerStreak}</span></>}</>
            : t('feedback.wrong')}
        </div>
      ) : (
        <div className="rounded-xl px-6 py-4 text-center font-bold text-xl bg-indigo-100 text-indigo-800">
          {t('feedback.didntAnswer')}
        </div>
      )}

      {/* Slot grid with correct/wrong highlights */}
      <div className="grid grid-cols-2 gap-3">
        {slots.map((slot) => {
          const { className, style } = slotProps(slot.slot_index)
          return (
            <div key={slot.slot_index} className={className} style={style}>
              <SlotIcon name={SLOT_ICONS[slot.slot_index]} />
            </div>
          )
        })}
      </div>

      {/* Leaderboard — player above, self, player below */}
      {leaderboard.length > 0 && (() => {
        const idx = leaderboard.findIndex(p => p.id === playerId)
        const visible = [idx - 1, idx, idx + 1].filter(i => i >= 0 && i < leaderboard.length)
        return (
          <div className="flex flex-col gap-2">
            {visible.map(i => {
              const p = leaderboard[i]
              return (
                <div
                  key={p.id}
                  className={`flex items-center gap-3 px-4 py-3 rounded-lg ${p.id === playerId ? 'bg-indigo-700 text-white' : 'bg-indigo-100'}`}
                >
                  <span className={`font-mono w-6 text-right ${p.id === playerId ? 'text-indigo-200' : 'text-gray-400'}`}>{i + 1}</span>
                  <span className="flex-1 font-semibold">{p.nickname}</span>
                  <span className={p.id === playerId ? 'text-indigo-100' : 'text-gray-700'}>{p.score}{(p.streak ?? 0) >= 3 && <> 🔥<span className="text-orange-400 font-bold">{p.streak}</span></>}</span>
                </div>
              )
            })}
          </div>
        )
      })()}

      <p className="text-gray-500 text-sm text-center">{t('feedback.waitingNext')}</p>
    </div>
  )
}
