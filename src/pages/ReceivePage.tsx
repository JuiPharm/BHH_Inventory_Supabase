import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { BarcodeScannerInput } from '../components/BarcodeScannerInput'
import { PrintHeader } from '../components/PrintHeader'
import { PrintButton } from '../components/PrintButton'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcReceiveStock, rpcSearchItems } from '../services/inventoryService'
import type { ItemSearchResult, ReceiveItemInput } from '../types'
import { readableError } from '../utils/errors'
import { formatDateTime } from '../utils/format'

type Line = ReceiveItemInput & { item?: ItemSearchResult | null }

export function ReceivePage() {
  const { selectedWarehouseId, profile } = useAuth()
  const { pushToast } = useToast()
  
  const [invoiceNo, setInvoiceNo] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [scanning, setScanning] = useState(false)
  
  const [line, setLine] = useState<Line>({ item_id: '', lot_no: '', expiry_date: '', qty: 1, unit_cost: 0 })
  const [items, setItems] = useState<Line[]>([])
  
  // Receipt State
  const [receiptData, setReceiptData] = useState<{ invoiceNo: string, items: Line[], date: string } | null>(null)

  async function handleScan(code: string) {
    if (!code) return
    setScanning(true)
    try {
      const res = await rpcSearchItems(code) as ItemSearchResult[]
      if (res && res.length > 0) {
        const item = res[0]
        setLine({ ...line, item, item_id: item.id })
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
    if (!line.item_id || line.qty <= 0 || line.unit_cost < 0) { pushToast('กรุณาเลือกรายการและใส่จำนวน/ราคาให้ถูกต้อง', 'warning'); return }
    if (line.item?.is_expiry_tracked && !line.expiry_date) { pushToast('รายการนี้ต้องระบุวันหมดอายุ', 'warning'); return }
    if (line.item?.is_lot_tracked && !line.lot_no) { pushToast('รายการนี้ต้องระบุ Lot no.', 'warning'); return }
    setItems(prev => [...prev, line])
    setLine({ item_id: '', lot_no: '', expiry_date: '', qty: 1, unit_cost: 0 })
  }

  async function save() {
    if (!selectedWarehouseId) { pushToast('กรุณาเลือกคลัง', 'warning'); return }
    if (!items.length) { pushToast('กรุณาเพิ่มรายการรับเข้า', 'warning'); return }
    setSaving(true)
    try { 
      await rpcReceiveStock({ warehouse_id: selectedWarehouseId, invoice_no: invoiceNo, remarks, items })
      pushToast('รับเข้าสต็อกสำเร็จ', 'success')
      // Save data for receipt before clearing
      setReceiptData({ invoiceNo, items, date: new Date().toISOString() })
      setItems([])
      setInvoiceNo('')
      setRemarks('')
    }
    catch (error) { pushToast(readableError(error), 'error') }
    finally { setSaving(false) }
  }

  if (receiptData) {
    return (
      <div className="stack print-only-container">
        <section className="panel" style={{ background: '#fff' }}>
          <PrintHeader 
            title="Goods Receipt Note" 
            reference={receiptData.invoiceNo || 'N/A'} 
            date={formatDateTime(receiptData.date)} 
            user={profile?.full_name || profile?.email} 
          />
          <table className="data-table">
            <thead>
              <tr>
                <th>Item Code</th>
                <th>Description</th>
                <th>Lot No.</th>
                <th>Expiry</th>
                <th>Qty</th>
                <th>Unit Cost</th>
              </tr>
            </thead>
            <tbody>
              {receiptData.items.map((it, idx) => (
                <tr key={idx}>
                  <td>{it.item?.item_code}</td>
                  <td>{it.item?.item_name}</td>
                  <td>{it.lot_no || '-'}</td>
                  <td>{it.expiry_date || '-'}</td>
                  <td>{it.qty}</td>
                  <td>{it.unit_cost}</td>
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
        <h2>Receive Stock</h2>
        <div className="form-grid">
          <label>Invoice no. / PO no.
            <input value={invoiceNo} onChange={e => setInvoiceNo(e.target.value)} placeholder="เลขที่เอกสารอ้างอิง" />
          </label>
          <label>Remarks
            <input value={remarks} onChange={e => setRemarks(e.target.value)} placeholder="หมายเหตุ" />
          </label>
        </div>

        <div style={{ display: 'flex', gap: 16, marginTop: 16 }}>
          <BarcodeScannerInput onScan={handleScan} loading={scanning} />
        </div>

        <div className="line-editor" style={{ marginTop: 16 }}>
          <AsyncItemPicker value={line.item} onSelect={item => setLine({ ...line, item, item_id: item.id })} />
          <input placeholder="Lot no." value={line.lot_no || ''} onChange={e => setLine({ ...line, lot_no: e.target.value })} />
          <input type="date" value={line.expiry_date || ''} onChange={e => setLine({ ...line, expiry_date: e.target.value })} />
          <input type="number" placeholder="Qty" min="0" step="0.01" value={line.qty || ''} onChange={e => setLine({ ...line, qty: Number(e.target.value) })} />
          <input type="number" placeholder="Cost" min="0" step="0.01" value={line.unit_cost || ''} onChange={e => setLine({ ...line, unit_cost: Number(e.target.value) })} />
          <button className="btn secondary" onClick={addLine}>Add</button>
        </div>
      </section>

      <section className="panel no-print">
        <h2>รายการรับเข้า</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Item</th>
                <th>Lot</th>
                <th>Expiry</th>
                <th>Qty</th>
                <th>Cost</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {items.map((it, idx) => (
                <tr key={idx}>
                  <td>{it.item?.item_code} {it.item?.item_name}</td>
                  <td>{it.lot_no}</td>
                  <td>{it.expiry_date}</td>
                  <td>{it.qty}</td>
                  <td>{it.unit_cost}</td>
                  <td><button className="link-btn" onClick={() => setItems(items.filter((_, i) => i !== idx))}>remove</button></td>
                </tr>
              ))}
              {items.length === 0 && <tr><td colSpan={6} style={{ textAlign: 'center', padding: 20, color: 'var(--muted)' }}>No items added</td></tr>}
            </tbody>
          </table>
        </div>
        <div className="panel-actions" style={{ marginTop: 16 }}>
          <button className="btn" disabled={saving || items.length === 0} onClick={save}>
            {saving ? 'Saving...' : 'Save Receive'}
          </button>
        </div>
      </section>
    </div>
  )
}
