import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { PrintButton } from '../components/PrintButton'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcReceiveStock } from '../services/inventoryService'
import type { ItemSearchResult, ReceiveItemInput } from '../types'
import { readableError } from '../utils/errors'

type Line = ReceiveItemInput & { item?: ItemSearchResult | null }

export function ReceivePage() {
  const { selectedWarehouseId } = useAuth()
  const { pushToast } = useToast()
  const [invoiceNo, setInvoiceNo] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [line, setLine] = useState<Line>({ item_id: '', lot_no: '', expiry_date: '', qty: 1, unit_cost: 0 })
  const [items, setItems] = useState<Line[]>([])

  function addLine() {
    if (!line.item_id || line.qty <= 0 || line.unit_cost < 0) { pushToast('กรุณาเลือกรายการและใส่จำนวน/ราคาให้ถูกต้อง', 'warning'); return }
    if (line.item?.is_expiry_tracked && !line.expiry_date) { pushToast('รายการนี้ต้องระบุวันหมดอายุ', 'warning'); return }
    if (line.item?.is_lot_tracked && !line.lot_no) { pushToast('รายการนี้ต้องระบุ Lot no.', 'warning'); return }
    setItems(prev => [...prev, line]); setLine({ item_id: '', lot_no: '', expiry_date: '', qty: 1, unit_cost: 0 })
  }
  async function save() {
    if (!selectedWarehouseId) { pushToast('กรุณาเลือกคลัง', 'warning'); return }
    if (!items.length) { pushToast('กรุณาเพิ่มรายการรับเข้า', 'warning'); return }
    setSaving(true)
    try { await rpcReceiveStock({ warehouse_id: selectedWarehouseId, invoice_no: invoiceNo, remarks, items }); pushToast('รับเข้าสต็อกสำเร็จ', 'success'); setItems([]); setInvoiceNo(''); setRemarks('') }
    catch (error) { pushToast(readableError(error), 'error') }
    finally { setSaving(false) }
  }

  return <div className="stack"><section className="panel"><h2>Receive Stock</h2><div className="form-grid"><label>Invoice no.<input value={invoiceNo} onChange={e=>setInvoiceNo(e.target.value)}/></label><label>Remarks<input value={remarks} onChange={e=>setRemarks(e.target.value)}/></label></div><div className="line-editor"><AsyncItemPicker onSelect={item=>setLine({...line,item,item_id:item.id})}/><input placeholder="Lot no." value={line.lot_no || ''} onChange={e=>setLine({...line,lot_no:e.target.value})}/><input type="date" value={line.expiry_date || ''} onChange={e=>setLine({...line,expiry_date:e.target.value})}/><input type="number" min="0" step="0.01" value={line.qty} onChange={e=>setLine({...line,qty:Number(e.target.value)})}/><input type="number" min="0" step="0.01" value={line.unit_cost} onChange={e=>setLine({...line,unit_cost:Number(e.target.value)})}/><button className="btn secondary" onClick={addLine}>Add</button></div></section><section className="panel"><h2>รายการรับเข้า</h2><div className="table-wrap"><table className="data-table"><thead><tr><th>Item</th><th>Lot</th><th>Expiry</th><th>Qty</th><th>Cost</th><th></th></tr></thead><tbody>{items.map((it,idx)=><tr key={idx}><td>{it.item?.item_code} {it.item?.item_name}</td><td>{it.lot_no}</td><td>{it.expiry_date}</td><td>{it.qty}</td><td>{it.unit_cost}</td><td><button className="link-btn" onClick={()=>setItems(items.filter((_,i)=>i!==idx))}>remove</button></td></tr>)}</tbody></table></div><div className="panel-actions"><PrintButton/><button className="btn" disabled={saving} onClick={save}>{saving?'Saving...':'Save Receive'}</button></div></section></div>
}
