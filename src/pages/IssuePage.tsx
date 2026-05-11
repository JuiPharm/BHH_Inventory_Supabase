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

export function IssuePage() {
  const { selectedWarehouseId, profile } = useAuth()
  const { pushToast } = useToast()
  const requester = useMemo(() => profile?.full_name || profile?.email || 'Current login user', [profile])
  const [departments, setDepartments] = useState<Department[]>([])
  const [departmentId, setDepartmentId] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [line, setLine] = useState<Line>({ item_id: '', qty: 1, reason: '' })
  const [items, setItems] = useState<Line[]>([])

  useEffect(() => {
    let mounted = true
    supabase
      .from('departments')
      .select('id, department_code, department_name, is_active')
      .eq('is_active', true)
      .order('department_name')
      .then(({ data, error }) => {
        if (!mounted) return
        if (error) throw error
        setDepartments((data || []) as Department[])
      })
      .catch(error => pushToast(readableError(error), 'error'))
    return () => { mounted = false }
  }, [pushToast])

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
        requester_name: requester,
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
            <select value={departmentId} onChange={e => setDepartmentId(e.target.value)}>
              <option value="">เลือกหน่วยงานปลายทาง</option>
              {departments.map(d => <option key={d.id} value={d.id}>{d.department_name}</option>)}
            </select>
          </label>
          <label>
            Requester
            <input value={requester} disabled title="Requester อ้างอิงจากผู้ Login ปัจจุบัน" />
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
        <p className="hint">ระบบจะเลือก lot ด้วย FEFO จาก RPC โดยอัตโนมัติถ้าไม่ระบุ lot_id และ Requester จะอ้างอิงจากรหัส Login ปัจจุบัน</p>
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
