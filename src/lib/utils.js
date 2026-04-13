// Comparator for sorting rows that carry an order_index column.
// Usage: [...items].sort(byOrderIndex)
export const byOrderIndex = (a, b) => a.order_index - b.order_index
