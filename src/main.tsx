import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import { AuthProvider } from './state/AuthContext'
import { ToastProvider } from './state/ToastContext'
import './styles/global.css'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <div style={{ padding: 40, fontFamily: 'system-ui, sans-serif', color: '#333' }}>
      <h1 style={{ color: '#e53e3e' }}>System Configuration Error</h1>
      <p>The application could not start because the Supabase environment variables are missing.</p>
      <p><strong>Please add the following secrets to your GitHub Repository (Settings &gt; Secrets and variables &gt; Actions):</strong></p>
      <ul>
        <li><code>VITE_SUPABASE_URL</code></li>
        <li><code>VITE_SUPABASE_ANON_KEY</code></li>
      </ul>
      <p>After adding the secrets, you must re-run the GitHub Actions deployment workflow.</p>
    </div>
  )
} else {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <ToastProvider>
        <AuthProvider>
          <App />
        </AuthProvider>
      </ToastProvider>
    </React.StrictMode>
  )
}
