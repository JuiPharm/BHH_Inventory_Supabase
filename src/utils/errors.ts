export function readableError(error: unknown) {
  if (!error) return 'เกิดข้อผิดพลาด ไม่สามารถทำรายการได้'
  if (typeof error === 'string') return error
  if (error instanceof Error) return error.message
  const maybe = error as { message?: string; details?: string; hint?: string }
  return maybe.message || maybe.details || maybe.hint || 'เกิดข้อผิดพลาด ไม่สามารถทำรายการได้'
}
