import { useState } from 'react'
import { AsyncItemPicker } from '../components/AsyncItemPicker'
import { PrintButton } from '../components/PrintButton'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { rpcIssueStock } from '../services/inventoryService'
import type { IssueItemInput, ItemSearchResult } from '../types'
import { readableError } from '../utils/errors'

type Line = IssueItemInput & { item?: ItemSearchResult | null }

export function IssuePage() {
  const { selectedWarehouseId } = useAuth()
  const { pushToast } = useToast()
  const [requester, setRequester] = useState('')
  const [remarks, setRemarks] = useState('')
  const [saving, setSaving] = useState(false)
  const [line, setLine] = useState<Line>({ item_id: '', qty: 1, reason: '' })
  const [items, setItems] = useState<Line[]>([])
  function addLine() {
    if (!line.item_id || line.qty <= 0) { pushToast('กรุณาเลือกรายการและใส่จำนวนให้ถูกต้อง', 'warning'); return }
    if ((line.item?.is_controlled || line.item?.is_high_alert) && !line.reason) { pushToast('Controlled/High alert item ต้องระบุ reason', 'warning'); return }
    setItems(prev=>[...prev,line]); setLine({ item_id:'', qty:1, reason:'' })
  }
  async function save() {
    if (!selectedWarehouseId) { pushToast('กรุณาเลือกคลัง', 'warning'); return }
    if (!items.length) { pushToast('กรุณาเพิ่มรายการเบิก', 'warning'); return }
    setSaving(true)
    try { await rpcIssueStock({ warehouse_id:selectedWarehouseId, requester_name:requester, remarks, items }); pushToast('เบิก stock สำเร็จ', 'success'); setItems([]); setRequester(''); setRemarks('') }
    catch (error) { pushToast(readableError(error),'error') }
    finally { setSaving(false) }
  }
  return <div className="stack"><section className="panel"><h2>Issue Stock</h2><div className="form-grid"><label>Requester<input value={requester} onChange={e=>setRequester(e.target.value)}/></label><label>Remarks<input value={remarks} onChange={e=>setRemarks(e.target.value)}/></label></div><div className="line-editor"><AsyncItemPicker onSelect={item=>setLine({...line,item,item_id:item.id})}/><input type="number" min="0" step="0.01" value={line.qty} onChange={e=>setLine({...line,qty:Number(e.target.value)})}/><input placeholder="Reason" value={line.reason || ''} onChange={e=>setLine({...line,reason:e.target.value})}/><button className="btn secondary" onClick={addLine}>Add</button></div><p className="hint">ระบบจะเลือก lot ด้วย FEFO จาก RPC โดยอัตโนมัติถ้าไม่ระบุ lot_id</p></section><section className="panel"><h2>รายการเบิก</h2><div className="table-wrap"><table className="data-table"><thead><tr><th>Item</th><th>Qty</th><th>Reason</th><th></th></tr></thead><tbody>{items.map((it,idx)=><tr key={idx}><td>{it.item?.item_code} {it.item?.item_name}</td><td>{it.qty}</td><td>{it.reason}</td><td><button className="link-btn" onClick={()=>setItems(items.filter((_,i)=>i!==idx))}>remove</button></td></tr>)}</tbody></table></div><div className="panel-actions"><PrintButton/><button className="btn" disabled={saving} onClick={save}>{saving?'Saving...':'Save Issue'}</button></div></section></div>
}
