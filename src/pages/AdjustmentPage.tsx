import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { LotSelector } from '../components/LotSelector'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcAdjustStock } from '../services/inventoryService'
import type { AdjustmentItemInput, ItemSearchResult } from '../types'
import { readableError } from '../utils/errors'

type Line = AdjustmentItemInput & { item?: ItemSearchResult | null; adjType: 'inc' | 'dec' }

export function AdjustmentPage() {
  const { selectedWarehouseId } = useAuth()
  const { pushToast } = useToast()
  
  const [reason, setReason] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  
  const [items, setItems] = useState<Line[]>([])
  const [adjType, setAdjType] = useState<'inc' | 'dec'>('dec')
  const [line, setLine] = useState<{ item: ItemSearchResult | null; item_id: string; lot_id: string; qty: number; reason: string }>({
    item: null, item_id: '', lot_id: '', qty: 0, reason: ''
  })

  function addLine() {
    if (!line.item_id || !line.lot_id || line.qty <= 0 || !line.reason) {
      pushToast('กรุณาระบุ Item, Lot ID, จำนวน (มากกว่า 0) และเหตุผลของรายการ', 'warning')
      return
    }
    const qty_adjust = adjType === 'inc' ? line.qty : -line.qty
    setItems([...items, { ...line, qty_adjust, adjType }])
    setLine({ item: null, item_id: '', lot_id: '', qty: 0, reason: '' })
  }

  async function save() {
    if (!selectedWarehouseId || !reason || !items.length) {
      pushToast('กรุณาเลือกคลัง ระบุเหตุผลหลัก และเพิ่มรายการ', 'warning')
      return
    }
    setSaving(true)
    try {
      await rpcAdjustStock({ warehouse_id: selectedWarehouseId, reason, remarks, items })
      pushToast('ปรับปรุงสต็อกสำเร็จ', 'success')
      setItems([])
      setReason('')
      setRemarks('')
    } catch (e) {
      pushToast(readableError(e), 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="stack">
      <section className="panel">
        <h2>Stock Adjustment</h2>
        <div className="form-grid">
          <label>Main Reason (e.g., Stock Count Correction, Damage)
            <input required value={reason} onChange={e => setReason(e.target.value)} placeholder="เหตุผลหลักในการปรับปรุง" />
          </label>
          <label>Remarks
            <input value={remarks} onChange={e => setRemarks(e.target.value)} placeholder="หมายเหตุเพิ่มเติม" />
          </label>
        </div>

        <div style={{ marginTop: 24, padding: 16, background: 'var(--sky)', borderRadius: 16 }}>
          <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
            <label style={{ flexDirection: 'row', alignItems: 'center' }}>
              <input type="radio" name="adjType" checked={adjType === 'dec'} onChange={() => setAdjType('dec')} />
              Decrease Stock (-) (ของเสีย, หาย)
            </label>
            <label style={{ flexDirection: 'row', alignItems: 'center' }}>
              <input type="radio" name="adjType" checked={adjType === 'inc'} onChange={() => setAdjType('inc')} />
              Increase Stock (+) (ของเกิน, พบเจอ)
            </label>
          </div>

          <div className="line-editor" style={{ gridTemplateColumns: 'minmax(260px, 2fr) 1.5fr 1fr 1.5fr auto' }}>
            <AsyncItemPicker 
              value={line.item}
              onSelect={item => setLine({ ...line, item, item_id: item?.id || '', lot_id: '' })} 
            />
            
            {adjType === 'dec' ? (
              <LotSelector 
                itemId={line.item_id} 
                warehouseId={selectedWarehouseId} 
                value={line.lot_id} 
                onChange={lot_id => setLine({ ...line, lot_id })} 
              />
            ) : (
              <input 
                placeholder="Enter Lot ID" 
                value={line.lot_id} 
                onChange={e => setLine({ ...line, lot_id: e.target.value })} 
              />
            )}
            
            <input 
              type="number" 
              step="1" 
              min="1"
              placeholder="Qty (Positive)" 
              value={line.qty || ''} 
              onChange={e => setLine({ ...line, qty: Number(e.target.value) })} 
            />
            
            <input 
              placeholder="Line reason" 
              value={line.reason} 
              onChange={e => setLine({ ...line, reason: e.target.value })} 
            />
            
            <button className="btn secondary" onClick={addLine}>Add</button>
          </div>
        </div>
      </section>

      <section className="panel">
        <h2>รายการปรับปรุงยอด</h2>
        {items.length === 0 ? (
          <div className="empty-state">ยังไม่มีรายการ กรุณาเพิ่มรายการด้านบน</div>
        ) : (
          <ul className="simple-list">
            {items.map((it, idx) => (
              <li key={idx}>
                <span>
                  <strong style={{ color: it.adjType === 'inc' ? 'var(--green)' : 'var(--red)' }}>
                    {it.adjType === 'inc' ? '+' : ''}{it.qty_adjust}
                  </strong>{' '}
                  · {it.item?.item_code} {it.item?.item_name} · Lot {it.lot_id} · {it.reason}
                </span>
                <button className="link-btn" onClick={() => setItems(items.filter((_, i) => i !== idx))}>Remove</button>
              </li>
            ))}
          </ul>
        )}
        <div className="panel-actions" style={{ marginTop: 24 }}>
          <button className="btn" disabled={saving || items.length === 0} onClick={save}>
            {saving ? 'Saving...' : 'Save Adjustment'}
          </button>
        </div>
      </section>
    </div>
  )
}
