import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcTransferStock } from '../services/inventoryService'
import type { ItemSearchResult, TransferItemInput } from '../types'
import { readableError } from '../utils/errors'

type Line = TransferItemInput & { item?: ItemSearchResult | null }
export function TransferPage() {
  const { warehouses, selectedWarehouseId } = useAuth(); const { pushToast } = useToast()
  const [from, setFrom] = useState(selectedWarehouseId || ''); const [to, setTo] = useState(''); const [remarks, setRemarks] = useState(''); const [saving,setSaving]=useState(false)
  const [line,setLine]=useState<Line>({ item_id:'', lot_id:'', qty:1 }); const [items,setItems]=useState<Line[]>([])
  function addLine(){ if(!line.item_id || !line.lot_id || line.qty<=0){ pushToast('กรุณาเลือก item, lot_id และจำนวน', 'warning'); return } setItems([...items,line]); setLine({ item_id:'', lot_id:'', qty:1 }) }
  async function save(){ if(!from || !to || from===to || !items.length){ pushToast('ตรวจสอบคลังต้นทาง/ปลายทาง และรายการโอน', 'warning'); return } setSaving(true); try{ await rpcTransferStock({ from_warehouse_id:from, to_warehouse_id:to, remarks, items }); pushToast('สร้าง transfer สำเร็จ', 'success'); setItems([]); setRemarks('') }catch(e){ pushToast(readableError(e),'error') }finally{ setSaving(false) } }
  return <div className="stack"><section className="panel"><h2>Stock Transfer</h2><div className="form-grid"><label>From warehouse<select value={from} onChange={e=>setFrom(e.target.value)}><option value="">เลือกคลัง</option>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_name}</option>)}</select></label><label>To warehouse<select value={to} onChange={e=>setTo(e.target.value)}><option value="">เลือกคลัง</option>{warehouses.map(w=><option key={w.id} value={w.id}>{w.warehouse_name}</option>)}</select></label><label className="span-2">Remarks<input value={remarks} onChange={e=>setRemarks(e.target.value)} /></label></div><div className="line-editor"><AsyncItemPicker onSelect={item=>setLine({...line,item,item_id:item.id})}/><input placeholder="Lot ID" value={line.lot_id} onChange={e=>setLine({...line,lot_id:e.target.value})}/><input type="number" min="0" step="0.01" value={line.qty} onChange={e=>setLine({...line,qty:Number(e.target.value)})}/><button className="btn secondary" onClick={addLine}>Add</button></div></section><section className="panel"><h2>รายการโอน</h2><ul className="simple-list">{items.map((it,idx)=><li key={idx}><span>{it.item?.item_code} {it.item?.item_name} · Lot {it.lot_id} · Qty {it.qty}</span><button className="link-btn" onClick={()=>setItems(items.filter((_,i)=>i!==idx))}>remove</button></li>)}</ul><div className="panel-actions"><button className="btn" disabled={saving} onClick={save}>{saving?'Saving...':'Submit Transfer'}</button></div></section></div>
}
