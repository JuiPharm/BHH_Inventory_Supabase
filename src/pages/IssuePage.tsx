import { useEffect, useMemo, useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { PrintButton } from '../components/PrintButton'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcIssueStock } from '../services/inventoryService'
import type { Department, IssueItemInput, ItemSearchResult } from '../types'
import { readableError } from '../utils/errors'

type Line = IssueItemInput & { item?: ItemSearchResult | null }

const ISSUE_DESTINATIONS: Array<{ code: 'OPD' | 'IPD' | 'CHEMO'; name: string }> = [
  { code: 'OPD', name: 'OPD Pharmacy' },
  { code: 'IPD', name: 'IPD Pharmacy' },
  { code: 'CHEMO', name: 'IV Chemo' }
]

const DESTINATION_NAME_TO_CODE: Record<string, 'OPD' | 'IPD' | 'CHEMO'> = {
  'opd pharmacy': 'OPD',
  'ipd pharmacy': 'IPD',
  'iv chemo': 'CHEMO'
}

function normalize(value: string | null | undefined) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ')
}

function normalizeIssueDestinations(rows: Department[]) {
  const byCode = new Map<'OPD' | 'IPD' | 'CHEMO', Department>()

  for (const row of rows) {
    const normalizedCode = String(row.department_code || '').trim().toUpperCase()
    const normalizedName = normalize(row.department_name)
    const matchedCode = ISSUE_DESTINATIONS.some(d => d.code === normalizedCode)
      ? normalizedCode as 'OPD' | 'IPD' | 'CHEMO'
      : DESTINATION_NAME_TO_CODE[normalizedName]

    if (!matchedCode) continue

    const displayName = ISSUE_DESTINATIONS.find(d => d.code === matchedCode)?.name || row.department_name
    const previous = byCode.get(matchedCode)
    const exactCodeMatch = normalizedCode === matchedCode

    // Prefer the canonical row whose department_code is exactly OPD/IPD/CHEMO.
    // This prevents duplicated names from legacy seed/hotfix data appearing in the dropdown.
    if (!previous || exactCodeMatch) {
      byCode.set(matchedCode, {
        ...row,
        department_code: matchedCode,
        department_name: displayName
      })
    }
  }

  return ISSUE_DESTINATIONS
    .map(destination => byCode.get(destination.code))
    .filter((row): row is Department => Boolean(row))
}

export function IssuePage() {
  const { selectedWarehouseId, profile } = useAuth()
  const { pushToast } = useToast()
  const requester = useMemo(() => profile?.full_name || profile?.email || profile?.id || 'Current login user', [profile])
  const [departments, setDepartments] = useState<Department[]>([])
  const [loadingDepartments, setLoadingDepartments] = useState(false)
  const [departmentId, setDepartmentId] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [line, setLine] = useState<Line>({ item_id: '', qty: 1, reason: '' })
  const [items, setItems] = useState<Line[]>([])

  useEffect(() => {
    let mounted = true
    setLoadingDepartments(true)
    supabase
      .from('departments')
      .select('id, department_code, department_name, is_active')
      .eq('is_active', true)
      .order('department_code', { ascending: true })
      .then(({ data, error }) => {
        if (!mounted) return
        if (error) throw error
        const cleanDestinations = normalizeIssueDestinations((data || []) as Department[])
        setDepartments(cleanDestinations)
        if (departmentId && !cleanDestinations.some(d => d.id === departmentId)) {
          setDepartmentId('')
        }
      })
      .catch(error => pushToast(readableError(error), 'error'))
      .finally(() => {
        if (mounted) setLoadingDepartments(false)
      })
    return () => { mounted = false }
  }, [departmentId, pushToast])

  function addLine() {
    if (!line.item_id || line.qty <= 0) {
      pushToast('กรุณาเลือกรายการและใส่จำนวนให้ถูกต้อง', 'warning')
      return
    }
    if ((line.item?.is_controlled || line.item?.is_high_alert) && !line.reason) {
      pushToast('Controlled/High alert item ต้องระบุ reason', 'warning')
      return
    }
    setItems(prev => [...prev, line])
    setLine({ item_id: '', qty: 1, reason: '' })
  }

  async function save() {
    if (!selectedWarehouseId) {
      pushToast('กรุณาเลือกคลังต้นทาง', 'warning')
      return
    }
    if (!departmentId) {
      pushToast('กรุณาเลือกหน่วยงานปลายทาง เช่น OPD Pharmacy, IPD Pharmacy หรือ IV Chemo', 'warning')
      return
    }
    if (!items.length) {
      pushToast('กรุณาเพิ่มรายการเบิก', 'warning')
      return
    }
    setSaving(true)
    try {
      await rpcIssueStock({
        warehouse_id: selectedWarehouseId,
        issue_to_department_id: departmentId,
        // Do not trust editable frontend text for requester. The RPC records auth.uid()/profile.
        requester_name: null,
        remarks,
        items
      })
      pushToast('เบิก stock สำเร็จ', 'success')
      setItems([])
      setDepartmentId('')
      setRemarks('')
    } catch (error) {
      pushToast(readableError(error), 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="stack">
      <section className="panel">
        <h2>Issue Stock</h2>
        <div className="form-grid">
          <label>
            Issue to department
            <select
              value={departmentId}
              onChange={e => setDepartmentId(e.target.value)}
              disabled={loadingDepartments}
            >
              <option value="">{loadingDepartments ? 'กำลังโหลดหน่วยงาน...' : 'เลือกหน่วยงานปลายทาง'}</option>
              {departments.map(d => <option key={d.department_code} value={d.id}>{d.department_name}</option>)}
            </select>
          </label>
          <label>
            Requester
            <input value={requester} disabled title="Requester อ้างอิงจากผู้ Login ปัจจุบันและบันทึกจาก Supabase Auth" />
          </label>
          <label>
            Remarks
            <input value={remarks} onChange={e => setRemarks(e.target.value)} />
          </label>
        </div>
        <div className="line-editor">
          <AsyncItemPicker onSelect={item => setLine({ ...line, item, item_id: item.id })} />
          <input type="number" min="0" step="0.01" value={line.qty} onChange={e => setLine({ ...line, qty: Number(e.target.value) })} />
          <input placeholder="Reason" value={line.reason || ''} onChange={e => setLine({ ...line, reason: e.target.value })} />
          <button className="btn secondary" onClick={addLine}>Add</button>
        </div>
        <p className="hint">Dropdown แสดงเฉพาะ OPD Pharmacy, IPD Pharmacy และ IV Chemo โดยตัดรายการซ้ำอัตโนมัติ ส่วน Requester จะบันทึกจาก Supabase Auth Login ผ่าน RPC</p>
      </section>

      <section className="panel">
        <h2>รายการเบิก</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Item</th><th>Qty</th><th>Reason</th><th></th></tr></thead>
            <tbody>
              {items.map((it, idx) => <tr key={idx}>
                <td>{it.item?.item_code} {it.item?.item_name}</td>
                <td>{it.qty}</td>
                <td>{it.reason}</td>
                <td><button className="link-btn" onClick={() => setItems(items.filter((_, i) => i !== idx))}>remove</button></td>
              </tr>)}
            </tbody>
          </table>
        </div>
        <div className="panel-actions">
          <PrintButton />
          <button className="btn" disabled={saving} onClick={save}>{saving ? 'Saving...' : 'Save Issue'}</button>
        </div>
      </section>
    </div>
  )
}
