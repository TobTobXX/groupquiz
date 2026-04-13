import SlotIcon from './SlotIcon'
import { SLOT_COLOR_HEX } from '../lib/slots'

// Shown during an active question: question text, countdown, slot grid,
// answer progress, and host controls.
export default function HostActiveQuestion({
  question,
  currentQuestionIndex,
  totalQuestions,
  timeRemaining,
  questionOpen,
  slots,
  answerCount,
  playerCount,
  loadingSlots,
  onClose,
  onNext,
  onEnd,
}) {
  return (
    <div className="flex flex-col items-center gap-4 w-full">
      <p className="text-slate-300 text-sm">
        Question <span className="text-white font-bold">{currentQuestionIndex + 1}</span> / {totalQuestions}
      </p>

      {question && (
        <p className="text-2xl font-bold text-center leading-snug px-2">
          {question.question_text}
        </p>
      )}

      {timeRemaining !== null && (
        <div className="text-6xl font-bold text-white tabular-nums">
          {timeRemaining}
        </div>
      )}

      {slots && (
        <div className="w-full grid grid-cols-2 gap-3">
          {slots.map((slot) => {
            const answer = question?.answers?.find((a) => a.id === slot.answer_id)
            return (
              <div
                key={slot.slot_index}
                className="flex items-center gap-3 p-3 rounded-xl min-h-20"
                style={{ backgroundColor: SLOT_COLOR_HEX[slot.color] }}
              >
                <SlotIcon name={slot.icon} className="text-white flex-shrink-0" />
                <span className="text-white font-semibold text-center flex-1 leading-tight">
                  {answer?.answer_text ?? ''}
                </span>
              </div>
            )
          })}
        </div>
      )}

      <p className="text-slate-400 text-sm">
        {questionOpen
          ? `${answerCount} / ${playerCount} answered`
          : 'Results shown'}
      </p>
      <button
        onClick={onClose}
        disabled={!questionOpen}
        className="w-full bg-amber-600 hover:bg-amber-500 disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition-colors"
      >
        Close question
      </button>
      <button
        onClick={onNext}
        disabled={currentQuestionIndex >= totalQuestions - 1 || loadingSlots}
        className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-3 rounded-lg transition-colors"
      >
        {loadingSlots ? 'Loading…' : 'Next question'}
      </button>
      <button
        onClick={onEnd}
        className="w-full bg-slate-600 hover:bg-slate-500 text-white font-semibold py-2 rounded-lg transition-colors"
      >
        End game
      </button>
    </div>
  )
}
