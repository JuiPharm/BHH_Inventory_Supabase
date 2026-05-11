import { createContext, useContext, useMemo, useState, type ReactNode } from 'react'

type ToastKind = 'success' | 'error' | 'info' | 'warning'
interface Toast { id: number; message: string; kind: ToastKind }
interface ToastContextValue {
  pushToast: (message: string, kind?: ToastKind) => void
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const value = useMemo(() => ({
    pushToast(message: string, kind: ToastKind = 'info') {
      const id = Date.now() + Math.random()
      setToasts(prev => [...prev, { id, message, kind }])
      window.setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 4500)
    }
  }), [])

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-stack" aria-live="polite">
        {toasts.map(toast => <div key={toast.id} className={`toast toast-${toast.kind}`}>{toast.message}</div>)}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used inside ToastProvider')
  return ctx
}
