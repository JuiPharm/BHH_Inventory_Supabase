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

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    try {
      await signIn(email, password)
      pushToast('เข้าสู่ระบบสำเร็จ', 'success')
    } catch (error) {
      pushToast(readableError(error), 'error')
    } finally { setLoading(false) }
  }

  async function forgotPassword() {
    if (!email) { pushToast('กรุณากรอก email ก่อน', 'warning'); return }
    setLoading(true)
    try {
      await resetPassword(email)
      pushToast('ส่ง link reset password ไปที่ email แล้ว', 'success')
    } catch (error) { pushToast(readableError(error), 'error') }
    finally { setLoading(false) }
  }

  return <div className="login-page"><div className="login-card"><div className="login-hero"><div className="brand-mark large">B</div><h1>BHH Inventory Management System</h1><p>ระบบคลังโรงพยาบาลแบบ production-grade บน Supabase + Netlify</p></div><form onSubmit={submit} className="login-form"><label><span>Email</span><div className="input-icon"><Mail size={18}/><input type="email" value={email} onChange={e => setEmail(e.target.value)} required /></div></label><label><span>Password</span><div className="input-icon"><LockKeyhole size={18}/><input type="password" value={password} onChange={e => setPassword(e.target.value)} required /></div></label><button className="btn full" disabled={loading}>{loading ? 'กำลังเข้าสู่ระบบ...' : 'Login'}</button><button type="button" className="link-btn" onClick={forgotPassword} disabled={loading}>Forgot password</button></form></div></div>
}
