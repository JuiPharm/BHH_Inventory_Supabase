import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { BarcodeScannerInput } from '../components/BarcodeScannerInput'
import { LotSelector } from '../components/LotSelector'
import { PrintHeader } from '../components/PrintHeader'
import { PrintButton } from '../components/PrintButton'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcTransferStock, rpcSearchItems } from '../services/inventoryService'
import type { ItemSearchResult, TransferItemInput } from '../types'
import { readableError } from '../utils/errors'
import { formatDateTime } from '../utils/format'

type Line = TransferItemInput & { item?: ItemSearchResult | null }

export function TransferPage() {
  const { warehouses, selectedWarehouseId, profile } = useAuth()
  const { pushToast } = useToast()
  
  const [from, setFrom] = useState(selectedWarehouseId || '')
  const [to, setTo] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [scanning, setScanning] = useState(false)
  
  const [line, setLine] = useState<Line>({ item_id: '', lot_id: '', qty: 1 })
  const [items, setItems] = useState<Line[]>([])
  
  // Receipt State
  const [receiptData, setReceiptData] = useState<{ fromName: string, toName: string, remarks: string, items: Line[], date: string } | null>(null)

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
    if (!line.item_id || !line.lot_id || line.qty <= 0) {
      pushToast('กรุณาเลือก Item, Lot ID และจำนวน', 'warning')
      return
    }
    setItems([...items, line])
    setLine({ item_id: '', lot_id: '', qty: 1 })
  }

  async function save() {
    if (!from || !to || from === to || !items.length) {
      pushToast('ตรวจสอบคลังต้นทาง/ปลายทาง และรายการโอน', 'warning')
      return
    }
    setSaving(true)
    try {
      await rpcTransferStock({ from_warehouse_id: from, to_warehouse_id: to, remarks, items })
      
      const fromName = warehouses.find(w => w.id === from)?.warehouse_name || 'Unknown'
      const toName = warehouses.find(w => w.id === to)?.warehouse_name || 'Unknown'
      
      pushToast('สร้าง Transfer สำเร็จ', 'success')
      setReceiptData({ fromName, toName, remarks, items, date: new Date().toISOString() })
      setItems([])
      setRemarks('')
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setSaving(false)
    }
  }

  if (receiptData) {
    return (
      <div className="stack print-only-container">
        <section className="panel" style={{ background: '#fff' }}>
          <PrintHeader 
            title="Stock Transfer Slip" 
            reference={`Transfer to: ${receiptData.toName}`} 
            warehouse={receiptData.fromName}
            date={formatDateTime(receiptData.date)} 
            user={profile?.full_name || profile?.email} 
          />
          <table className="data-table">
            <thead>
              <tr>
                <th>Item Code</th>
                <th>Description</th>
                <th>Lot ID</th>
                <th>Qty</th>
              </tr>
            </thead>
            <tbody>
              {receiptData.items.map((it, idx) => (
                <tr key={idx}>
                  <td>{it.item?.item_code}</td>
                  <td>{it.item?.item_name}</td>
                  <td>{it.lot_id}</td>
                  <td>{it.qty}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="panel-actions no-print" style={{ marginTop: 24, justifyContent: 'center' }}>
            <PrintButton />
            <button className="btn secondary" onClick={() => setReceiptData(null)}>New Transfer</button>
          </div>
        </section>
      </div>
    )
  }

  return (
    <div className="stack">
      <section className="panel no-print">
        <h2>Stock Transfer</h2>
        <div className="form-grid">
          <label>From warehouse
            <select value={from} onChange={e => setFrom(e.target.value)}>
              <option value="">เลือกคลังต้นทาง</option>
              {warehouses.map(w => <option key={w.id} value={w.id}>{w.warehouse_name}</option>)}
            </select>
          </label>
          <label>To warehouse
            <select value={to} onChange={e => setTo(e.target.value)}>
              <option value="">เลือกคลังปลายทาง</option>
              {warehouses.map(w => <option key={w.id} value={w.id}>{w.warehouse_name}</option>)}
            </select>
          </label>
          <label className="span-2">Remarks
            <input value={remarks} onChange={e => setRemarks(e.target.value)} />
          </label>
        </div>

        <div style={{ display: 'flex', gap: 16, marginTop: 16 }}>
          <BarcodeScannerInput onScan={handleScan} loading={scanning} />
        </div>

        <div className="line-editor" style={{ gridTemplateColumns: 'minmax(260px, 2fr) 2fr 1fr auto', marginTop: 16 }}>
          <AsyncItemPicker value={line.item} onSelect={item => setLine({ ...line, item, item_id: item.id, lot_id: '' })} />
          <LotSelector 
            itemId={line.item_id} 
            warehouseId={from} 
            value={line.lot_id} 
            onChange={lot_id => setLine({ ...line, lot_id })} 
          />
          <input type="number" min="0" step="0.01" placeholder="Qty" value={line.qty || ''} onChange={e => setLine({ ...line, qty: Number(e.target.value) })} />
          <button className="btn secondary" onClick={addLine}>Add</button>
        </div>
      </section>

      <section className="panel no-print">
        <h2>รายการโอน</h2>
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Item</th><th>Lot</th><th>Qty</th><th></th></tr></thead>
            <tbody>
              {items.map((it, idx) => <tr key={idx}>
                <td>{it.item?.item_code} {it.item?.item_name}</td>
                <td>Lot {it.lot_id.slice(0, 8)}...</td>
                <td>{it.qty}</td>
                <td><button className="link-btn" onClick={() => setItems(items.filter((_, i) => i !== idx))}>remove</button></td>
              </tr>)}
              {items.length === 0 && <tr><td colSpan={4} style={{ textAlign: 'center', padding: 20, color: 'var(--muted)' }}>No items added</td></tr>}
            </tbody>
          </table>
        </div>
        <div className="panel-actions">
          <button className="btn" disabled={saving || items.length === 0} onClick={save}>{saving ? 'Saving...' : 'Submit Transfer'}</button>
        </div>
      </section>
    </div>
  )
}
