import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcAdjustStock } from '../services/inventoryService'
import type { AdjustmentItemInput, ItemSearchResult } from '../types'
import { readableError } from '../utils/errors'

type Line = AdjustmentItemInput & { item?: ItemSearchResult | null }
export function AdjustmentPage() {
  const { selectedWarehouseId } = useAuth(); const { pushToast } = useToast()
  const [reason, setReason] = useState(''); const [remarks, setRemarks] = useState(''); const [saving, setSaving] = useState(false)
  const [line, setLine] = useState<Line>({ item_id:'', lot_id:'', qty_adjust:0, reason:'' }); const [items, setItems] = useState<Line[]>([])
  function addLine(){ if(!line.item_id || !line.lot_id || line.qty_adjust===0 || !line.reason){ pushToast('ต้องระบุ item, lot_id, qty และ reason', 'warning'); return } setItems([...items,line]); setLine({ item_id:'', lot_id:'', qty_adjust:0, reason:'' }) }
  async function save(){ if(!selectedWarehouseId || !reason || !items.length){ pushToast('กรุณาเลือกคลัง ระบุเหตุผล และเพิ่มรายการ', 'warning'); return } setSaving(true); try{ await rpcAdjustStock({ warehouse_id:selectedWarehouseId, reason, remarks, items }); pushToast('ปรับยอดสำเร็จ', 'success'); setItems([]); setReason(''); setRemarks('') }catch(e){ pushToast(readableError(e),'error') }finally{ setSaving(false) } }
  return <div className="stack"><section className="panel"><h2>Stock Adjustment</h2><div className="form-grid"><label>Main reason<input required value={reason} onChange={e=>setReason(e.target.value)} placeholder="Damage / Loss / Correction" /></label><label>Remarks<input value={remarks} onChange={e=>setRemarks(e.target.value)} /></label></div><div className="line-editor"><AsyncItemPicker onSelect={item=>setLine({...line,item,item_id:item.id})}/><input placeholder="Lot ID" value={line.lot_id} onChange={e=>setLine({...line,lot_id:e.target.value})}/><input type="number" step="0.01" value={line.qty_adjust} onChange={e=>setLine({...line,qty_adjust:Number(e.target.value)})}/><input placeholder="Line reason" value={line.reason} onChange={e=>setLine({...line,reason:e.target.value})}/><button className="btn secondary" onClick={addLine}>Add</button></div><p className="hint">Negative adjustment จะถูกตรวจสอบไม่ให้ stock ติดลบใน database RPC</p></section><section className="panel"><h2>รายการปรับยอด</h2><ul className="simple-list">{items.map((it,idx)=><li key={idx}><span>{it.item?.item_code} {it.item?.item_name} · Lot {it.lot_id} · {it.qty_adjust}</span><button className="link-btn" onClick={()=>setItems(items.filter((_,i)=>i!==idx))}>remove</button></li>)}</ul><div className="panel-actions"><button className="btn" disabled={saving} onClick={save}>{saving?'Saving...':'Save Adjustment'}</button></div></section></div>
}
