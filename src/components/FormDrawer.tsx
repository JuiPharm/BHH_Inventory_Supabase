import type { ReactNode } from 'react'

export function FormDrawer({ open, title, children, onClose }: { open: boolean; title: string; children: ReactNode; onClose: () => void }) {
  if (!open) return null
  return <div className="drawer-backdrop"><aside className="drawer"><div className="drawer-head"><h2>{title}</h2><button className="icon-btn" onClick={onClose}>×</button></div>{children}</aside></div>
}
