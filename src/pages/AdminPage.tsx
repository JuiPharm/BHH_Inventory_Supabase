import { useEffect, useMemo, useState } from 'react'
import { Mail, Save } from 'lucide-react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { StatusBadge } from '../components/StatusBadge'
import { useToast } from '../state/ToastContext'
import { readableError } from '../utils/errors'

type ProfileRow = Record<string, any>
type WarehouseRow = Record<string, any>
type RoleRow = Record<string, any>

const NOTIFICATION_EMAIL_KEY = 'notification_emails'

function parseEmailList(value: string) {
  return value
    .split(/[\n,;]/)
    .map(email => email.trim())
    .filter(Boolean)
}

function hasInvalidEmails(emails: string[]) {
  return emails.some(email => !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
}

export function AdminPage() {
  const { pushToast } = useToast()
  const [profiles, setProfiles] = useState<ProfileRow[]>([])
  const [warehouses, setWarehouses] = useState<WarehouseRow[]>([])
  const [roles, setRoles] = useState<RoleRow[]>([])
  const [loading, setLoading] = useState(false)

  const [notificationEmails, setNotificationEmails] = useState('')
  const [savingEmails, setSavingEmails] = useState(false)

  const [showUserModal, setShowUserModal] = useState(false)
  const [savingUser, setSavingUser] = useState(false)
  const [userForm, setUserForm] = useState({
    id: '',
    email: '',
    password: '',
    full_name: '',
    role_code: '',
    is_active: true,
    warehouse_ids: [] as string[]
  })

  const emailCount = useMemo(() => parseEmailList(notificationEmails).length, [notificationEmails])

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    try {
      const [p, w, r, settings] = await Promise.all([
        supabase.from('profiles').select('id,email,full_name,is_active,roles(role_code,role_name),user_warehouse_access(warehouse_id)').limit(100),
        supabase.from('warehouses').select('id,warehouse_code,warehouse_name,is_active').limit(100),
        supabase.from('roles').select('id,role_code,role_name').eq('is_active', true),
        supabase.from('app_settings').select('value').eq('key', NOTIFICATION_EMAIL_KEY).maybeSingle()
      ])
      if (p.error) throw p.error
      if (w.error) throw w.error
      if (r.error) throw r.error
      if (settings.error) throw settings.error

      setProfiles(p.data || [])
      setWarehouses(w.data || [])
      setRoles(r.data || [])

      const recipients = Array.isArray((settings.data?.value as any)?.recipients)
        ? (settings.data?.value as any).recipients
        : []
      setNotificationEmails(recipients.join('\n'))
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setLoading(false)
    }
  }

  function openNewUser() {
    setUserForm({ id: '', email: '', password: '', full_name: '', role_code: '', is_active: true, warehouse_ids: [] })
    setShowUserModal(true)
  }

  function openEditUser(p: ProfileRow) {
    setUserForm({
      id: p.id,
      email: p.email,
      password: '',
      full_name: p.full_name || '',
      role_code: p.roles?.role_code || '',
      is_active: p.is_active,
      warehouse_ids: (p.user_warehouse_access || []).map((uwa: any) => uwa.warehouse_id)
    })
    setShowUserModal(true)
  }

  function toggleWarehouse(wid: string) {
    setUserForm(prev => {
      const ids = prev.warehouse_ids.includes(wid)
        ? prev.warehouse_ids.filter(id => id !== wid)
        : [...prev.warehouse_ids, wid]
      return { ...prev, warehouse_ids: ids }
    })
  }

  async function saveNotificationEmails() {
    const recipients = parseEmailList(notificationEmails)
    if (hasInvalidEmails(recipients)) {
      pushToast('Please check notification email format.', 'warning')
      return
    }

    setSavingEmails(true)
    try {
      const { error } = await supabase.from('app_settings').upsert({
        key: NOTIFICATION_EMAIL_KEY,
        value: {
          recipients,
          channels: ['low_stock', 'near_expiry', 'movement_exception'],
          updated_from: 'admin_web'
        },
        description: 'Email recipients for inventory notifications'
      })
      if (error) throw error
      pushToast('Notification emails saved.', 'success')
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setSavingEmails(false)
    }
  }

  async function saveUser() {
    if (!userForm.full_name || !userForm.role_code) {
      pushToast('Please complete full name and role.', 'warning')
      return
    }
    setSavingUser(true)
    try {
      let targetUserId = userForm.id

      if (userForm.id) {
        const { error } = await supabase.rpc('admin_update_user', {
          p_user_id: userForm.id,
          p_full_name: userForm.full_name,
          p_role_code: userForm.role_code,
          p_is_active: userForm.is_active
        })
        if (error) throw error
      } else {
        if (!userForm.email || !userForm.password || userForm.password.length < 6) {
          pushToast('Please enter email and a password of at least 6 characters.', 'warning')
          setSavingUser(false)
          return
        }
        const { data, error } = await supabase.rpc('admin_create_user', {
          p_email: userForm.email,
          p_password: userForm.password,
          p_full_name: userForm.full_name,
          p_role_code: userForm.role_code
        })
        if (error) throw error
        targetUserId = data
      }

      if (targetUserId) {
        await supabase.from('user_warehouse_access').delete().eq('user_id', targetUserId)
        if (userForm.warehouse_ids.length > 0) {
          const inserts = userForm.warehouse_ids.map(wid => ({
            user_id: targetUserId,
            warehouse_id: wid,
            can_receive: true,
            can_issue: true,
            can_adjust: true,
            can_transfer: true
          }))
          const { error: insErr } = await supabase.from('user_warehouse_access').insert(inserts)
          if (insErr) throw insErr
        }
      }

      pushToast(userForm.id ? 'User updated.' : 'User created.', 'success')
      setShowUserModal(false)
      load()
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setSavingUser(false)
    }
  }

  return (
    <div className="stack">
      <div className="grid two">
        <section className="panel">
          <div className="section-head">
            <div>
              <h2>Users / Profiles</h2>
              <p className="hint">Manage application users, roles, and warehouse access.</p>
            </div>
            <button className="btn" onClick={openNewUser}>+ Add User</button>
          </div>
          <DataTable
            loading={loading}
            rows={profiles}
            columns={[
              { key: 'email', header: 'Email', render: r => String(r.email || '') },
              { key: 'name', header: 'Name', render: r => String(r.full_name || '') },
              { key: 'role', header: 'Role', render: r => String((r.roles as any)?.role_name || '-') },
              { key: 'access', header: 'Warehouses', render: r => <small>{(r.user_warehouse_access as any[])?.length || 0} warehouses</small> },
              { key: 'active', header: 'Status', render: r => <StatusBadge tone={Boolean(r.is_active) ? 'green' : 'gray'}>{Boolean(r.is_active) ? 'Active' : 'Inactive'}</StatusBadge> },
              { key: 'action', header: '', render: r => <button className="link-btn" onClick={() => openEditUser(r)}>Edit</button> }
            ]}
          />
        </section>

        <section className="panel">
          <h2>Warehouses</h2>
          <DataTable
            loading={loading}
            rows={warehouses}
            columns={[
              { key: 'code', header: 'Code', render: r => <strong>{String(r.warehouse_code || '')}</strong> },
              { key: 'name', header: 'Name', render: r => String(r.warehouse_name || '') },
              { key: 'active', header: 'Status', render: r => <StatusBadge tone={Boolean(r.is_active) ? 'green' : 'gray'}>{Boolean(r.is_active) ? 'Active' : 'Inactive'}</StatusBadge> }
            ]}
          />
          <p className="hint">Warehouse master data is still controlled by Supabase SQL for production safety.</p>
        </section>
      </div>

      <section className="panel notification-panel">
        <div className="section-head">
          <div>
            <h2><Mail size={20} /> Notification Emails</h2>
            <p className="hint">Recipients used by notification jobs for low stock, near expiry, and exception alerts.</p>
          </div>
          <StatusBadge tone={emailCount > 0 ? 'blue' : 'gray'}>{String(emailCount) + ' recipients'}</StatusBadge>
        </div>
        <label>
          Email recipients
          <textarea
            rows={5}
            value={notificationEmails}
            onChange={e => setNotificationEmails(e.target.value)}
            placeholder="pharmacy@example.com&#10;inventory.manager@example.com"
          />
        </label>
        <p className="hint">Enter one email per line, or separate multiple emails with commas/semicolons.</p>
        <div className="panel-actions">
          <button className="btn" onClick={saveNotificationEmails} disabled={savingEmails}><Save size={16} />{savingEmails ? 'Saving...' : 'Save Notification Emails'}</button>
        </div>
      </section>

      {showUserModal && (
        <div className="modal-backdrop">
          <div className="modal-card user-modal">
            <h3>{userForm.id ? 'Edit User' : 'Add New User'}</h3>
            <div className="form-grid single">
              <label>Email
                <input type="email" value={userForm.email} onChange={e => setUserForm({ ...userForm, email: e.target.value })} disabled={!!userForm.id} />
              </label>
              {!userForm.id && (
                <label>Password
                  <input type="password" value={userForm.password} onChange={e => setUserForm({ ...userForm, password: e.target.value })} />
                </label>
              )}
              <label>Full Name
                <input type="text" value={userForm.full_name} onChange={e => setUserForm({ ...userForm, full_name: e.target.value })} />
              </label>
              <label>Role
                <select value={userForm.role_code} onChange={e => setUserForm({ ...userForm, role_code: e.target.value })}>
                  <option value="">-- Select role --</option>
                  {roles.map(r => <option key={r.id} value={r.role_code}>{r.role_name}</option>)}
                </select>
              </label>
              {userForm.id && (
                <label className="check-row">
                  <input type="checkbox" checked={userForm.is_active} onChange={e => setUserForm({ ...userForm, is_active: e.target.checked })} />
                  Active Status
                </label>
              )}
              <div className="warehouse-checklist">
                <label>Warehouse Access</label>
                {warehouses.map(w => (
                  <label key={w.id} className="check-row">
                    <input type="checkbox" checked={userForm.warehouse_ids.includes(w.id)} onChange={() => toggleWarehouse(w.id)} />
                    {w.warehouse_code} - {w.warehouse_name}
                  </label>
                ))}
              </div>
            </div>
            <div className="panel-actions">
              <button className="btn secondary" onClick={() => setShowUserModal(false)} disabled={savingUser}>Cancel</button>
              <button className="btn" onClick={saveUser} disabled={savingUser}>{savingUser ? 'Saving...' : 'Save User'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
