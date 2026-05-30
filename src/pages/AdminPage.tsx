import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { StatusBadge } from '../components/StatusBadge'
import { useToast } from '../state/ToastContext'
import { readableError } from '../utils/errors'

export function AdminPage() {
  const { pushToast } = useToast()
  const [profiles, setProfiles] = useState<Record<string, any>[]>([])
  const [warehouses, setWarehouses] = useState<Record<string, any>[]>([])
  const [roles, setRoles] = useState<Record<string, any>[]>([])
  const [loading, setLoading] = useState(false)

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

  useEffect(() => { load() }, [])

  async function load() {
    setLoading(true)
    try {
      const [p, w, r] = await Promise.all([
        supabase.from('profiles').select('id,email,full_name,is_active,roles(role_code,role_name),user_warehouse_access(warehouse_id)').limit(100),
        supabase.from('warehouses').select('id,warehouse_code,warehouse_name,is_active').limit(100),
        supabase.from('roles').select('id,role_code,role_name').eq('is_active', true)
      ])
      if (p.error) throw p.error
      if (w.error) throw w.error
      if (r.error) throw r.error
      setProfiles(p.data || [])
      setWarehouses(w.data || [])
      setRoles(r.data || [])
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

  function openEditUser(p: any) {
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

  async function saveUser() {
    if (!userForm.full_name || !userForm.role_code) {
      pushToast('กรุณากรอกข้อมูลให้ครบถ้วน (ชื่อ, สิทธิ์)', 'warning')
      return
    }
    setSavingUser(true)
    try {
      let targetUserId = userForm.id

      if (userForm.id) {
        // Update user
        const { error } = await supabase.rpc('admin_update_user', {
          p_user_id: userForm.id,
          p_full_name: userForm.full_name,
          p_role_code: userForm.role_code,
          p_is_active: userForm.is_active
        })
        if (error) throw error
      } else {
        // Create user
        if (!userForm.email || !userForm.password || userForm.password.length < 6) {
          pushToast('กรุณากรอก Email และ Password (ขั้นต่ำ 6 ตัวอักษร) สำหรับผู้ใช้ใหม่', 'warning')
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

      // Sync user warehouse access
      if (targetUserId) {
        await supabase.from('user_warehouse_access').delete().eq('user_id', targetUserId)
        if (userForm.warehouse_ids.length > 0) {
          const inserts = userForm.warehouse_ids.map(wid => ({
            user_id: targetUserId,
            warehouse_id: wid,
            can_receive: true, can_issue: true, can_adjust: true, can_transfer: true
          }))
          const { error: insErr } = await supabase.from('user_warehouse_access').insert(inserts)
          if (insErr) throw insErr
        }
      }

      pushToast(userForm.id ? 'อัปเดตผู้ใช้สำเร็จ' : 'สร้างผู้ใช้สำเร็จ', 'success')
      setShowUserModal(false)
      load()
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setSavingUser(false)
    }
  }

  return (
    <div className="grid two">
      <section className="panel">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <h2 style={{ margin: 0 }}>Users / Profiles</h2>
          <button className="btn" onClick={openNewUser}>+ Add User</button>
        </div>
        <DataTable
          loading={loading}
          rows={profiles}
          columns={[
            { key: 'email', header: 'Email', render: r => String(r.email || '') },
            { key: 'name', header: 'Name', render: r => String(r.full_name || '') },
            { key: 'role', header: 'Role', render: r => String((r.roles as any)?.role_name || '-') },
            { key: 'access', header: 'Warehouses', render: r => <small>{(r.user_warehouse_access as any[])?.length || 0} คลัง</small> },
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
        <p className="hint">Master data คลังและอื่นๆ จัดการผ่าน Supabase SQL เพื่อความปลอดภัย</p>
      </section>

      {showUserModal && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ width: 480, maxHeight: '90vh', overflowY: 'auto' }}>
            <h3>{userForm.id ? 'Edit User' : 'Add New User'}</h3>
            <div className="form-grid" style={{ gridTemplateColumns: '1fr' }}>
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
                  <option value="">-- เลือกสิทธิ์ --</option>
                  {roles.map(r => (
                    <option key={r.id} value={r.role_code}>{r.role_name}</option>
                  ))}
                </select>
              </label>
              {userForm.id && (
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                  <input type="checkbox" checked={userForm.is_active} onChange={e => setUserForm({ ...userForm, is_active: e.target.checked })} />
                  Active Status
                </label>
              )}
              
              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
                <label style={{ marginBottom: 8 }}>Warehouse Access</label>
                <div style={{ display: 'grid', gap: 8, background: '#f5f8fc', padding: 12, borderRadius: 12 }}>
                  {warehouses.map(w => (
                    <label key={w.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 'normal', cursor: 'pointer' }}>
                      <input 
                        type="checkbox" 
                        checked={userForm.warehouse_ids.includes(w.id)} 
                        onChange={() => toggleWarehouse(w.id)} 
                      />
                      {w.warehouse_code} - {w.warehouse_name}
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="panel-actions" style={{ marginTop: 24, justifyContent: 'flex-end', gap: 8 }}>
              <button className="btn secondary" onClick={() => setShowUserModal(false)} disabled={savingUser}>Cancel</button>
              <button className="btn" onClick={saveUser} disabled={savingUser}>{savingUser ? 'Saving...' : 'Save User'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
