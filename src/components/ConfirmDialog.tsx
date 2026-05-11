export function ConfirmDialog({ open, title, message, confirmLabel = 'ยืนยัน', onCancel, onConfirm }: { open: boolean; title: string; message: string; confirmLabel?: string; onCancel: () => void; onConfirm: () => void }) {
  if (!open) return null
  return <div className="modal-backdrop"><div className="modal-card small"><h3>{title}</h3><p>{message}</p><div className="modal-actions"><button className="btn secondary" onClick={onCancel}>ยกเลิก</button><button className="btn danger" onClick={onConfirm}>{confirmLabel}</button></div></div></div>
}
