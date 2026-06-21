import { useState } from 'react'
import { LockKeyhole, Mail } from 'lucide-react'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { readableError } from '../utils/errors'

export function LoginPage() {
  const { signIn, resetPassword } = useAuth()
  const { pushToast } = useToast()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const logoSrc = `${import.meta.env.BASE_URL}bdms-bhh-logo.svg`

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    try {
      await signIn(email, password)
      pushToast('Login successful.', 'success')
    } catch (error) {
      pushToast(readableError(error), 'error')
    } finally { setLoading(false) }
  }

  async function forgotPassword() {
    if (!email) { pushToast('Please enter your email first.', 'warning'); return }
    setLoading(true)
    try {
      await resetPassword(email)
      pushToast('Password reset link sent.', 'success')
    } catch (error) { pushToast(readableError(error), 'error') }
    finally { setLoading(false) }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-hero">
          <img className="login-logo" src={logoSrc} alt="Bangkok Hospital Hat Yai" />
          <h1>BHH Inventory Management System</h1>
          <p>Hospital inventory operations for stock balance, receiving, issuing, transfer, expiry monitoring, and audit-ready movement history.</p>
          <div className="login-status-pill">Production ready · GitHub Pages frontend · Supabase backend</div>
        </div>
        <form onSubmit={submit} className="login-form">
          <label><span>Email</span><div className="input-icon"><Mail size={18}/><input type="email" value={email} onChange={e => setEmail(e.target.value)} required /></div></label>
          <label><span>Password</span><div className="input-icon"><LockKeyhole size={18}/><input type="password" value={password} onChange={e => setPassword(e.target.value)} required /></div></label>
          <button className="btn full" disabled={loading}>{loading ? 'Signing in...' : 'Login'}</button>
          <button type="button" className="link-btn" onClick={forgotPassword} disabled={loading}>Forgot password</button>
        </form>
      </div>
    </div>
  )
}
