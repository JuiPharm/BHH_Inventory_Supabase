import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'
import { DataTable } from '../components/DataTable'
import { ExportButton } from '../components/ExportButton'
import { StatusBadge } from '../components/StatusBadge'
import { useAuth } from '../state/AuthContext'
import { useToast } from '../state/ToastContext'
import { formatDate, formatNumber } from '../utils/format'
import { readableError } from '../utils/errors'

interface ExpiryRow { lot_id:string; item_code:string; item_name:string; warehouse_name:string; lot_no:string; expiry_date:string; days_to_expiry:number; qty_available:number; expiry_status:string }
export function ExpiryPage(){
 const {selectedWarehouseId}=useAuth(); const {pushToast}=useToast(); const [days,setDays]=useState(90); const [rows,setRows]=useState<ExpiryRow[]>([]); const [loading,setLoading]=useState(false)
 useEffect(()=>{ load() },[selectedWarehouseId,days])
 async function load(){ setLoading(true); try{ let q=supabase.from('near_expiry_view').select('*').lte('days_to_expiry',days).order('expiry_date'); if(selectedWarehouseId) q=q.eq('warehouse_id',selectedWarehouseId); const {data,error}=await q; if(error) throw error; setRows((data||[]) as ExpiryRow[]) }catch(e){ pushToast(readableError(e),'error') }finally{ setLoading(false) } }
 return <div className="stack"><div className="toolbar"><select className="select" value={days} onChange={e=>setDays(Number(e.target.value))}><option value={30}>30 วัน</option><option value={60}>60 วัน</option><option value={90}>90 วัน</option><option value={180}>180 วัน</option></select><ExportButton filename="near_expiry.csv" rows={rows as unknown as Record<string,unknown>[]} /></div><DataTable loading={loading} rows={rows} columns={[{key:'item',header:'Item',render:r=><div><b>{r.item_code}</b><small>{r.item_name}</small></div>},{key:'wh',header:'Warehouse',render:r=>r.warehouse_name},{key:'lot',header:'Lot',render:r=>r.lot_no},{key:'expiry',header:'Expiry',render:r=>formatDate(r.expiry_date)},{key:'days',header:'Days',render:r=>formatNumber(r.days_to_expiry)},{key:'qty',header:'Qty',render:r=>formatNumber(r.qty_available,2)},{key:'status',header:'Status',render:r=><StatusBadge tone={r.expiry_status==='expired'?'red':'amber'}>{r.expiry_status}</StatusBadge>}]} /></div>
}
