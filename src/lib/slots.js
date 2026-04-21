// Slot colors indexed by slot_index (0=red, 1=blue, 2=yellow, 3=green).
// Used by both the host and player screens via inline styles so the colors
// are always guaranteed to match exactly.
export const SLOT_COLORS = ['#FF4949', '#2D7DD2', '#E6A500', '#2ECC71']

// Slot icon names indexed by slot_index. Icons are derived client-side because
// session_questions.slots only stores {slot_index, answer_id, answer_text}.
export const SLOT_ICONS = ['circle', 'diamond', 'triangle', 'square']
