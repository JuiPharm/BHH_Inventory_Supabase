import { useEffect, useMemo, useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { BarcodeScannerInput } from '../components/BarcodeScannerInput'
import { LotSelector } from '../components/LotSelector'
import { PrintHeader } from '../components/PrintHeader'
import { PrintButton } from '../components/PrintButton'
import { supabase } from '../lib/supabaseClient'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcIssueStock, rpcSearchItems } from '../services/inventoryService'
import type { Department, IssueItemInput, ItemSearchResult } from '../types'
import { readableError } from '../utils/errors'
import { formatDateTime } from '../utils/format'

type Line = IssueItemInput & { item?: ItemSearchResult | null; lot_display?: string }

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
  const [scanning, setScanning] = useState(false)
  
  const [line, setLine] = useState<Line>({ item_id: '', lot_id: '', qty: 1, reason: '' })
  const [items, setItems] = useState<Line[]>([])
  
  // Receipt State
  const [receiptData, setReceiptData] = useState<{ destName: string, remarks: string, items: Line[], date: string } | null>(null)

  useEffect(() => {
    let mounted = true

    async function loadDepartments() {
      setLoadingDepartments(true)
      try {
        const { data, error } = await supabase
          .from('departments')
          .select('id, department_code, department_name, is_active')
          .eq('is_active', true)
          .order('department_code', { ascending: true })

        if (!mounted) return
        if (error) throw error
        const cleanDestinations = normalizeIssueDestinations((data || []) as Department[])
        setDepartments(cleanDestinations)
        if (departmentId && !cleanDestinations.some(d => d.id === departmentId)) {
          setDepartmentId('')
        }
      } catch (error) {
        if (mounted) pushToast(readableError(error), 'error')
      } finally {
        if (mounted) setLoadingDepartments(false)
      }
    }

    loadDepartments()
    return () => { mounted = false }
  }, [departmentId, pushToast])

  async function handleScan(code: string) {
    if (!code) return
    setScanning(true)
    try {
      const res = await rpcSearchItems(code) as ItemSearchResult[]
      if (res && res.length > 0) {
        const item = res[0]
        setLine({ ...line, item, item_id: item.id, lot_id: '' })
        pushToast(`Scanned: ${item.item_code}`, 'info')
      } else {
        pushToast(`Barcode not found: ${code}`, 'warning')
      }
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setScanning(false)
    }
  }

  function addLine() {
    if (!line.item_id || line.qty <= 0) {
      pushToast('à¸à¸£à¸¸à¸“à¸²à¹€à¸¥à¸·à¸­à¸à¸£à¸²à¸¢à¸à¸²à¸£à¹à¸¥à¸°à¹ƒà¸ªà¹ˆà¸ˆà¸³à¸™à¸§à¸™à¹ƒà¸«à¹‰à¸–à¸¹à¸à¸•à¹‰à¸­à¸‡', 'warning')
      return
    }
    if ((line.item?.is_controlled || line.item?.is_high_alert) && !line.reason) {
      pushToast('Controlled/High alert item à¸•à¹‰à¸­à¸‡à¸£à¸°à¸šà¸¸ reason', 'warning')
      return
    }
    setItems(prev => [...prev, line])
    setLine({ item_id: '', lot_id: '', qty: 1, reason: '' })
  }

  async function save() {
    if (!selectedWarehouseId) {
      pushToast('à¸à¸£à¸¸à¸“à¸²à¹€à¸¥à¸·à¸­à¸à¸„à¸¥à¸±à¸‡à¸•à¹‰à¸™à¸—à¸²à¸‡', 'warning')
      return
    }
    if (!departmentId) {
      pushToast('à¸à¸£à¸¸à¸“à¸²à¹€à¸¥à¸·à¸­à¸à¸«à¸™à¹ˆà¸§à¸¢à¸‡à¸²à¸™à¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡ à¹€à¸Šà¹ˆà¸™ OPD Pharmacy, IPD Pharmacy à¸«à¸£à¸·à¸­ IV Chemo', 'warning')
      return
    }
    if (!items.length) {
      pushToast('à¸à¸£à¸¸à¸“à¸²à¹€à¸žà¸´à¹ˆà¸¡à¸£à¸²à¸¢à¸à¸²à¸£à¹€à¸šà¸´à¸', 'warning')
      return
    }
    setSaving(true)
    try {
      await rpcIssueStock({
        warehouse_id: selectedWarehouseId,
        issue_to_department_id: departmentId,
        requester_name: null,
        remarks,
        items: items.map(it => ({
          item_id: it.item_id,
          lot_id: it.lot_id || null, // null lot_id will trigger FEFO in backend
          qty: it.qty,
          reason: it.reason
        }))
      })
      
      const destName = departments.find(d => d.id === departmentId)?.department_name || 'Unknown'
      
      pushToast('à¹€à¸šà¸´à¸ stock à¸ªà¸³à¹€à¸£à¹‡à¸ˆ', 'success')
      setReceiptData({ destName, remarks, items, date: new Date().toISOString() })
      setItems([])
      setDepartmentId('')
      setRemarks('')
    } catch (error) {
      pushToast(readableError(error), 'error')
    } finally {
      setSaving(false)
    }
  }

  if (receiptData) {
    return (
      <div className="stack print-only-container">
        <section className="panel" style={{ background: '#fff' }}>
          <PrintHeader 
            title="Issuing Slip" 
            reference={`To: ${receiptData.destName}`} 
            date={formatDateTime(receiptData.date)} 
            user={requester} 
          />
          <table className="data-table">
            <thead>
              <tr>
                <th>Item Code</th>
                <th>Description</th>
                <th>Lot ID</th>
                <th>Qty</th>
                <th>Reason</th>
              </tr>
            </thead>
            <tbody>
              {receiptData.items.map((it, idx) => (
                <tr key={idx}>
                  <td>{it.item?.item_code}</td>
                  <td>{it.item?.item_name}</td>
                  <td>{it.lot_id || 'FEFO (Auto)'}</td>
                  <td>{it.qty}</td>
                  <td>{it.reason || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="panel-actions no-print" style={{ marginTop: 24, justifyContent: 'center' }}>
            <PrintButton />
            <button className="btn secondary" onClick={() => setReceiptData(null)}>New Transaction</button>
          </div>
        </section>
      </div>
    )
  }

  return (
    <div className="stack">
      <section className="panel no-print">
        <h2>Issue Stock</h2>
        <div className="form-grid">
          <label>
            Issue to department
            <select value={departmentId} onChange={e => setDepartmentId(e.target.value)} disabled={loadingDepartments}>
              <option value="">{loadingDepartments ? 'à¸à¸³à¸¥à¸±à¸‡à¹‚à¸«à¸¥à¸”à¸«à¸™à¹ˆà¸§à¸¢à¸‡à¸²à¸™...' : 'à¹€à¸¥à¸·à¸­à¸à¸«à¸™à¹ˆà¸§à¸¢à¸‡à¸²à¸™à¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡'}</option>
              {departments.map(d => <option key={d.department_code} value={d.id}>{d.department_name}</option>)}
            </select>
          </label>
          <label>
            Requester
            <input value={requester} disabled title="Requester à¸­à¹‰à¸²à¸‡à¸­à¸´à¸‡à¸ˆà¸²à¸à¸œà¸¹à¹‰ Login à¸›à¸±à¸ˆà¸ˆà¸¸à¸šà¸±à¸™" />
          </label>
          <label className="span-2">
            Remarks
            <input value={remarks} onChange={e => setRemarks(e.target.value)} />
          </label>
        </div>
        
        <div style={{ display: 'flex', gap: 16, marginTop: 16 }}>
          <BarcodeScannerInput onScan={handleScan} loading={scanning} />
        </div>

        <div className="line-editor" style={{ gridTemplateColumns: 'minmax(260px, 2fr) 2fr 1fr 1fr auto', marginTop: 16 }}>
          <AsyncItemPicker value={line.item} onSelect={item => setLine({ ...line, item, item_id: item.id, lot_id: '' })} />
          <LotSelector 
            itemId={line.item_id} 
            warehouseId={selectedWarehouseId} 
            value={line.lot_id || ''} 
            onChange={lot_id => setLine({ ...line, lot_id })} 
          />
          <input type="number" min="0" step="0.01" placeholder="Qty" value={line.qty || ''} onChange={e => setLine({ ...line, qty: Number(e.target.value) })} />
          <input placeholder="Reason" value={line.reason || ''} onChange={e => setLine({ ...line, reason: e.target.value })} />
          <button className="btn secondary" onClick={addLine}>Add</button>
        </div>
        <p className="hint" style={{ marginTop: 8 }}>à¸«à¸²à¸à¹„à¸¡à¹ˆà¸£à¸°à¸šà¸¸ Lot à¸£à¸°à¸šà¸šà¸ˆà¸°à¸ˆà¹ˆà¸²à¸¢à¸ªà¸´à¸™à¸„à¹‰à¸²à¹à¸šà¸š <strong>FEFO</strong> (à¸ˆà¹ˆà¸²à¸¢ Lot à¸—à¸µà¹ˆà¸«à¸¡à¸”à¸­à¸²à¸¢à¸¸à¸à¹ˆà¸­à¸™à¸­à¸±à¸•à¹‚à¸™à¸¡à¸±à¸•à¸´)</p>
      </section>

      <section className="panel no-print">
        <h2>à¸£à¸²à¸¢à¸à¸²à¸£à¹€à¸šà¸´à¸</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Item</th><th>Lot</th><th>Qty</th><th>Reason</th><th></th></tr></thead>
            <tbody>
              {items.map((it, idx) => <tr key={idx}>
                <td>{it.item?.item_code} {it.item?.item_name}</td>
                <td>{it.lot_id ? `Lot ${it.lot_id.slice(0, 8)}...` : <span style={{ color: 'var(--blue)' }}>FEFO Auto</span>}</td>
                <td>{it.qty}</td>
                <td>{it.reason}</td>
                <td><button className="link-btn" onClick={() => setItems(items.filter((_, i) => i !== idx))}>remove</button></td>
              </tr>)}
              {items.length === 0 && <tr><td colSpan={5} style={{ textAlign: 'center', padding: 20, color: 'var(--muted)' }}>No items added</td></tr>}
            </tbody>
          </table>
        </div>
        <div className="panel-actions">
          <button className="btn" disabled={saving || items.length === 0} onClick={save}>{saving ? 'Saving...' : 'Save Issue'}</button>
        </div>
      </section>
    </div>
  )
}
