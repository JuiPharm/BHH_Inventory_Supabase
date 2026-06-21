import { Boxes, ClipboardCheck, ClipboardList, FileBarChart, Home, Layers, LogOut, PackageOpen, Settings, ShieldCheck, Truck, Warehouse } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useAuth } from './state/AuthContext'
import { useToast } from './state/ToastContext'
import { readableError } from './utils/errors'
import { LoadingSpinner } from './components/LoadingSpinner'
import { WarehouseSelector } from './components/WarehouseSelector'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { ItemsPage } from './pages/ItemsPage'
import { StockBalancePage } from './pages/StockBalancePage'
import { ReceivePage } from './pages/ReceivePage'
import { IssuePage } from './pages/IssuePage'
import { AdjustmentPage } from './pages/AdjustmentPage'
import { TransferPage } from './pages/TransferPage'
import { StockCountPage } from './pages/StockCountPage'
import { ExpiryPage } from './pages/ExpiryPage'
import { ReorderPage } from './pages/ReorderPage'
import { ReportsPage } from './pages/ReportsPage'
import { AuditLogPage } from './pages/AuditLogPage'
import { AdminPage } from './pages/AdminPage'

const NAV = [
  { path: '/', label: 'Dashboard', icon: Home, page: DashboardPage },
  { path: '/items', label: 'Item Master', icon: Boxes, page: ItemsPage },
  { path: '/stock', label: 'Stock Balance', icon: Layers, page: StockBalancePage },
  { path: '/receive', label: 'Receive Stock', icon: PackageOpen, page: ReceivePage },
  { path: '/issue', label: 'Issue Stock', icon: ClipboardList, page: IssuePage },
  { path: '/adjustment', label: 'Adjustment', icon: ShieldCheck, page: AdjustmentPage },
  { path: '/transfer', label: 'Transfer', icon: Truck, page: TransferPage },
  { path: '/stock-count', label: 'Stock Count', icon: ClipboardCheck, page: StockCountPage },
  { path: '/expiry', label: 'Expiry', icon: Warehouse, page: ExpiryPage },
  { path: '/reorder', label: 'Reorder', icon: FileBarChart, page: ReorderPage },
  { path: '/reports', label: 'Reports', icon: FileBarChart, page: ReportsPage },
  { path: '/audit', label: 'Audit Log', icon: ShieldCheck, page: AuditLogPage },
  { path: '/admin', label: 'Admin', icon: Settings, page: AdminPage }
]

function useCurrentPath() {
  const getPath = () => window.location.hash.slice(1) || '/'
  const [path, setPath] = useState(getPath())

  useEffect(() => {
    const onHashChange = () => setPath(getPath())
    window.addEventListener('hashchange', onHashChange)
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  const navigate = (next: string) => {
    window.location.hash = next
  }
  return { path, navigate }
}

export default function App() {
  const { loading, session, profile, signOut } = useAuth()
  const { pushToast } = useToast()
  const { path, navigate } = useCurrentPath()
  const logoSrc = `${import.meta.env.BASE_URL}bangkok-hospital-hatyai-logo.jpg`

  const currentRole = (profile?.roles as any)?.role_code
  const isAdmin = currentRole === 'super_admin' || currentRole === 'inventory_manager'

  const navItems = useMemo(() => {
    return NAV.filter(item => {
      if (item.path === '/transfer' || item.path === '/admin' || item.path === '/adjustment') {
        return isAdmin
      }
      return true
    })
  }, [isAdmin])

  const current = useMemo(() => navItems.find(n => n.path === path) || navItems[0], [path, navItems])
  const Page = current?.page || DashboardPage
  const mobileNavItems = navItems.filter(item => ['/', '/stock', '/receive', '/issue', '/reports'].includes(item.path)).slice(0, 5)

  if (loading) return <div className="full-screen"><LoadingSpinner label="Checking secure session..." /></div>
  if (!session) return <LoginPage />
  if (profile && !profile.is_active) return <div className="full-screen error-panel"><h1>Account disabled</h1><p>Please contact the system administrator.</p><button className="btn" onClick={() => signOut()}>Sign out</button></div>

  async function handleSignOut() {
    try { await signOut() } catch (error) { pushToast(readableError(error), 'error') }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <img className="brand-logo" src={logoSrc} alt="Bangkok Hospital Hat Yai" />
        </div>
        <nav>{navItems.map(item => { const Icon = item.icon; return <button key={item.path} className={item.path === current?.path ? 'active' : ''} onClick={() => navigate(item.path)}><Icon size={18} />{item.label}</button> })}</nav>
      </aside>
      <main className="main-area">
        <header className="topbar">
          <div className="topbar-title"><h1>{current?.label || 'BHH Inventory'}</h1><p>Bangkok Hospital Hat Yai Â· Supabase RLS Â· GitHub Pages</p></div>
          <div className="topbar-actions"><WarehouseSelector /><div className="user-pill"><span>{profile?.full_name || profile?.email || 'User'}</span><small>{(profile?.roles as any)?.role_name || 'No role'}</small></div><button className="icon-btn" onClick={handleSignOut} title="Logout"><LogOut size={18} /></button></div>
        </header>
        <section className="page-content"><Page /></section>
      </main>
      <nav className="mobile-bottom-nav" aria-label="Primary mobile navigation">
        {mobileNavItems.map(item => { const Icon = item.icon; return <button key={item.path} className={item.path === current?.path ? 'active' : ''} onClick={() => navigate(item.path)}><Icon size={22} /><span>{item.label.replace(' Stock', '')}</span></button> })}
      </nav>
    </div>
  )
}
